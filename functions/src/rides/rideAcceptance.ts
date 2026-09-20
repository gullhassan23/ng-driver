import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  COLLECTIONS,
  DriverFields,
  RideFields,
  RideStatus,
  isActiveAssignedStatus,
} from "../shared/constants";
import {assignedDriverRideFields} from "../shared/driverSnapshot";
import {
  SafeMessages,
  failInvalidArgument,
  requireAuth,
} from "../shared/errors";

interface AcceptRideRequest {
  rideId?: string;
  offeredFare?: number;
  driverLatitude?: number;
  driverLongitude?: number;
  driverAddress?: string;
}

function textField(
  data: Record<string, unknown> | undefined,
  key: string,
): string {
  const value = data?.[key];
  return typeof value === "string" ? value : "";
}

function optionalFiniteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

/**
 * Atomically claim a pending ride for the calling driver.
 * Sets ride status directly to `driver_arriving` — no driverOffers / rider selection.
 */
export const acceptRide = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const data = (request.data ?? {}) as AcceptRideRequest;
  const rideId = typeof data.rideId === "string" ? data.rideId.trim() : "";

  if (!rideId) {
    failInvalidArgument("rideId is required.");
  }

  const driverLatitude = optionalFiniteNumber(data.driverLatitude);
  const driverLongitude = optionalFiniteNumber(data.driverLongitude);

  const db = getFirestore();
  const rideRef = db.collection(COLLECTIONS.rides).doc(rideId);
  const driverRef = db.collection(COLLECTIONS.drivers).doc(uid);

  let denial: HttpsError | undefined;
  let resultStatus: string = RideStatus.driverArriving;

  await db.runTransaction(async (tx) => {
    denial = undefined;

    const rideSnap = await tx.get(rideRef);
    const driverSnap = await tx.get(driverRef);

    if (!driverSnap.exists || driverSnap.get(DriverFields.isApproved) !== true) {
      denial = new HttpsError("permission-denied", SafeMessages.notApproved);
      return;
    }

    if (!rideSnap.exists) {
      denial = new HttpsError("failed-precondition", SafeMessages.rideNotFound);
      return;
    }

    const status = rideSnap.get(RideFields.status) as string | undefined;
    const existingDriverId = rideSnap.get(RideFields.driverId) as
      | string
      | undefined;

    // Idempotent: same driver already owns an active assigned ride.
    if (
      existingDriverId === uid &&
      status &&
      isActiveAssignedStatus(status)
    ) {
      resultStatus = status;
      return;
    }

    // First-accept-wins: any other driverId / active status means taken.
    if (existingDriverId && existingDriverId !== uid) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.alreadyAccepted,
      );
      return;
    }

    if (status && isActiveAssignedStatus(status)) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.alreadyAccepted,
      );
      return;
    }

    // Only unclaimed pending/expired rides are claimable.
    if (status !== RideStatus.pending && status !== RideStatus.expired) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.rideUnavailable,
      );
      return;
    }

    const driverData = driverSnap.data() as Record<string, unknown> | undefined;
    const activeRideId = textField(driverData, DriverFields.currentRideId);
    if (activeRideId && activeRideId !== rideId) {
      denial = new HttpsError(
        "failed-precondition",
        "Finish or cancel your current ride before accepting another.",
      );
      return;
    }

    const pickupLatitude = optionalFiniteNumber(
      rideSnap.get(RideFields.pickupLatitude),
    );
    const pickupLongitude = optionalFiniteNumber(
      rideSnap.get(RideFields.pickupLongitude),
    );

    const rideUpdate: Record<string, unknown> = {
      [RideFields.status]: RideStatus.driverArriving,
      [RideFields.driverId]: uid,
      [RideFields.acceptedAt]: FieldValue.serverTimestamp(),
      [RideFields.arrivingAt]: FieldValue.serverTimestamp(),
      [RideFields.updatedAt]: FieldValue.serverTimestamp(),
      ...assignedDriverRideFields({
        driverData,
        driverLatitude,
        driverLongitude,
        pickupLatitude,
        pickupLongitude,
      }),
    };

    if (driverLatitude !== undefined && driverLongitude !== undefined) {
      rideUpdate[RideFields.driverLocation] = {
        latitude: driverLatitude,
        longitude: driverLongitude,
      };
      rideUpdate[RideFields.driverLocationUpdatedAt] =
        FieldValue.serverTimestamp();
    }

    tx.update(rideRef, rideUpdate);
    tx.set(
      driverRef,
      {
        [DriverFields.currentRideId]: rideId,
        [DriverFields.updatedAt]: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    resultStatus = RideStatus.driverArriving;
  });

  if (denial) {
    throw denial;
  }

  logger.info("Ride claimed by driver", {
    rideId,
    driverId: uid,
    status: resultStatus,
    hasLocation: driverLatitude !== undefined && driverLongitude !== undefined,
  });

  return {
    ok: true,
    rideId,
    driverId: uid,
    status: resultStatus,
  };
});
