import {DriverFields, RideFields} from "./constants";
import {formatDriverEta, milesBetween} from "./geo";

function textField(
  data: Record<string, unknown> | undefined,
  key: string,
): string {
  const value = data?.[key];
  return typeof value === "string" ? value.trim() : "";
}

function optionalFiniteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function ratingFromDriver(
  driverData: Record<string, unknown> | undefined,
): number {
  const raw = driverData?.[DriverFields.rating] ?? driverData?.["driverRating"];
  const value = optionalFiniteNumber(raw);
  if (value !== undefined && value >= 0) return value;
  return 5;
}

/** Pickup ETA + miles from the driver's current GPS. */
export function pickupEtaFields(params: {
  driverLatitude?: number;
  driverLongitude?: number;
  pickupLatitude?: number;
  pickupLongitude?: number;
}): Record<string, unknown> {
  const {driverLatitude, driverLongitude, pickupLatitude, pickupLongitude} =
    params;
  if (
    driverLatitude === undefined ||
    driverLongitude === undefined ||
    pickupLatitude === undefined ||
    pickupLongitude === undefined
  ) {
    return {};
  }

  const miles = milesBetween(
    driverLatitude,
    driverLongitude,
    pickupLatitude,
    pickupLongitude,
  );
  return {
    [RideFields.driverDistanceMiles]: Math.round(miles * 1000) / 1000,
    [RideFields.driverEta]: formatDriverEta(miles),
  };
}

/** Denormalized driver snapshot written onto `rides/{rideId}` at accept. */
export function assignedDriverRideFields(params: {
  driverData: Record<string, unknown> | undefined;
  driverLatitude?: number;
  driverLongitude?: number;
  pickupLatitude?: number;
  pickupLongitude?: number;
}): Record<string, unknown> {
  const {
    driverData,
    driverLatitude,
    driverLongitude,
    pickupLatitude,
    pickupLongitude,
  } = params;

  const firstName = textField(driverData, DriverFields.firstName);
  const lastName = textField(driverData, DriverFields.lastName);
  const make = textField(driverData, DriverFields.vehicleMake);
  const model = textField(driverData, DriverFields.vehicleModel);
  const type = textField(driverData, DriverFields.vehicleType);
  const registration = textField(driverData, DriverFields.vehicleRegistration);
  const makeModel = `${make} ${model}`.trim();

  return {
    [RideFields.driverFirstName]: firstName,
    [RideFields.driverLastName]: lastName,
    [RideFields.driverName]: `${firstName} ${lastName}`.trim(),
    [RideFields.driverPhone]: textField(driverData, DriverFields.phone),
    [RideFields.driverVehicleType]: type,
    [RideFields.driverVehicleMake]: make,
    [RideFields.driverVehicleModel]: model,
    [RideFields.driverVehicleColor]: textField(
      driverData,
      DriverFields.vehicleColor,
    ),
    [RideFields.driverVehicleRegistration]: registration,
    [RideFields.driverVehicle]: makeModel || type,
    [RideFields.driverVehicleNumber]: registration,
    [RideFields.driverRating]: ratingFromDriver(driverData),
    ...pickupEtaFields({
      driverLatitude,
      driverLongitude,
      pickupLatitude,
      pickupLongitude,
    }),
  };
}
