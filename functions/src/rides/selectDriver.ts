import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  COLLECTIONS,
  DriverFields,
  DriverOfferFields,
  DriverOfferStatus,
  RideFields,
  RideStatus,
  isActiveAssignedStatus,
} from "../shared/constants";
import {
  SafeMessages,
  failInvalidArgument,
  requireAuth,
} from "../shared/errors";

interface SelectDriverRequest {
  rideId?: string;
  driverId?: string;
}

function textField(
  data: Record<string, unknown> | undefined,
  key: string,
): string {
  const value = data?.[key];
  return typeof value === "string" ? value : "";
}

/**
 * Atomically select one driver from pending offers.
 * Only the rider (customerId) may call this.
 */
export const selectDriver = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const data = (request.data ?? {}) as SelectDriverRequest;
  const rideId = typeof data.rideId === "string" ? data.rideId.trim() : "";
  const selectedDriverId =
    typeof data.driverId === "string" ? data.driverId.trim() : "";

  if (!rideId) {
    failInvalidArgument("rideId is required.");
  }
  if (!selectedDriverId) {
    failInvalidArgument("driverId is required.");
  }

  const db = getFirestore();
  const rideRef = db.collection(COLLECTIONS.rides).doc(rideId);
  const selectedOfferRef = rideRef
    .collection(COLLECTIONS.driverOffers)
    .doc(selectedDriverId);
  const selectedDriverRef = db
    .collection(COLLECTIONS.drivers)
    .doc(selectedDriverId);

  let denial: HttpsError | undefined;
  let resultStatus: string = RideStatus.pending;

  await db.runTransaction(async (tx) => {
    denial = undefined;

    const rideSnap = await tx.get(rideRef);
    const offerSnap = await tx.get(selectedOfferRef);
    const driverSnap = await tx.get(selectedDriverRef);

    if (!rideSnap.exists) {
      denial = new HttpsError("failed-precondition", SafeMessages.rideNotFound);
      return;
    }

    const customerId = rideSnap.get(RideFields.customerId) as
      | string
      | undefined;
    if (!customerId || customerId !== uid) {
      denial = new HttpsError(
        "permission-denied",
        "Only the rider can select a driver.",
      );
      return;
    }

    const status = rideSnap.get(RideFields.status) as string | undefined;
    const existingDriverId = rideSnap.get(RideFields.driverId) as
      | string
      | undefined;

    if (existingDriverId && existingDriverId !== selectedDriverId) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.alreadyAccepted,
      );
      return;
    }

    if (status && isActiveAssignedStatus(status)) {
      if (existingDriverId === selectedDriverId) {
        resultStatus = status;
        return;
      }
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.alreadyAccepted,
      );
      return;
    }

    if (status !== RideStatus.pending && status !== RideStatus.expired) {
      denial = new HttpsError(
        "failed-precondition",
        SafeMessages.rideUnavailable,
      );
      return;
    }

    if (!offerSnap.exists) {
      denial = new HttpsError(
        "failed-precondition",
        "Selected driver has not accepted this ride.",
      );
      return;
    }

    const offerStatus = offerSnap.get(DriverOfferFields.status) as
      | string
      | undefined;

    if (offerStatus !== DriverOfferStatus.driverAccepted) {
      denial = new HttpsError(
        "failed-precondition",
        "Selected driver offer is no longer available.",
      );
      return;
    }

    const offerData = offerSnap.data() as Record<string, unknown> | undefined;
    const driverData = driverSnap.data() as Record<string, unknown> | undefined;

    const firstName =
      textField(offerData, DriverOfferFields.driverFirstName) ||
      textField(driverData, DriverFields.firstName);
    const lastName =
      textField(offerData, DriverOfferFields.driverLastName) ||
      textField(driverData, DriverFields.lastName);
    const driverName =
      textField(offerData, DriverOfferFields.driverName) ||
      `${firstName} ${lastName}`.trim();

    tx.update(rideRef, {
      [RideFields.status]: RideStatus.driverSelected,
      [RideFields.driverId]: selectedDriverId,
      [RideFields.acceptedAt]: FieldValue.serverTimestamp(),
      [RideFields.updatedAt]: FieldValue.serverTimestamp(),
      [RideFields.driverFirstName]: firstName,
      [RideFields.driverLastName]: lastName,
      [RideFields.driverName]: driverName,
      [RideFields.driverPhone]:
        textField(offerData, DriverOfferFields.driverPhone) ||
        textField(driverData, DriverFields.phone),
      [RideFields.driverVehicleType]:
        textField(offerData, DriverOfferFields.driverVehicleType) ||
        textField(driverData, DriverFields.vehicleType),
      [RideFields.driverVehicleMake]:
        textField(offerData, DriverOfferFields.driverVehicleMake) ||
        textField(driverData, DriverFields.vehicleMake),
      [RideFields.driverVehicleModel]:
        textField(offerData, DriverOfferFields.driverVehicleModel) ||
        textField(driverData, DriverFields.vehicleModel),
      [RideFields.driverVehicleColor]:
        textField(offerData, DriverOfferFields.driverVehicleColor) ||
        textField(driverData, DriverFields.vehicleColor),
      [RideFields.driverVehicleRegistration]:
        textField(offerData, DriverOfferFields.driverVehicleRegistration) ||
        textField(driverData, DriverFields.vehicleRegistration),
    });

    tx.update(selectedOfferRef, {
      [DriverOfferFields.status]: DriverOfferStatus.riderSelected,
      [DriverOfferFields.updatedAt]: FieldValue.serverTimestamp(),
    });

    tx.set(
      selectedDriverRef,
      {
        [DriverFields.currentRideId]: rideId,
        [DriverFields.updatedAt]: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    resultStatus = RideStatus.driverSelected;
  });

  if (denial) {
    throw denial;
  }

  const offersSnap = await rideRef.collection(COLLECTIONS.driverOffers).get();
  const batch = db.batch();
  let declinedCount = 0;

  for (const doc of offersSnap.docs) {
    if (doc.id === selectedDriverId) continue;
    const offerStatus = doc.get(DriverOfferFields.status) as string | undefined;
    if (offerStatus === DriverOfferStatus.driverAccepted) {
      batch.update(doc.ref, {
        [DriverOfferFields.status]: DriverOfferStatus.riderDeclined,
        [DriverOfferFields.updatedAt]: FieldValue.serverTimestamp(),
      });
      declinedCount++;
    }
  }

  if (declinedCount > 0) {
    await batch.commit();
  }

  logger.info("Driver selected for ride", {
    rideId,
    driverId: selectedDriverId,
    declinedCount,
  });

  return {
    ok: true,
    rideId,
    driverId: selectedDriverId,
    status: resultStatus,
  };
});
