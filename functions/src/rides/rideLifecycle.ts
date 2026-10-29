import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import type {
  DocumentReference,
  DocumentSnapshot,
  Transaction,
} from "firebase-admin/firestore";

import {
  COLLECTIONS,
  CancelledBy,
  DriverFields,
  ReservationFields,
  ReservationStatus,
  RideFields,
  RideStatus,
  isActiveAssignedStatus,
  isPreArrivingAssignedStatus,
  isTripInProgressStatus,
} from "../shared/constants";
import {
  SafeMessages,
  failInvalidArgument,
  requireAuth,
} from "../shared/errors";

type LifecycleAction =
  | "setArriving"
  | "arrivePickup"
  | "start"
  | "complete"
  | "cancel";

interface UpdateRideStatusRequest {
  rideId?: string;
  action?: LifecycleAction;
  cancellationReason?: string;
}

interface SyncReservationOptions {
  cancelledBy?: string;
  cancellationReason?: string;
}

/**
 * Mirror linked reservation status inside the same transaction.
 * Never overwrites a completed reservation with cancelled.
 * Does not write passenger_arriving onto reservations.
 * On cancel, also writes cancelledBy / cancelledAt / optional reason.
 */
function syncLinkedReservation(
  tx: Transaction,
  reservationRef: DocumentReference | undefined,
  reservationSnap: DocumentSnapshot | undefined,
  newStatus: string,
  options?: SyncReservationOptions,
): void {
  if (!reservationRef || !reservationSnap || !reservationSnap.exists) {
    return;
  }

  const current = String(
    reservationSnap.get(ReservationFields.status) ?? "",
  ).toLowerCase();
  if (
    current === ReservationStatus.completed &&
    newStatus === ReservationStatus.cancelled
  ) {
    return;
  }
  if (current === newStatus.toLowerCase()) {
    return;
  }

  const update: Record<string, unknown> = {
    [ReservationFields.status]: newStatus,
    [ReservationFields.updatedAt]: FieldValue.serverTimestamp(),
  };

  if (newStatus === ReservationStatus.cancelled) {
    update[ReservationFields.cancelledAt] = FieldValue.serverTimestamp();
    if (options?.cancelledBy) {
      update[ReservationFields.cancelledBy] = options.cancelledBy;
    }
    if (options?.cancellationReason) {
      update[ReservationFields.cancellationReason] = options.cancellationReason;
      update[ReservationFields.cancelReason] = options.cancellationReason;
    }
  }

  tx.update(reservationRef, update);
}

function clearDriverCurrentRide(
  tx: Transaction,
  driverId: string,
): void {
  const driverRef = getFirestore().collection(COLLECTIONS.drivers).doc(driverId);
  tx.set(
    driverRef,
    {
      [DriverFields.currentRideId]: FieldValue.delete(),
      [DriverFields.updatedAt]: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

/**
 * Server-authoritative status transitions after a ride is claimed
 * (or rider cancel while pending).
 *
 * Actions:
 * - setArriving: accepted → driver_arriving (idempotent)
 * - arrivePickup: driver_arriving → driver_arrived (idempotent; preserves passenger_arriving)
 * - start: passenger_arriving → ride_started (idempotent if already trip)
 * - complete: ride_started|inProgress → completed (idempotent)
 * - cancel: pending (rider), assigned active (driver or rider)
 *
 * When rides.reservationId is set, the linked reservation status is updated
 * in the same transaction for arrivePickup / start / complete / cancel /
 * setArriving. Cancel also writes cancelledBy attribution on the reservation.
 */
export const updateRideStatus = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const data = (request.data ?? {}) as UpdateRideStatusRequest;
  const rideId = typeof data.rideId === "string" ? data.rideId.trim() : "";
  const action = data.action;
  const cancellationReason =
    typeof data.cancellationReason === "string"
      ? data.cancellationReason.trim()
      : "";

  if (!rideId) {
    failInvalidArgument("rideId is required.");
  }

  const allowedActions: LifecycleAction[] = [
    "setArriving",
    "arrivePickup",
    "start",
    "complete",
    "cancel",
  ];
  if (!action || !allowedActions.includes(action)) {
    failInvalidArgument(
      "action must be setArriving, arrivePickup, start, complete, or cancel.",
    );
  }

  const db = getFirestore();
  const rideRef = db.collection(COLLECTIONS.rides).doc(rideId);

  let resultStatus: string = RideStatus.pending;
  let denial: HttpsError | undefined;
  /** Driver whose currentRideId should be cleared after a successful cancel/complete. */
  let clearCurrentRideFor: string | undefined;

  await db.runTransaction(async (tx) => {
    denial = undefined;
    clearCurrentRideFor = undefined;
    const rideSnap = await tx.get(rideRef);

    if (!rideSnap.exists) {
      denial = new HttpsError("failed-precondition", SafeMessages.rideNotFound);
      return;
    }

    const status = rideSnap.get(RideFields.status) as string | undefined;
    const driverId = rideSnap.get(RideFields.driverId) as string | undefined;
    const customerId = rideSnap.get(RideFields.customerId) as
      | string
      | undefined;
    const reservationId = rideSnap.get(RideFields.reservationId) as
      | string
      | undefined;

    let reservationRef: DocumentReference | undefined;
    let reservationSnap: DocumentSnapshot | undefined;
    if (typeof reservationId === "string" && reservationId.trim() !== "") {
      reservationRef = db
        .collection(COLLECTIONS.reservations)
        .doc(reservationId.trim());
      reservationSnap = await tx.get(reservationRef);
    }

    if (action === "cancel") {
      // Idempotent: already cancelled.
      if (status === RideStatus.cancelled) {
        resultStatus = RideStatus.cancelled;
        if (driverId) {
          clearDriverCurrentRide(tx, driverId);
          clearCurrentRideFor = driverId;
        }
        return;
      }

      // Rider cancels a still-pending request.
      if (status === RideStatus.pending) {
        if (!customerId || customerId !== uid) {
          denial = new HttpsError(
            "permission-denied",
            "Only the rider can cancel a pending ride.",
          );
          return;
        }

        const cancelPending: Record<string, unknown> = {
          [RideFields.status]: RideStatus.cancelled,
          [RideFields.cancelledAt]: FieldValue.serverTimestamp(),
          [RideFields.cancelledBy]: CancelledBy.rider,
          [RideFields.updatedAt]: FieldValue.serverTimestamp(),
        };
        if (cancellationReason) {
          cancelPending[RideFields.cancellationReason] = cancellationReason;
        }

        tx.update(rideRef, cancelPending);
        resultStatus = RideStatus.cancelled;
        return;
      }

      if (status === RideStatus.completed) {
        denial = new HttpsError(
          "failed-precondition",
          SafeMessages.invalidStatus,
        );
        return;
      }

      // Assigned trip: driver or rider may cancel.
      if (status && isActiveAssignedStatus(status)) {
        const isDriver = Boolean(driverId && driverId === uid);
        const isRider = Boolean(customerId && customerId === uid);

        if (!isDriver && !isRider) {
          denial = new HttpsError(
            "permission-denied",
            SafeMessages.notAssigned,
          );
          return;
        }

        const cancelledBy = isDriver ? CancelledBy.driver : CancelledBy.rider;
        const cancelAssigned: Record<string, unknown> = {
          [RideFields.status]: RideStatus.cancelled,
          [RideFields.cancelledAt]: FieldValue.serverTimestamp(),
          [RideFields.cancelledBy]: cancelledBy,
          [RideFields.updatedAt]: FieldValue.serverTimestamp(),
        };
        if (cancellationReason) {
          cancelAssigned[RideFields.cancellationReason] = cancellationReason;
        }

        tx.update(rideRef, cancelAssigned);
        syncLinkedReservation(
          tx,
          reservationRef,
          reservationSnap,
          ReservationStatus.cancelled,
          {
            cancelledBy,
            cancellationReason: cancellationReason || undefined,
          },
        );

        if (driverId) {
          clearDriverCurrentRide(tx, driverId);
          clearCurrentRideFor = driverId;
        }

        resultStatus = RideStatus.cancelled;
        return;
      }

      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.invalidStatus,
      );
      return;
    }

    if (!driverId || driverId !== uid) {
      denial = new HttpsError("permission-denied", SafeMessages.notAssigned);
      return;
    }

    if (action === "setArriving") {
      if (status === RideStatus.driverArriving) {
        resultStatus = RideStatus.driverArriving;
        return;
      }
      if (
        status === RideStatus.driverArrived ||
        status === RideStatus.passengerArriving ||
        isTripInProgressStatus(status ?? "")
      ) {
        resultStatus = status ?? RideStatus.driverArriving;
        return;
      }
      if (!isPreArrivingAssignedStatus(status ?? "")) {
        denial = new HttpsError(
          "failed-precondition",
          SafeMessages.invalidStatus,
        );
        return;
      }

      tx.update(rideRef, {
        [RideFields.status]: RideStatus.driverArriving,
        [RideFields.arrivingAt]: FieldValue.serverTimestamp(),
        [RideFields.updatedAt]: FieldValue.serverTimestamp(),
      });
      syncLinkedReservation(
        tx,
        reservationRef,
        reservationSnap,
        ReservationStatus.driverArriving,
      );
      resultStatus = RideStatus.driverArriving;
      return;
    }

    if (action === "arrivePickup") {
      if (status === RideStatus.driverArrived) {
        resultStatus = RideStatus.driverArrived;
        return;
      }
      if (status === RideStatus.passengerArriving) {
        // Already past arrival — do not overwrite passenger_arriving.
        resultStatus = RideStatus.passengerArriving;
        return;
      }
      if (isTripInProgressStatus(status ?? "")) {
        resultStatus = status ?? RideStatus.driverArrived;
        return;
      }
      if (status !== RideStatus.driverArriving) {
        denial = new HttpsError(
          "failed-precondition",
          SafeMessages.invalidStatus,
        );
        return;
      }

      tx.update(rideRef, {
        [RideFields.status]: RideStatus.driverArrived,
        [RideFields.driverArrivedAt]: FieldValue.serverTimestamp(),
        [RideFields.updatedAt]: FieldValue.serverTimestamp(),
      });
      syncLinkedReservation(
        tx,
        reservationRef,
        reservationSnap,
        ReservationStatus.driverArrived,
      );
      resultStatus = RideStatus.driverArrived;
      return;
    }

    if (action === "start") {
      if (isTripInProgressStatus(status ?? "")) {
        resultStatus = RideStatus.rideStarted;
        return;
      }
      if (status !== RideStatus.passengerArriving) {
        denial = new HttpsError(
          "failed-precondition",
          SafeMessages.invalidStatus,
        );
        return;
      }

      tx.update(rideRef, {
        [RideFields.status]: RideStatus.rideStarted,
        [RideFields.startedAt]: FieldValue.serverTimestamp(),
        [RideFields.updatedAt]: FieldValue.serverTimestamp(),
      });
      syncLinkedReservation(
        tx,
        reservationRef,
        reservationSnap,
        ReservationStatus.rideStarted,
      );
      resultStatus = RideStatus.rideStarted;
      return;
    }

    // complete — idempotent; only from trip-in-progress
    if (status === RideStatus.completed) {
      const driverRef = db.collection(COLLECTIONS.drivers).doc(driverId);
      tx.set(
        driverRef,
        {
          [DriverFields.currentRideId]: FieldValue.delete(),
          [DriverFields.updatedAt]: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      resultStatus = RideStatus.completed;
      clearCurrentRideFor = driverId;
      return;
    }

    if (!isTripInProgressStatus(status ?? "")) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.invalidStatus,
      );
      return;
    }

    // Complete is idempotent and does not touch payment fields. Card
    // capture/verification belongs in dedicated backend payment functions.
    tx.update(rideRef, {
      [RideFields.status]: RideStatus.completed,
      [RideFields.completedAt]: FieldValue.serverTimestamp(),
      [RideFields.updatedAt]: FieldValue.serverTimestamp(),
    });
    syncLinkedReservation(
      tx,
      reservationRef,
      reservationSnap,
      ReservationStatus.completed,
    );

    const driverRef = db.collection(COLLECTIONS.drivers).doc(driverId);
    tx.set(
      driverRef,
      {
        [DriverFields.currentRideId]: FieldValue.delete(),
        [DriverFields.updatedAt]: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    resultStatus = RideStatus.completed;
    clearCurrentRideFor = driverId;
  });

  if (denial) {
    throw denial;
  }

  logger.info("updateRideStatus", {
    rideId,
    uid,
    action,
    resultStatus,
    clearCurrentRideFor,
  });
  return {ok: true, rideId, status: resultStatus};
});
