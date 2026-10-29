import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  COLLECTIONS,
  CancelledBy,
  DriverFields,
  FCM_MAX_DRIVERS,
  FcmNotificationType,
  RESERVATION_WALL_CLOCK_TZ,
  ReservationFields,
  ReservationStatus,
  normalizeReservationStatus as normalizeReservationStatusValue,
} from "../shared/constants";
import {
  claimFcmDispatch,
  sendFcmToDriver,
  sendFcmToTokens,
  sendFcmToUser,
} from "./fcmSend";

function normalizeReservationStatus(status: unknown): string {
  if (typeof status !== "string") return "";
  return normalizeReservationStatusValue(status);
}

function isCancelledStatus(status: string): boolean {
  return status === ReservationStatus.cancelled || status === "canceled";
}

function reservationCustomerId(data: Record<string, unknown>): string {
  const raw =
    data[ReservationFields.userId] ??
    data[ReservationFields.customerId] ??
    data[ReservationFields.uid] ??
    "";
  return typeof raw === "string" ? raw.trim() : "";
}

function cancelledByActor(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().toLowerCase();
}

interface WallClockParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
}

function zonedParts(date: Date, timeZone: string): WallClockParts {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    hourCycle: "h23",
  }).formatToParts(date);

  const read = (type: Intl.DateTimeFormatPartTypes): number => {
    const value = parts.find((p) => p.type === type)?.value;
    return value ? Number.parseInt(value, 10) : Number.NaN;
  };

  return {
    year: read("year"),
    month: read("month"),
    day: read("day"),
    hour: read("hour"),
    minute: read("minute"),
  };
}

/**
 * Interprets year/month/day hour:minute as wall-clock in [timeZone]
 * and returns the corresponding UTC Date.
 */
export function wallClockInTimeZoneToDate(
  year: number,
  monthIndex: number,
  day: number,
  hour: number,
  minute: number,
  timeZone: string = RESERVATION_WALL_CLOCK_TZ,
): Date {
  let utcMs = Date.UTC(year, monthIndex, day, hour, minute, 0);
  for (let i = 0; i < 3; i++) {
    const parts = zonedParts(new Date(utcMs), timeZone);
    if (
      [parts.year, parts.month, parts.day, parts.hour, parts.minute].some(
        (n) => Number.isNaN(n),
      )
    ) {
      break;
    }
    const asIfUtc = Date.UTC(
      parts.year,
      parts.month - 1,
      parts.day,
      parts.hour,
      parts.minute,
      0,
    );
    const wanted = Date.UTC(year, monthIndex, day, hour, minute, 0);
    utcMs += wanted - asIfUtc;
  }
  return new Date(utcMs);
}

function calendarDateInZone(
  instant: Date,
  timeZone: string,
): {year: number; monthIndex: number; day: number} | null {
  const parts = zonedParts(instant, timeZone);
  if (
    [parts.year, parts.month, parts.day].some((n) => Number.isNaN(n))
  ) {
    return null;
  }
  return {
    year: parts.year,
    monthIndex: parts.month - 1,
    day: parts.day,
  };
}

/**
 * Combines pickupDate + pickupTime into an absolute Date using
 * [RESERVATION_WALL_CLOCK_TZ] wall-clock (not raw UTC).
 */
export function parseReservationScheduledAt(
  data: Record<string, unknown>,
  timeZone: string = RESERVATION_WALL_CLOCK_TZ,
): Date | null {
  const pickupDateRaw = data[ReservationFields.pickupDate];
  let year: number;
  let monthIndex: number;
  let day: number;

  if (pickupDateRaw instanceof Timestamp) {
    const cal = calendarDateInZone(pickupDateRaw.toDate(), timeZone);
    if (!cal) return null;
    year = cal.year;
    monthIndex = cal.monthIndex;
    day = cal.day;
  } else if (pickupDateRaw instanceof Date) {
    const cal = calendarDateInZone(pickupDateRaw, timeZone);
    if (!cal) return null;
    year = cal.year;
    monthIndex = cal.monthIndex;
    day = cal.day;
  } else {
    return null;
  }

  const timeRaw =
    typeof data[ReservationFields.pickupTime] === "string"
      ? (data[ReservationFields.pickupTime] as string).trim()
      : "";
  if (!timeRaw) return null;

  const match12 = /^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM|am|pm)$/.exec(
    timeRaw,
  );
  if (match12) {
    let hour = Number.parseInt(match12[1], 10);
    const minute = Number.parseInt(match12[2], 10);
    const period = match12[4].toUpperCase();
    if (period === "PM" && hour < 12) hour += 12;
    if (period === "AM" && hour === 12) hour = 0;
    return wallClockInTimeZoneToDate(
      year,
      monthIndex,
      day,
      hour,
      minute,
      timeZone,
    );
  }

  const match24 = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(timeRaw);
  if (match24) {
    const hour = Number.parseInt(match24[1], 10);
    const minute = Number.parseInt(match24[2], 10);
    return wallClockInTimeZoneToDate(
      year,
      monthIndex,
      day,
      hour,
      minute,
      timeZone,
    );
  }

  const parsed = Date.parse(timeRaw);
  if (!Number.isNaN(parsed)) {
    const t = new Date(parsed);
    const timeParts = zonedParts(t, timeZone);
    return wallClockInTimeZoneToDate(
      year,
      monthIndex,
      day,
      timeParts.hour,
      timeParts.minute,
      timeZone,
    );
  }

  return null;
}

/** Notify approved drivers (not online-gated) about a new pending reservation. */
export const onReservationCreated = onDocumentCreated(
  `${COLLECTIONS.reservations}/{reservationId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const reservationId = event.params.reservationId as string;
    const data = snap.data();
    const status = normalizeReservationStatus(data[ReservationFields.status]);
    if (status !== ReservationStatus.pending) {
      return;
    }

    const claimed = await claimFcmDispatch(
      `${FcmNotificationType.newReservation}_${reservationId}`,
    );
    if (!claimed) return;

    if (data[ReservationFields.fcmNotifiedAt]) {
      return;
    }

    try {
      const db = getFirestore();
      const driversSnap = await db
        .collection(COLLECTIONS.drivers)
        .where(DriverFields.isApproved, "==", true)
        .limit(FCM_MAX_DRIVERS)
        .get();

      const tokens: string[] = [];
      const driverIdsByToken = new Map<string, string>();

      for (const doc of driversSnap.docs) {
        const token = doc.get(DriverFields.fcmToken);
        if (typeof token === "string" && token.trim().length > 0) {
          const trimmed = token.trim();
          tokens.push(trimmed);
          driverIdsByToken.set(trimmed, doc.id);
        }
      }

      if (tokens.length > 0) {
        await sendFcmToTokens(
          tokens,
          {
            type: FcmNotificationType.newReservation,
            title: "New reservation request",
            body: "A rider booked a reservation. Open the app to review.",
            data: {reservationId},
          },
          {driverIdsByToken},
        );
      } else {
        logger.info("No tokens for new_reservation", {reservationId});
      }

      await snap.ref.set(
        {
          [ReservationFields.fcmNotifiedAt]: FieldValue.serverTimestamp(),
          [ReservationFields.updatedAt]: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    } catch (error) {
      logger.error("new_reservation FCM failed", {reservationId, error});
    }
  },
);

/**
 * Notify the other party when a reservation is cancelled.
 * Uses cancelledBy so driver-initiated cancels notify the rider, not the driver.
 */
export const onReservationUpdated = onDocumentUpdated(
  `${COLLECTIONS.reservations}/{reservationId}`,
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const reservationId = event.params.reservationId as string;
    const prevStatus = normalizeReservationStatus(
      before.get(ReservationFields.status),
    );
    const nextStatus = normalizeReservationStatus(
      after.get(ReservationFields.status),
    );

    if (isCancelledStatus(prevStatus) || !isCancelledStatus(nextStatus)) {
      return;
    }

    const afterData = after.data() as Record<string, unknown>;
    const driverIdRaw = after.get(ReservationFields.driverId);
    const driverId =
      typeof driverIdRaw === "string" ? driverIdRaw.trim() : "";
    const customerId = reservationCustomerId(afterData);
    const cancelledBy = cancelledByActor(
      after.get(ReservationFields.cancelledBy),
    );

    const claimed = await claimFcmDispatch(
      `${FcmNotificationType.reservationCancelled}_${reservationId}`,
    );
    if (!claimed) return;

    try {
      if (cancelledBy === CancelledBy.driver) {
        if (!customerId) {
          logger.info("reservation_cancelled: no customer to notify", {
            reservationId,
          });
          return;
        }
        await sendFcmToUser(customerId, {
          type: FcmNotificationType.reservationCancelled,
          title: "Reservation cancelled",
          body: "Your driver cancelled this reservation.",
          data: {
            reservationId,
            cancelledBy: CancelledBy.driver,
          },
        });
        return;
      }

      // Rider cancel (or legacy missing attribution with an assigned driver).
      if (!driverId) {
        // Unassigned pending cancel — no recipient.
        return;
      }
      await sendFcmToDriver(driverId, {
        type: FcmNotificationType.reservationCancelled,
        title: "Reservation cancelled",
        body: "A rider cancelled your confirmed reservation.",
        data: {
          reservationId,
          cancelledBy: cancelledBy || CancelledBy.rider,
        },
      });
    } catch (error) {
      logger.error("reservation_cancelled FCM failed", {
        reservationId,
        error,
      });
    }
  },
);

const REMINDER_WINDOW_MS = 60 * 60 * 1000;

/**
 * Every 5 minutes: remind assigned drivers of confirmed reservations
 * whose pickup is within the next 60 minutes (once per reservation).
 */
export const sendReservationReminders = onSchedule(
  "every 5 minutes",
  async () => {
    const db = getFirestore();
    const now = Date.now();

    const snap = await db
      .collection(COLLECTIONS.reservations)
      .where(ReservationFields.status, "==", ReservationStatus.confirm)
      .limit(100)
      .get();

    if (snap.empty) {
      logger.info("sendReservationReminders: none");
      return;
    }

    let sent = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      if (data[ReservationFields.reminderSentAt]) continue;

      const driverIdRaw = data[ReservationFields.driverId];
      const driverId =
        typeof driverIdRaw === "string" ? driverIdRaw.trim() : "";
      if (!driverId) continue;

      const scheduled = parseReservationScheduledAt(data);
      if (!scheduled) continue;

      const msUntil = scheduled.getTime() - now;
      if (msUntil <= 0 || msUntil > REMINDER_WINDOW_MS) continue;

      const reservationId = doc.id;
      const claimed = await claimFcmDispatch(
        `${FcmNotificationType.reservationReminder}_${reservationId}`,
      );
      if (!claimed) continue;

      try {
        await sendFcmToDriver(driverId, {
          type: FcmNotificationType.reservationReminder,
          title: "Upcoming reservation",
          body: "You have a confirmed reservation within the next hour.",
          data: {reservationId},
        });

        await doc.ref.set(
          {
            [ReservationFields.reminderSentAt]: FieldValue.serverTimestamp(),
            [ReservationFields.updatedAt]: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        sent += 1;
      } catch (error) {
        logger.error("reservation_reminder FCM failed", {
          reservationId,
          error,
        });
      }
    }

    logger.info("sendReservationReminders: done", {sent, scanned: snap.size});
  },
);
