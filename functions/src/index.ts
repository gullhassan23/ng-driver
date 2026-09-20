import {initializeApp} from "firebase-admin/app";

initializeApp();

export {onRideCreated, expirePendingRides} from "./rides/rideExpiry";
export {acceptRide} from "./rides/rideAcceptance";
export {selectDriver} from "./rides/selectDriver";
export {updateRideStatus} from "./rides/rideLifecycle";
