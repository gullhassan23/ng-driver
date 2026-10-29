/** Matches Flutter `FirestorePaths` / `RideFields` / `RideStatus` / `DriverFields`. */

export const COLLECTIONS = {
  rides: "rides",
  drivers: "drivers",
  driverInformation: "driver_information",
  reservations: "reservations",
  rideRequests: "rideRequests",
  driverOffers: "driverOffers",
  /** Rider profiles (FCM token for passenger notifications). */
  users: "users",
  /** Admin-only idempotency ledger for FCM sends. */
  fcmDispatches: "fcm_dispatches",
  messages: "messages",
} as const;

/** Who initiated a cancel — shared by rides and reservations. */
export const CancelledBy = {
  driver: "driver",
  rider: "rider",
  user: "user",
} as const;

/** FCM `data.type` values — must match Flutter `NotificationTypes`. */
export const FcmNotificationType = {
  newRide: "new_ride",
  newReservation: "new_reservation",
  chatMessage: "chat_message",
  rideCancelled: "ride_cancelled",
  reservationCancelled: "reservation_cancelled",
  passengerArriving: "passenger_arriving",
  driverApproved: "driver_approved",
  reservationReminder: "reservation_reminder",
  /** Rider: driver claimed / on the way (pending → driver_arriving). */
  rideAccepted: "ride_accepted",
  /** Rider: driver reached pickup. */
  driverArrived: "driver_arrived",
  /** Rider: trip finished. */
  rideCompleted: "ride_completed",
} as const;

/**
 * Wall-clock timezone for reservation pickupDate + pickupTime on the server.
 * Clients parse as device-local; Functions have no device locale, so Eastern
 * (NG Town Car service area) is the canonical interpretation.
 */
export const RESERVATION_WALL_CLOCK_TZ = "America/New_York";

export const ChatMessageFields = {
  senderId: "senderId",
  senderType: "senderType",
  message: "message",
  createdAt: "createdAt",
  read: "read",
  type: "type",
} as const;

export const ChatSenderType = {
  rider: "rider",
  driver: "driver",
} as const;

export const RideStatus = {
  pending: "pending",
  /** Legacy claim status; dual-read only. */
  accepted: "accepted",
  /** Legacy rider-selected assignment; dual-read only — new writes use driverArriving. */
  driverSelected: "driver_selected",
  driverArriving: "driver_arriving",
  driverArrived: "driver_arrived",
  /** Rider acknowledged they are coming (unlocks Start Ride). */
  passengerArriving: "passenger_arriving",
  rideStarted: "ride_started",
  /** Legacy dual-read only — new writes use passengerArriving. */
  riderArrived: "riderArrived",
  /** Legacy — dual-read only; new writes use rideStarted. */
  inProgress: "inProgress",
  /** Rider-app / rules snake_case alias; dual-read only. */
  inProgressSnake: "in_progress",
  completed: "completed",
  cancelled: "cancelled",
  expired: "expired",
} as const;

/** Map Firestore / console aliases onto canonical statuses. */
export function normalizeRideStatus(status: string): string {
  const trimmed = status.trim();
  switch (trimmed) {
    case RideStatus.inProgress:
    case RideStatus.inProgressSnake:
      return RideStatus.rideStarted;
    case "canceled":
      return RideStatus.cancelled;
    case RideStatus.accepted:
    case "selected":
      return RideStatus.driverSelected;
    default:
      return trimmed;
  }
}

/** Active trip phase: ride_started or legacy inProgress / in_progress. */
export function isTripInProgressStatus(status: string): boolean {
  return normalizeRideStatus(status) === RideStatus.rideStarted;
}

/** Assigned but not yet moving toward pickup. */
export function isPreArrivingAssignedStatus(status: string): boolean {
  return normalizeRideStatus(status) === RideStatus.driverSelected;
}

/** Assigned driver still on an open ride. */
export function isActiveAssignedStatus(status: string): boolean {
  const value = normalizeRideStatus(status);
  return (
    value === RideStatus.driverSelected ||
    value === RideStatus.driverArriving ||
    value === RideStatus.driverArrived ||
    value === RideStatus.passengerArriving ||
    value === RideStatus.rideStarted ||
    value === RideStatus.riderArrived
  );
}

export const DriverOfferStatus = {
  driverAccepted: "driver_accepted",
  riderSelected: "rider_selected",
  riderDeclined: "rider_declined",
  expired: "expired",
  cancelled: "cancelled",
} as const;

export const DriverOfferFields = {
  driverId: "driverId",
  driverName: "driverName",
  driverFirstName: "driverFirstName",
  driverLastName: "driverLastName",
  driverPhone: "driverPhone",
  driverVehicleType: "driverVehicleType",
  driverVehicleMake: "driverVehicleMake",
  driverVehicleModel: "driverVehicleModel",
  driverVehicleColor: "driverVehicleColor",
  driverVehicleRegistration: "driverVehicleRegistration",
  /** Driver GPS + address at offer submission. */
  driverLatitude: "driverLatitude",
  driverLongitude: "driverLongitude",
  driverAddress: "driverAddress",
  status: "status",
  acceptedAt: "acceptedAt",
  createdAt: "createdAt",
  updatedAt: "updatedAt",
} as const;

export type RideStatusValue = (typeof RideStatus)[keyof typeof RideStatus];

export const RideFields = {
  rideId: "rideId",
  customerId: "customerId",
  customerName: "customerName",
  estimatedFare: "estimatedFare",
  pickupLatitude: "pickupLatitude",
  pickupLongitude: "pickupLongitude",
  dropoffLatitude: "dropoffLatitude",
  dropoffLongitude: "dropoffLongitude",
  /** Optional intermediate stops: [{location, latitude, longitude, order}]. */
  stops: "stops",
  /** Next stop index; when >= stops.length the target is dropoff. */
  currentStopIndex: "currentStopIndex",
  status: "status",
  driverId: "driverId",
  createdAt: "createdAt",
  acceptedAt: "acceptedAt",
  /** Set when status becomes driver_arriving. */
  arrivingAt: "arrivingAt",
  updatedAt: "updatedAt",
  completedAt: "completedAt",
  startedAt: "startedAt",
  expiresAt: "expiresAt",
  riderArrived: "riderArrived",
  riderArrivedAt: "riderArrivedAt",
  cancelledAt: "cancelledAt",
  cancelledBy: "cancelledBy",
  cancellationReason: "cancellationReason",
  /** Live GPS map written by the driver client. */
  driverLocation: "driverLocation",
  driverLocationUpdatedAt: "driverLocationUpdatedAt",
  driverArrivedAt: "driverArrivedAt",
  driverFirstName: "driverFirstName",
  driverLastName: "driverLastName",
  driverName: "driverName",
  driverPhone: "driverPhone",
  driverVehicleType: "driverVehicleType",
  driverVehicleMake: "driverVehicleMake",
  driverVehicleModel: "driverVehicleModel",
  driverVehicleColor: "driverVehicleColor",
  driverVehicleRegistration: "driverVehicleRegistration",
  driverVehicle: "driverVehicle",
  driverVehicleNumber: "driverVehicleNumber",
  driverRating: "driverRating",
  driverDistanceMiles: "driverDistanceMiles",
  driverEta: "driverEta",
  /** Linked reservation when this ride was started from a booking. */
  reservationId: "reservationId",
  /** Rider-selected method. Written by rider/backend; never marked paid by drivers. */
  paymentMethod: "paymentMethod",
  paymentStatus: "paymentStatus",
  paymentTransactionId: "paymentTransactionId",
  paymentAmount: "paymentAmount",
  cardLast4: "cardLast4",
  paidAt: "paidAt",
  /** Set after first successful new_ride FCM fan-out (idempotency). */
  fcmNotifiedAt: "fcmNotifiedAt",
} as const;

export const ReservationStatus = {
  pending: "pending",
  confirm: "confirm",
  /** Legacy dual-read aliases. */
  confirmed: "confirmed",
  upcoming: "upcoming",
  accepted: "accepted",
  driverArriving: "driver_arriving",
  driverArrived: "driver_arrived",
  rideStarted: "ride_started",
  completed: "completed",
  cancelled: "cancelled",
} as const;

export function normalizeReservationStatus(status: string): string {
  const value = status.trim().toLowerCase();
  if (value === "canceled") return ReservationStatus.cancelled;
  if (
    value === ReservationStatus.confirmed ||
    value === ReservationStatus.upcoming ||
    value === ReservationStatus.accepted
  ) {
    return ReservationStatus.confirm;
  }
  return value;
}

export function isConfirmReservationStatus(status: string): boolean {
  return normalizeReservationStatus(status) === ReservationStatus.confirm;
}

/** Status values that normalize to confirmed (for Firestore `in` queries). */
export const RESERVATION_CONFIRM_STATUS_VALUES = [
  ReservationStatus.confirm,
  ReservationStatus.confirmed,
  ReservationStatus.upcoming,
  ReservationStatus.accepted,
] as const;

/** Confirmed or live reservation phases (assigned, not terminal). */
export function isActiveReservationLifecycleStatus(status: string): boolean {
  const value = normalizeReservationStatus(status);
  return (
    value === ReservationStatus.confirm ||
    value === ReservationStatus.driverArriving ||
    value === ReservationStatus.driverArrived ||
    value === ReservationStatus.rideStarted
  );
}

export const ReservationFields = {
  status: "status",
  driverId: "driverId",
  rideId: "rideId",
  updatedAt: "updatedAt",
  pickupDate: "pickupDate",
  pickupTime: "pickupTime",
  userId: "userId",
  customerId: "customerId",
  uid: "uid",
  cancelledAt: "cancelledAt",
  cancelledBy: "cancelledBy",
  /** Preferred cancel reason key (also dual-read cancelReason). */
  cancellationReason: "cancellationReason",
  cancelReason: "cancelReason",
  /** Set after reservation_reminder FCM (idempotency). */
  reminderSentAt: "reminderSentAt",
  /** Set after first successful new_reservation FCM fan-out. */
  fcmNotifiedAt: "fcmNotifiedAt",
} as const;

export const DriverFields = {
  uid: "uid",
  firstName: "firstName",
  lastName: "lastName",
  phone: "phone",
  vehicleType: "vehicleType",
  vehicleMake: "vehicleMake",
  vehicleModel: "vehicleModel",
  vehicleColor: "vehicleColor",
  vehicleRegistration: "vehicleRegistration",
  rating: "rating",
  isOnline: "isOnline",
  isApproved: "isApproved",
  fcmToken: "fcmToken",
  currentRideId: "currentRideId",
  updatedAt: "updatedAt",
} as const;

/** How long a pending ride stays claimable. */
export const RIDE_EXPIRY_MS = 5 * 60 * 1000;

/** Cap FCM fan-out per new ride (no geo filter yet). */
export const FCM_MAX_DRIVERS = 50;

/** Maximum straight-line distance (miles) a driver can be from pickup to accept a ride. */
export const RIDE_REQUEST_RADIUS_MILES = 1.0;

