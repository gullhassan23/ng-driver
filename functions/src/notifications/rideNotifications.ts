import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";

import {
  COLLECTIONS,
  DriverFields,
  FCM_MAX_DRIVERS,
} from "../shared/constants";

/**
 * Best-effort FCM to approved, online drivers with a token.
 * Does not affect Firestore listeners — failures are logged only.
 */
export async function notifyEligibleDrivers(rideId: string): Promise<void> {
  const db = getFirestore();

  const snapshot = await db
    .collection(COLLECTIONS.drivers)
    .where(DriverFields.isApproved, "==", true)
    .where(DriverFields.isOnline, "==", true)
    .limit(FCM_MAX_DRIVERS)
    .get();

  const tokens: string[] = [];

  for (const doc of snapshot.docs) {
    const token = doc.get(DriverFields.fcmToken);
    if (typeof token === "string" && token.trim().length > 0) {
      tokens.push(token.trim());
    }
  }

  if (tokens.length === 0) {
    logger.info("No eligible driver tokens for ride", {rideId});
    return;
  }

  const messaging = getMessaging();
  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: "New ride request",
      body: "A rider is waiting nearby. Open the app to accept.",
    },
    data: {
      rideId,
    },
    android: {
      priority: "high",
    },
  });

  logger.info("FCM multicast sent", {
    rideId,
    successCount: response.successCount,
    failureCount: response.failureCount,
    tokenCount: tokens.length,
  });
}
