import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

import {
  COLLECTIONS,
  ChatMessageFields,
  ChatSenderType,
  FcmNotificationType,
  ReservationFields,
  RideFields,
} from "../shared/constants";
import {claimFcmDispatch, sendFcmToDriver} from "./fcmSend";
import {getFirestore} from "firebase-admin/firestore";

function previewBody(message: unknown): string {
  if (typeof message !== "string") return "New message from your rider.";
  const trimmed = message.trim();
  if (!trimmed) return "New message from your rider.";
  return trimmed.length > 120 ? `${trimmed.slice(0, 117)}...` : trimmed;
}

async function notifyAssignedDriverForChat(params: {
  parentCollection: string;
  sessionId: string;
  messageId: string;
  isReservation: boolean;
  senderType: unknown;
  senderId: unknown;
  messageText: unknown;
}): Promise<void> {
  const senderType =
    typeof params.senderType === "string"
      ? params.senderType.trim().toLowerCase()
      : "";
  if (senderType !== ChatSenderType.rider) {
    return;
  }

  const senderId =
    typeof params.senderId === "string" ? params.senderId.trim() : "";

  const parentSnap = await getFirestore()
    .collection(params.parentCollection)
    .doc(params.sessionId)
    .get();
  if (!parentSnap.exists) {
    logger.info("chat FCM skipped: parent missing", {
      sessionId: params.sessionId,
      isReservation: params.isReservation,
    });
    return;
  }

  const driverField = params.isReservation
    ? ReservationFields.driverId
    : RideFields.driverId;
  const driverIdRaw = parentSnap.get(driverField);
  const driverId =
    typeof driverIdRaw === "string" ? driverIdRaw.trim() : "";
  if (!driverId) {
    return;
  }

  // Never notify the sender (defensive if mis-tagged).
  if (senderId && senderId === driverId) {
    return;
  }

  const claimed = await claimFcmDispatch(
    `${FcmNotificationType.chatMessage}_${params.parentCollection}_${params.sessionId}_${params.messageId}`,
  );
  if (!claimed) return;

  try {
    await sendFcmToDriver(driverId, {
      type: FcmNotificationType.chatMessage,
      title: "New message",
      body: previewBody(params.messageText),
      data: {
        sessionId: params.sessionId,
        isReservation: params.isReservation ? "true" : "false",
        messageId: params.messageId,
        ...(params.isReservation
          ? {reservationId: params.sessionId}
          : {rideId: params.sessionId}),
      },
    });
  } catch (error) {
    logger.error("chat_message FCM failed", {
      sessionId: params.sessionId,
      isReservation: params.isReservation,
      error,
    });
  }
}

export const onRideChatMessageCreated = onDocumentCreated(
  `${COLLECTIONS.rides}/{rideId}/${COLLECTIONS.messages}/{messageId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const rideId = event.params.rideId as string;
    const messageId = event.params.messageId as string;
    const data = snap.data();

    await notifyAssignedDriverForChat({
      parentCollection: COLLECTIONS.rides,
      sessionId: rideId,
      messageId,
      isReservation: false,
      senderType: data[ChatMessageFields.senderType],
      senderId: data[ChatMessageFields.senderId],
      messageText: data[ChatMessageFields.message],
    });
  },
);

export const onReservationChatMessageCreated = onDocumentCreated(
  `${COLLECTIONS.reservations}/{reservationId}/${COLLECTIONS.messages}/{messageId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const reservationId = event.params.reservationId as string;
    const messageId = event.params.messageId as string;
    const data = snap.data();

    await notifyAssignedDriverForChat({
      parentCollection: COLLECTIONS.reservations,
      sessionId: reservationId,
      messageId,
      isReservation: true,
      senderType: data[ChatMessageFields.senderType],
      senderId: data[ChatMessageFields.senderId],
      messageText: data[ChatMessageFields.message],
    });
  },
);
