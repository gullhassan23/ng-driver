import {
  FieldValue,
  getFirestore,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  COLLECTIONS,
  CancelledBy,
  DriverFields,
  ReservationFields,
  ReservationStatus,
  RideFields,
  RideStatus,
  isActiveAssignedStatus,
  isActiveReservationLifecycleStatus,
  normalizeReservationStatus,
} from "../shared/constants";
import {
  SafeMessages,
  failInvalidArgument,
  requireAuth,
} from "../shared/errors";

interface CancelReservationRequest {
  reservationId?: string;
  cancellationReason?: string;
}

/**
 * Assigned driver cancels a confirmed (or live) reservation.
 *
 * - Pending offers cannot be cancelled here (decline is local-only).
 * - Idempotent when already cancelled.
 * - When a linked live ride exists, cancels that ride too and clears
 *   drivers.currentRideId in the same transaction.
 * - Never writes customer cancellation-fee or payment fields.
 */
export const cancelReservation = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const data = (request.data ?? {}) as CancelReservationRequest;
  const reservationId =
    typeof data.reservationId === "string" ? data.reservationId.trim() : "";
  const cancellationReason =
    typeof data.cancellationReason === "string"
      ? data.cancellationReason.trim()
      : "";

  if (!reservationId) {
    failInvalidArgument("reservationId is required.");
  }

  const db = getFirestore();
  const reservationRef = db
    .collection(COLLECTIONS.reservations)
    .doc(reservationId);

  let resultStatus: string = ReservationStatus.cancelled;
  let denial: HttpsError | undefined;
  let clearedRideId: string | undefined;

  await db.runTransaction(async (tx) => {
    denial = undefined;
    clearedRideId = undefined;

    const reservationSnap = await tx.get(reservationRef);
    if (!reservationSnap.exists) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.reservationNotFound,
      );
      return;
    }

    const resData = reservationSnap.data() ?? ({} as DocumentData);
    const status = normalizeReservationStatus(
      String(resData[ReservationFields.status] ?? ""),
    );
    const assignedDriver =
      typeof resData[ReservationFields.driverId] === "string"
        ? (resData[ReservationFields.driverId] as string).trim()
        : "";

    if (status === ReservationStatus.cancelled) {
      resultStatus = ReservationStatus.cancelled;
      return;
    }

    if (status === ReservationStatus.completed) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.invalidReservationStatus,
      );
      return;
    }

    if (status === ReservationStatus.pending) {
      denial = new HttpsError(
        "failed-precondition",
        "Pending reservation offers cannot be cancelled. Decline locally instead.",
      );
      return;
    }

    if (!isActiveReservationLifecycleStatus(status)) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.invalidReservationStatus,
      );
      return;
    }

    if (!assignedDriver || assignedDriver !== uid) {
      denial = new HttpsError(
        "permission-denied",
        SafeMessages.notAssignedReservation,
      );
      return;
    }

    const linkedRideId =
      typeof resData[ReservationFields.rideId] === "string"
        ? (resData[ReservationFields.rideId] as string).trim()
        : "";

    let rideRef: DocumentReference | undefined;
    let rideSnap: DocumentSnapshot | undefined;
    if (linkedRideId) {
      rideRef = db.collection(COLLECTIONS.rides).doc(linkedRideId);
      rideSnap = await tx.get(rideRef);
    }

    const cancelFields: Record<string, unknown> = {
      [ReservationFields.status]: ReservationStatus.cancelled,
      [ReservationFields.cancelledAt]: FieldValue.serverTimestamp(),
      [ReservationFields.cancelledBy]: CancelledBy.driver,
      [ReservationFields.updatedAt]: FieldValue.serverTimestamp(),
    };
    if (cancellationReason) {
      cancelFields[ReservationFields.cancellationReason] = cancellationReason;
      cancelFields[ReservationFields.cancelReason] = cancellationReason;
    }

    tx.update(reservationRef, cancelFields);

    if (rideRef && rideSnap?.exists) {
      const rideStatus = String(rideSnap.get(RideFields.status) ?? "");
      const rideDriver = String(rideSnap.get(RideFields.driverId) ?? "").trim();

      if (isActiveAssignedStatus(rideStatus) && rideDriver === uid) {
        const rideCancel: Record<string, unknown> = {
          [RideFields.status]: RideStatus.cancelled,
          [RideFields.cancelledAt]: FieldValue.serverTimestamp(),
          [RideFields.cancelledBy]: CancelledBy.driver,
          [RideFields.updatedAt]: FieldValue.serverTimestamp(),
        };
        if (cancellationReason) {
          rideCancel[RideFields.cancellationReason] = cancellationReason;
        }
        tx.update(rideRef, rideCancel);
        clearedRideId = linkedRideId;

        const driverRef = db.collection(COLLECTIONS.drivers).doc(uid);
        tx.set(
          driverRef,
          {
            [DriverFields.currentRideId]: FieldValue.delete(),
            [DriverFields.updatedAt]: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
    }

    resultStatus = ReservationStatus.cancelled;
  });

  if (denial) {
    throw denial;
  }

  logger.info("cancelReservation", {
    reservationId,
    uid,
    resultStatus,
    clearedRideId,
  });

  return {
    ok: true,
    reservationId,
    status: resultStatus,
    clearedRideId: clearedRideId ?? null,
  };
});
