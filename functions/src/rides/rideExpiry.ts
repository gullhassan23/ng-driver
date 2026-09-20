import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  COLLECTIONS,
  RideFields,
  RideStatus,
} from "../shared/constants";
import {notifyEligibleDrivers} from "../notifications/rideNotifications";

/** Pending rides expire after 5 minutes without acceptance. */
const RIDE_EXPIRY_MS = 5 * 60 * 1000;

/**
 * When a ride is created by the User app, ensure server timestamps for
 * createdAt / expiresAt, then best-effort FCM to eligible drivers.
 */
export const onRideCreated = onDocumentCreated(
  `${COLLECTIONS.rides}/{rideId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }

    const rideId = event.params.rideId;
    const data = snap.data();
    const patch: Record<string, unknown> = {};

    if (!data[RideFields.createdAt]) {
      patch[RideFields.createdAt] = FieldValue.serverTimestamp();
    }

    if (!data[RideFields.expiresAt]) {
      patch[RideFields.expiresAt] = Timestamp.fromMillis(
        Date.now() + RIDE_EXPIRY_MS,
      );
    }

    if (Object.keys(patch).length > 0) {
      patch[RideFields.updatedAt] = FieldValue.serverTimestamp();
      await snap.ref.set(patch, {merge: true});
      logger.info("Ride timestamps set", {rideId, keys: Object.keys(patch)});
    }

    const status = (data[RideFields.status] as string | undefined) ?? RideStatus.pending;
    if (status === RideStatus.pending) {
      try {
        await notifyEligibleDrivers(rideId);
      } catch (error) {
        // FCM must never block the ride feed / lifecycle.
        logger.error("FCM notify failed", {rideId, error});
      }
    }
  },
);

/**
 * Periodically mark overdue pending rides as expired.
 */
export const expirePendingRides = onSchedule("every 1 minutes", async () => {
  const db = getFirestore();
  const now = Timestamp.now();

  const snap = await db
    .collection(COLLECTIONS.rides)
    .where(RideFields.status, "==", RideStatus.pending)
    .where(RideFields.expiresAt, "<=", now)
    .limit(50)
    .get();

  if (snap.empty) {
    logger.info("expirePendingRides: none due");
    return;
  }

  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.update(doc.ref, {
      [RideFields.status]: RideStatus.expired,
      [RideFields.updatedAt]: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  logger.info("expirePendingRides: expired", {count: snap.size});
});
