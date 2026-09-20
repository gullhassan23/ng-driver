/** Matches Flutter `FirestorePaths` / `RideFields` / `RideStatus` / `DriverFields`. */

export const COLLECTIONS = {
  rides: "rides",
  drivers: "drivers",
  driverInformation: "driver_information",
  reservations: "reservations",
  rideRequests: "rideRequests",
  driverOffers: "driverOffers",
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
} as const;

export const ReservationStatus = {
  pending: "pending",
  confirm: "confirm",
  driverArriving: "driver_arriving",
  driverArrived: "driver_arrived",
  rideStarted: "ride_started",
  completed: "completed",
  cancelled: "cancelled",
} as const;

export const ReservationFields = {
  status: "status",
  driverId: "driverId",
  rideId: "rideId",
  updatedAt: "updatedAt",
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
