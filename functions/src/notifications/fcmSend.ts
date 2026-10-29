import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import type {MulticastMessage} from "firebase-admin/messaging";
import {logger} from "firebase-functions";

import {COLLECTIONS, DriverFields} from "../shared/constants";

/** Common rider-profile FCM token field names. */
const USER_FCM_TOKEN_KEYS = ["fcmToken", "fcm_token", "pushToken"] as const;

export interface FcmPayload {
  type: string;
  title: string;
  body: string;
  /** All values must be strings for FCM data. */
  data?: Record<string, string>;
}

/**
 * Claims a one-shot dispatch id. Returns false if already claimed
 * (Cloud Function retry / duplicate trigger).
 */
export async function claimFcmDispatch(dispatchId: string): Promise<boolean> {
  const trimmed = dispatchId.trim();
  if (!trimmed) return false;

  const ref = getFirestore().collection(COLLECTIONS.fcmDispatches).doc(trimmed);
  try {
    await ref.create({
      dispatchId: trimmed,
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  } catch (error: unknown) {
    const code =
      error && typeof error === "object" && "code" in error
        ? (error as {code?: number | string}).code
        : undefined;
    // Firestore ALREADY_EXISTS
    if (code === 6 || code === "already-exists") {
      logger.info("FCM dispatch already claimed", {dispatchId: trimmed});
      return false;
    }
    throw error;
  }
}

/** Reads a single driver's FCM token when present and non-empty. */
export async function getDriverFcmToken(
  driverId: string,
): Promise<string | null> {
  const id = driverId.trim();
  if (!id) return null;

  const snap = await getFirestore().collection(COLLECTIONS.drivers).doc(id).get();
  if (!snap.exists) return null;

  const token = snap.get(DriverFields.fcmToken);
  if (typeof token === "string" && token.trim().length > 0) {
    return token.trim();
  }
  return null;
}

/**
 * Best-effort multicast. Clears invalid tokens from driver docs when possible.
 */
export async function sendFcmToTokens(
  tokens: string[],
  payload: FcmPayload,
  options?: {driverIdsByToken?: Map<string, string>},
): Promise<void> {
  const unique = [...new Set(tokens.map((t) => t.trim()).filter(Boolean))];
  if (unique.length === 0) {
    logger.info("FCM skipped: no tokens", {type: payload.type});
    return;
  }

  const data: Record<string, string> = {
    type: payload.type,
    ...(payload.data ?? {}),
  };

  const message: MulticastMessage = {
    tokens: unique,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data,
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const messaging = getMessaging();
  const response = await messaging.sendEachForMulticast(message);

  logger.info("FCM multicast sent", {
    type: payload.type,
    successCount: response.successCount,
    failureCount: response.failureCount,
    tokenCount: unique.length,
  });

  const driverIdsByToken = options?.driverIdsByToken;
  if (!driverIdsByToken || response.failureCount === 0) {
    return;
  }

  const db = getFirestore();
  const clears: Promise<unknown>[] = [];

  response.responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error?.code ?? "";
    const invalid =
      code.includes("registration-token-not-registered") ||
      code.includes("invalid-registration-token") ||
      code.includes("invalid-argument");
    if (!invalid) return;

    const token = unique[index];
    const driverId = driverIdsByToken.get(token);
    if (!driverId) return;

    clears.push(
      db
        .collection(COLLECTIONS.drivers)
        .doc(driverId)
        .update({
          [DriverFields.fcmToken]: FieldValue.delete(),
          [DriverFields.updatedAt]: FieldValue.serverTimestamp(),
        })
        .catch((err) => {
          logger.warn("Failed to clear invalid FCM token", {
            driverId,
            error: err,
          });
        }),
    );
  });

  if (clears.length > 0) {
    await Promise.all(clears);
  }
}

/** Send to one driver by uid. No-op if no token. */
export async function sendFcmToDriver(
  driverId: string,
  payload: FcmPayload,
): Promise<void> {
  const token = await getDriverFcmToken(driverId);
  if (!token) {
    logger.info("FCM skipped: driver has no token", {
      type: payload.type,
      driverId,
    });
    return;
  }

  const driverIdsByToken = new Map<string, string>([[token, driverId.trim()]]);
  await sendFcmToTokens([token], payload, {driverIdsByToken});
}

/** Reads a rider's FCM token from `users/{userId}` when present. */
export async function getUserFcmToken(userId: string): Promise<string | null> {
  const id = userId.trim();
  if (!id) return null;

  const snap = await getFirestore().collection(COLLECTIONS.users).doc(id).get();
  if (!snap.exists) return null;

  for (const key of USER_FCM_TOKEN_KEYS) {
    const token = snap.get(key);
    if (typeof token === "string" && token.trim().length > 0) {
      return token.trim();
    }
  }
  return null;
}

/**
 * Best-effort FCM to a rider. No-op when the user doc has no token.
 * Rider App should also watch Firestore `cancelledBy` / status directly.
 */
export async function sendFcmToUser(
  userId: string,
  payload: FcmPayload,
): Promise<void> {
  const token = await getUserFcmToken(userId);
  if (!token) {
    logger.info("FCM skipped: user has no token", {
      type: payload.type,
      userId,
    });
    return;
  }

  await sendFcmToTokens([token], payload);
}
