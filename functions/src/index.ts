/**
 * LEGACY entrypoint — DO NOT DEPLOY.
 * Canonical Cloud Functions for project ng-town-car-ride live in
 * ng_town_cab/functions. Deploying this tree overwrites shared callables
 * (including cancelReservation) and can delete payment functions.
 *
 * Driver reservation cancel is now: driverCancelReservation
 * (exported from ng_town_cab/functions).
 */

import {initializeApp} from "firebase-admin/app";

initializeApp();

export {onRideCreated, expirePendingRides} from "./rides/rideExpiry";
export {acceptRide} from "./rides/rideAcceptance";
export {selectDriver} from "./rides/selectDriver";
export {updateRideStatus} from "./rides/rideLifecycle";
/** @deprecated Use driverCancelReservation from ng_town_cab/functions. */
export {cancelReservation} from "./rides/cancelReservation";

export {
  onReservationCreated,
  onReservationUpdated,
  sendReservationReminders,
} from "./notifications/reservationNotifications";
export {
  onRideChatMessageCreated,
  onReservationChatMessageCreated,
} from "./notifications/chatNotifications";
export {
  onRideUpdated,
  onDriverUpdated,
} from "./notifications/lifecycleNotifications";
