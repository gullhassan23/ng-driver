import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

import {
  COLLECTIONS,
  DriverFields,
  FCM_MAX_DRIVERS,
  FcmNotificationType,
  RideFields,
} from "../shared/constants";
import {claimFcmDispatch, sendFcmToTokens} from "./fcmSend";

/**
 * Best-effort FCM to approved, online, unoccupied drivers with a token.
 * Idempotent per ride via fcm_dispatches + rides.fcmNotifiedAt.
 */
export async function notifyEligibleDrivers(rideId: string): Promise<void> {
  const id = rideId.trim();
  if (!id) return;

  const claimed = await claimFcmDispatch(`${FcmNotificationType.newRide}_${id}`);
  if (!claimed) {
    return;
  }

  const db = getFirestore();
  const rideRef = db.collection(COLLECTIONS.rides).doc(id);
  const rideSnap = await rideRef.get();
  if (!rideSnap.exists) {
    logger.info("new_ride FCM skipped: ride missing", {rideId: id});
    return;
  }

  if (rideSnap.get(RideFields.fcmNotifiedAt)) {
    logger.info("new_ride FCM skipped: already stamped", {rideId: id});
    return;
  }

  const snapshot = await db
    .collection(COLLECTIONS.drivers)
    .where(DriverFields.isApproved, "==", true)
    .where(DriverFields.isOnline, "==", true)
    .limit(FCM_MAX_DRIVERS)
    .get();

  const tokens: string[] = [];
  const driverIdsByToken = new Map<string, string>();

  for (const doc of snapshot.docs) {
    const currentRideId = doc.get(DriverFields.currentRideId);
    if (typeof currentRideId === "string" && currentRideId.trim().length > 0) {
      continue;
    }

    const token = doc.get(DriverFields.fcmToken);
    if (typeof token === "string" && token.trim().length > 0) {
      const trimmed = token.trim();
      tokens.push(trimmed);
      driverIdsByToken.set(trimmed, doc.id);
    }
  }

  if (tokens.length === 0) {
    logger.info("No eligible driver tokens for ride", {rideId: id});
    // Still stamp so retries do not keep scanning.
    await rideRef.set(
      {
        [RideFields.fcmNotifiedAt]: FieldValue.serverTimestamp(),
        [RideFields.updatedAt]: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return;
  }

  await sendFcmToTokens(
    tokens,
    {
      type: FcmNotificationType.newRide,
      title: "New ride request",
      body: "A rider is waiting nearby. Open the app to accept.",
      data: {rideId: id},
    },
    {driverIdsByToken},
  );

  await rideRef.set(
    {
      [RideFields.fcmNotifiedAt]: FieldValue.serverTimestamp(),
      [RideFields.updatedAt]: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}
