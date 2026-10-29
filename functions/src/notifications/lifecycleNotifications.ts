import {logger} from "firebase-functions";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";

import {
  COLLECTIONS,
  CancelledBy,
  DriverFields,
  FcmNotificationType,
  RideFields,
  RideStatus,
  normalizeRideStatus,
} from "../shared/constants";
import {
  claimFcmDispatch,
  sendFcmToDriver,
  sendFcmToUser,
} from "./fcmSend";

function isCancelled(status: string): boolean {
  return normalizeRideStatus(status) === RideStatus.cancelled;
}

function cancelledByActor(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().toLowerCase();
}

function isDriverCancelled(by: string): boolean {
  return by === CancelledBy.driver;
}

function isRiderCancelled(by: string): boolean {
  return by === CancelledBy.rider || by === CancelledBy.user;
}

/** Ride cancel (assigned) + passenger_arriving edge notifications. */
export const onRideUpdated = onDocumentUpdated(
  `${COLLECTIONS.rides}/{rideId}`,
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const rideId = event.params.rideId as string;
    const prevStatus = normalizeRideStatus(
      String(before.get(RideFields.status) ?? ""),
    );
    const nextStatus = normalizeRideStatus(
      String(after.get(RideFields.status) ?? ""),
    );

    const driverIdRaw = after.get(RideFields.driverId);
    const driverId =
      typeof driverIdRaw === "string" ? driverIdRaw.trim() : "";
    const customerIdRaw = after.get(RideFields.customerId);
    const customerId =
      typeof customerIdRaw === "string" ? customerIdRaw.trim() : "";
    const cancelledBy = cancelledByActor(after.get(RideFields.cancelledBy));

    // Terminal cancel: notify the other party with accurate attribution.
    if (!isCancelled(prevStatus) && isCancelled(nextStatus)) {
      const claimed = await claimFcmDispatch(
        `${FcmNotificationType.rideCancelled}_${rideId}`,
      );
      if (claimed) {
        try {
          if (isDriverCancelled(cancelledBy)) {
            // Driver cancelled — notify rider; do not ping the driver.
            if (customerId) {
              await sendFcmToUser(customerId, {
                type: FcmNotificationType.rideCancelled,
                title: "Ride cancelled",
                body: "Your driver cancelled this ride.",
                data: {
                  rideId,
                  cancelledBy: CancelledBy.driver,
                },
              });
            }
          } else if (isRiderCancelled(cancelledBy) || !cancelledBy) {
            // Rider cancelled (or legacy missing attribution) — notify driver.
            if (driverId) {
              await sendFcmToDriver(driverId, {
                type: FcmNotificationType.rideCancelled,
                title: "Ride cancelled",
                body: "The rider cancelled this ride.",
                data: {
                  rideId,
                  cancelledBy: cancelledBy || CancelledBy.rider,
                },
              });
            }
          }
        } catch (error) {
          logger.error("ride_cancelled FCM failed", {rideId, error});
        }
      }
    }

    // Rider signaled they are coming to the pickup.
    if (
      prevStatus !== RideStatus.passengerArriving &&
      nextStatus === RideStatus.passengerArriving &&
      driverId
    ) {
      const claimed = await claimFcmDispatch(
        `${FcmNotificationType.passengerArriving}_${rideId}`,
      );
      if (claimed) {
        try {
          await sendFcmToDriver(driverId, {
            type: FcmNotificationType.passengerArriving,
            title: "Passenger is coming",
            body: "The rider confirmed they are on the way to the pickup.",
            data: {rideId},
          });
        } catch (error) {
          logger.error("passenger_arriving FCM failed", {rideId, error});
        }
      }
    }
  },
);

/** Notify driver when admin flips isApproved false → true. */
export const onDriverUpdated = onDocumentUpdated(
  `${COLLECTIONS.drivers}/{driverId}`,
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const driverId = event.params.driverId as string;
    const wasApproved = before.get(DriverFields.isApproved) === true;
    const isApproved = after.get(DriverFields.isApproved) === true;

    if (wasApproved || !isApproved) {
      return;
    }

    const claimed = await claimFcmDispatch(
      `${FcmNotificationType.driverApproved}_${driverId}`,
    );
    if (!claimed) return;

    try {
      await sendFcmToDriver(driverId, {
        type: FcmNotificationType.driverApproved,
        title: "Account approved",
        body: "Your driver account is approved. You can go online now.",
        data: {driverId},
      });
    } catch (error) {
      logger.error("driver_approved FCM failed", {driverId, error});
    }
  },
);
