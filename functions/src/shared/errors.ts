import {HttpsError} from "firebase-functions/v2/https";

/** Safe client-facing messages — no internal details. */
export const SafeMessages = {
  unauthenticated: "Authentication required.",
  rideNotFound: "Ride is no longer available.",
  rideUnavailable: "Ride is no longer available.",
  alreadyAccepted: "Another driver accepted this ride first.",
  expired: "Ride has expired.",
  notApproved: "Driver is not approved.",
  notAssigned: "You are not assigned to this ride.",
  invalidStatus: "This ride cannot be updated.",
  invalidArgument: "Invalid request.",
} as const;

export function requireAuth(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", SafeMessages.unauthenticated);
  }
  return uid;
}

export function failUnavailable(message = SafeMessages.rideUnavailable): never {
  throw new HttpsError("failed-precondition", message);
}

export function failInvalidArgument(
  message: string = SafeMessages.invalidArgument,
): never {
  throw new HttpsError("invalid-argument", message);
}

export function failPermission(message: string): never {
  throw new HttpsError("permission-denied", message);
}
