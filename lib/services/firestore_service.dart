import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/driver_information_model.dart';
import '../models/driver_model.dart';
import '../models/driver_offer_model.dart';
import '../models/reservation_model.dart';
import '../models/ride_model.dart';
import '../models/ride_request_model.dart';
import '../utilis/driver_ride_snapshot.dart';
import '../utilis/firestore_paths.dart';

/// Reads and writes the collections shared with the NG Town Ride user app.
class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _drivers =>
      _db.collection(FirestorePaths.drivers);

  CollectionReference<Map<String, dynamic>> get _driverInformation =>
      _db.collection(FirestorePaths.driverInformation);

  CollectionReference<Map<String, dynamic>> get _rideRequests =>
      _db.collection(FirestorePaths.rideRequests);

  CollectionReference<Map<String, dynamic>> get _rides =>
      _db.collection(FirestorePaths.rides);

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _db.collection(FirestorePaths.reservations);

  // ==========================================
  // DRIVER PROFILE
  // ==========================================

  Future<void> saveDriverProfile(DriverModel driver) {
    return _drivers.doc(driver.uid).set(
      {
        ...driver.toMap(),
        DriverFields.profileComplete: true,
        DriverFields.updatedAt: FieldValue.serverTimestamp(),
        // createdAt is set once at signup; do not overwrite on merge.
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateDriverFields(
    String uid,
    Map<String, dynamic> fields,
  ) {
    return _drivers.doc(uid).set(
      {
        ...fields,
        DriverFields.updatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Merge into `drivers/{uid}`. If the doc is missing, this is a create and
  /// must include `isApproved: false`. Never send `isApproved` on update so
  /// admin approval cannot be flipped from the client.
  Future<void> upsertDriverFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    final payload = Map<String, dynamic>.from(fields)
      ..remove(DriverFields.isApproved);

    final existing = await _drivers.doc(uid).get();

    if (!existing.exists) {
      payload[DriverFields.uid] = uid;
      payload[DriverFields.isApproved] = false;
      payload[DriverFields.isOnline] = payload[DriverFields.isOnline] ?? false;
      payload[DriverFields.createdAt] = FieldValue.serverTimestamp();
    }

    return updateDriverFields(uid, payload);
  }

  Future<void> markDriverProfileComplete(String uid) {
    return updateDriverFields(uid, {
      DriverFields.profileComplete: true,
    });
  }

  Future<void> saveFcmToken(String uid, String token) {
    return updateDriverFields(uid, {DriverFields.fcmToken: token});
  }

  Future<void> setOnlineStatus(String uid, bool isOnline) {
    return updateDriverFields(uid, {DriverFields.isOnline: isOnline});
  }

  /// Goes offline, clears the active-ride pointer, and drops the FCM token
  /// before document + Auth deletion.
  Future<void> deactivateDriverAccount(String uid) {
    return updateDriverFields(uid, {
      DriverFields.isOnline: false,
      DriverFields.fcmToken: FieldValue.delete(),
      DriverFields.currentRideId: FieldValue.delete(),
    });
  }

  /// Permanently removes driver-owned Firestore docs for [uid].
  ///
  /// Deletes `driver_information/{uid}` then `drivers/{uid}`.
  /// Missing documents are treated as success (already gone).
  /// Does not touch shared rides, reservations, offers, or chat.
  Future<void> deleteDriverOwnedData(String uid) async {
    await _deleteDocIfExists(_driverInformation.doc(uid));
    await _deleteDocIfExists(_drivers.doc(uid));
  }

  Future<void> _deleteDocIfExists(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.delete();
    } on FirebaseException catch (error) {
      // Doc already absent — treat as success for account deletion.
      if (error.code == 'not-found') return;
      rethrow;
    }
  }

  Future<DriverModel?> fetchDriver(String uid) async {
    final doc = await _drivers.doc(uid).get();

    if (!doc.exists) return null;

    return DriverModel.fromDoc(doc);
  }

  Stream<DriverModel?> watchDriver(String uid) {
    return _drivers.doc(uid).snapshots().map(
          (doc) => doc.exists ? DriverModel.fromDoc(doc) : null,
        );
  }

  // ==========================================
  // DRIVER INFORMATION (CNIC / vehicle form)
  // ==========================================

  Future<void> saveDriverInformation(DriverInformationModel info) {
    // Merge-only write: no pre-read (avoids permission-denied when get is
    // blocked). createdAt lives on drivers/{uid}; skip it here so we never
    // clobber an existing timestamp.
    return _driverInformation.doc(info.uid).set(
      {
        ...info.toMap(),
        DriverInformationFields.updatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<DriverInformationModel?> fetchDriverInformation(String uid) async {
    final doc = await _driverInformation.doc(uid).get();

    if (!doc.exists) return null;

    return DriverInformationModel.fromDoc(doc);
  }

  // ==========================================
  // RIDE REQUESTS (legacy listener — User app books via `rides`)
  // ==========================================

  /// Live feed of unclaimed ride requests (legacy). Prefer [pendingRides].
  Stream<List<RideRequestModel>> pendingRideRequests({int limit = 20}) {
    return _rideRequests
        .where(RideFields.status, isEqualTo: RideStatus.pending)
        .orderBy(RideFields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RideRequestModel.fromDoc)
              .toList(),
        );
  }

  Stream<RideRequestModel?> watchRideRequest(String rideId) {
    return _rideRequests.doc(rideId).snapshots().map(
          (doc) => doc.exists ? RideRequestModel.fromDoc(doc) : null,
        );
  }

  Future<RideRequestModel?> fetchRideRequest(String rideId) async {
    final doc = await _rideRequests.doc(rideId).get();

    if (!doc.exists) return null;

    return RideRequestModel.fromDoc(doc);
  }

  /// Legacy client transaction on `rideRequests`. Prefer [acceptRide].
  @Deprecated('Use acceptRide callable against the rides collection')
  Future<bool> acceptRideRequest({
    required String rideId,
    required String driverId,
    double? offeredFare,
  }) async {
    final rideRef = _rideRequests.doc(rideId);

    return _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(rideRef);

      if (!snapshot.exists) return false;

      final status = snapshot.data()?[RideFields.status] as String?;

      if (status != RideStatus.pending) return false;

      transaction.update(rideRef, {
        RideFields.status: RideStatus.accepted,
        RideFields.driverId: driverId,
        RideFields.acceptedAt: FieldValue.serverTimestamp(),
        RideFields.fare: ?offeredFare,
      });

      return true;
    });
  }

  // ==========================================
  // RIDES (authoritative booking collection)
  // ==========================================

  /// Live feed of rides waiting for a driver decision.
  ///
  /// Includes `expired` while the 5-minute timer is skipped so older rides
  /// remain claimable. Equality/`whereIn` only (no orderBy) so a composite
  /// index is not required; newest-first ordering is applied in memory.
  Stream<List<RideModel>> pendingRides({int limit = 20}) {
    return _rides
        .where(
          RideFields.status,
          whereIn: [RideStatus.pending, RideStatus.expired],
        )
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs.map(RideModel.fromDoc).toList()
            ..sort((a, b) {
              final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

          if (rides.length <= limit) return rides;
          return rides.sublist(0, limit);
        });
  }

  Future<RideModel?> fetchRide(String rideId) async {
    final doc = await _rides.doc(rideId).get();

    if (!doc.exists) return null;

    return RideModel.fromDoc(doc);
  }

  /// Live updates for a single `rides/{rideId}` document.
  Stream<RideModel?> watchRide(String rideId) {
    return _rides.doc(rideId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RideModel.fromDoc(doc);
    });
  }

  DocumentReference<Map<String, dynamic>> _driverOfferRef(
    String rideId,
    String driverId,
  ) {
    return _rides
        .doc(rideId)
        .collection(FirestorePaths.driverOffers)
        .doc(driverId);
  }

  /// Live updates for this driver's offer on a ride.
  Stream<DriverOfferModel?> watchDriverOffer({
    required String rideId,
    required String driverId,
  }) {
    return _driverOfferRef(rideId, driverId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DriverOfferModel.fromDoc(doc);
    });
  }

  Future<DriverOfferModel?> fetchDriverOffer({
    required String rideId,
    required String driverId,
  }) async {
    final doc = await _driverOfferRef(rideId, driverId).get();
    if (!doc.exists) return null;
    return DriverOfferModel.fromDoc(doc);
  }

  /// Finds rides where this driver has a waiting offer (`driver_accepted`).
  Future<List<({String rideId, DriverOfferModel offer})>>
      fetchWaitingDriverOffers(String driverId) async {
    final pendingSnap = await _rides
        .where(
          RideFields.status,
          whereIn: [RideStatus.pending, RideStatus.expired],
        )
        .limit(20)
        .get();

    final waiting = <({String rideId, DriverOfferModel offer})>[];

    for (final rideDoc in pendingSnap.docs) {
      final offerDoc = await _driverOfferRef(rideDoc.id, driverId).get();
      if (!offerDoc.exists) continue;
      final offer = DriverOfferModel.fromDoc(offerDoc);
      if (offer.isWaiting) {
        waiting.add((rideId: rideDoc.id, offer: offer));
      }
    }

    return waiting;
  }

  /// Clears the driver's active-ride pointer after complete/cancel.
  Future<void> clearCurrentRideId(String driverId) async {
    await _drivers.doc(driverId).set(
      {
        DriverFields.currentRideId: FieldValue.delete(),
        DriverFields.updatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Completed / cancelled rides claimed by [driverId], plus pending rides
  /// this driver declined (`cancelledByDriverId`).
  ///
  /// Filters status in memory so only single-field indexes are required
  /// (no composite index for status + orderBy).
  Stream<List<RideModel>> driverRideHistory(String driverId) {
    final assigned = _rides
        .where(RideFields.driverId, isEqualTo: driverId)
        .snapshots();
    final declined = _rides
        .where(RideFields.cancelledByDriverId, isEqualTo: driverId)
        .snapshots();

    return _mergeRideHistorySnapshots(assigned, declined);
  }

  Stream<List<RideModel>> _mergeRideHistorySnapshots(
    Stream<QuerySnapshot<Map<String, dynamic>>> assigned,
    Stream<QuerySnapshot<Map<String, dynamic>>> declined,
  ) {
    late StreamController<List<RideModel>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? assignedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? declinedSub;
    QuerySnapshot<Map<String, dynamic>>? assignedSnap;
    QuerySnapshot<Map<String, dynamic>>? declinedSnap;

    void emit() {
      if (assignedSnap == null || declinedSnap == null) return;

      final byId = <String, RideModel>{};
      for (final doc in assignedSnap!.docs) {
        byId[doc.id] = RideModel.fromDoc(doc);
      }
      for (final doc in declinedSnap!.docs) {
        byId.putIfAbsent(doc.id, () => RideModel.fromDoc(doc));
      }

      final rides = byId.values
          .where((ride) {
            final status = RideStatus.normalize(ride.status);
            return status == RideStatus.completed ||
                status == RideStatus.cancelled;
          })
          .toList()
        ..sort((a, b) {
          DateTime sortKey(RideModel ride) =>
              ride.completedAt ??
              ride.updatedAt ??
              ride.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return sortKey(b).compareTo(sortKey(a));
        });

      if (!controller.isClosed) {
        controller.add(rides);
      }
    }

    controller = StreamController<List<RideModel>>(
      onListen: () {
        assignedSub = assigned.listen(
          (snap) {
            assignedSnap = snap;
            emit();
          },
          onError: controller.addError,
        );
        declinedSub = declined.listen(
          (snap) {
            declinedSnap = snap;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await assignedSub?.cancel();
        await declinedSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Live stream of all documents in the `reservations` collection.
  ///
  /// Sorts in memory by `createdAt` (fallback `pickupDate`) so no composite
  /// index is required.
  Stream<List<ReservationModel>> watchReservations() {
    return _reservations.snapshots().map((snapshot) {
      final reservations = snapshot.docs.map(ReservationModel.fromDoc).toList()
        ..sort((a, b) {
          DateTime sortKey(ReservationModel reservation) =>
              reservation.createdAt ??
              reservation.pickupDate ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return sortKey(b).compareTo(sortKey(a));
        });

      return reservations;
    });
  }

  /// Live updates for a single `reservations/{reservationId}` document.
  Stream<ReservationModel?> watchReservation(String reservationId) {
    return _reservations.doc(reservationId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ReservationModel.fromDoc(doc);
    });
  }

  /// Declines a pending reservation (`pending` → `cancelled`).
  ///
  /// Empty/missing status is treated as pending (matches model + rules).
  /// Already-cancelled is idempotent. Throws [StateError] otherwise.
  Future<void> declineReservation({required String reservationId}) async {
    final reservationRef = _reservations.doc(reservationId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(reservationRef);
      if (!snap.exists) {
        throw StateError('Reservation is no longer available.');
      }

      final data = snap.data() ?? const <String, dynamic>{};
      final status = _normalizedReservationStatus(
        data[ReservationFields.status],
      );

      if (ReservationStatus.isCancelled(status)) {
        return;
      }

      if (status != ReservationStatus.pending) {
        throw StateError('Reservation is no longer pending.');
      }

      transaction.update(reservationRef, {
        ReservationFields.status: ReservationStatus.cancelled,
        ReservationFields.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  /// Confirms a pending reservation (`pending` → `confirm`) and assigns
  /// the driver. Does not create a ride or set `currentRideId`.
  Future<void> confirmReservation({
    required String reservationId,
    required String driverId,
  }) async {
    final reservationRef = _reservations.doc(reservationId);
    final driverRef = _drivers.doc(driverId);

    final driverSnap = await driverRef.get();
    if (!driverSnap.exists) {
      throw StateError('Driver profile not found.');
    }

    final driverData = driverSnap.data() ?? const <String, dynamic>{};
    if (driverData[DriverFields.isApproved] != true) {
      throw StateError('Driver is not approved.');
    }

    final activeRideId =
        (driverData[DriverFields.currentRideId] as String?)?.trim() ?? '';
    if (activeRideId.isNotEmpty) {
      throw StateError(
        'Finish or cancel your current ride before accepting a reservation.',
      );
    }

    String driverText(String key) => (driverData[key] as String?) ?? '';
    final firstName = driverText(DriverFields.firstName);
    final lastName = driverText(DriverFields.lastName);
    final driverName = '$firstName $lastName'.trim();
    final makeModel =
        '${driverText(DriverFields.vehicleMake)} ${driverText(DriverFields.vehicleModel)}'
            .trim();
    final vehicleName = makeModel.isNotEmpty
        ? makeModel
        : driverText(DriverFields.vehicleType);

    await _db.runTransaction((transaction) async {
      final reservationSnap = await transaction.get(reservationRef);
      if (!reservationSnap.exists) {
        throw StateError('Reservation is no longer available.');
      }

      final data = reservationSnap.data() ?? const <String, dynamic>{};
      final status = _normalizedReservationStatus(
        data[ReservationFields.status],
      );
      if (status != ReservationStatus.pending) {
        throw StateError('Reservation is no longer pending.');
      }

      final existingDriverId =
          (data[ReservationFields.driverId] as String?)?.trim() ?? '';
      if (existingDriverId.isNotEmpty) {
        throw StateError('This reservation was already accepted.');
      }

      transaction.update(reservationRef, {
        ReservationFields.status: ReservationStatus.confirm,
        ReservationFields.driverId: driverId,
        ReservationFields.driverName: driverName,
        ReservationFields.driverPhone: driverText(DriverFields.phone),
        ReservationFields.vehicleName: vehicleName,
        ReservationFields.vehicleNumber:
            driverText(DriverFields.vehicleRegistration),
        ReservationFields.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  /// Starts a confirmed reservation: creates a linked `rides/{rideId}`
  /// (status `driver_arriving`), sets `reservations.status` to
  /// `driver_arriving`, links `rideId`, and sets `drivers.currentRideId`.
  ///
  /// Requires pickup/drop-off coordinates so ActiveRide can render the map.
  /// If [reservation.rideId] already exists, returns that active ride
  /// (idempotent recover) instead of creating a duplicate, and heals a
  /// legacy `confirm` status to match the live ride.
  Future<RideModel> startReservationRide({
    required String reservationId,
    required String driverId,
  }) async {
    final reservationRef = _reservations.doc(reservationId);
    final driverRef = _drivers.doc(driverId);
    final rideRef = _rides.doc();

    final driverSnap = await driverRef.get();
    if (!driverSnap.exists) {
      throw StateError('Driver profile not found.');
    }

    final driverData = driverSnap.data() ?? const <String, dynamic>{};
    if (driverData[DriverFields.isApproved] != true) {
      throw StateError('Driver is not approved.');
    }

    return _db.runTransaction<RideModel>((transaction) async {
      final reservationSnap = await transaction.get(reservationRef);
      final driverTxnSnap = await transaction.get(driverRef);

      if (!reservationSnap.exists) {
        throw StateError('Reservation is no longer available.');
      }

      final reservation = ReservationModel.fromDoc(reservationSnap);
      if (ReservationStatus.isCancelled(reservation.status) ||
          ReservationStatus.isCompleted(reservation.status)) {
        throw StateError('Reservation is no longer available.');
      }

      final assignedDriverId = reservation.driverId;
      if (assignedDriverId != null &&
          assignedDriverId.isNotEmpty &&
          assignedDriverId != driverId) {
        throw StateError('This reservation is assigned to another driver.');
      }

      final txnDriverData =
          driverTxnSnap.data() ?? const <String, dynamic>{};
      final txnActiveRideId =
          txnDriverData[DriverFields.currentRideId] as String?;

      final existingRideId = reservation.rideId;
      if (existingRideId != null && existingRideId.isNotEmpty) {
        if (!ReservationStatus.isConfirm(reservation.status) &&
            !ReservationStatus.isLiveActive(reservation.status)) {
          throw StateError('Reservation is not available to continue.');
        }
        final existingRideRef = _rides.doc(existingRideId);
        final existingRideSnap = await transaction.get(existingRideRef);
        if (!existingRideSnap.exists) {
          throw StateError('Linked ride is no longer available.');
        }

        final existingRide = RideModel.fromDoc(existingRideSnap);
        if (existingRide.driverId != null &&
            existingRide.driverId!.isNotEmpty &&
            existingRide.driverId != driverId) {
          throw StateError('This reservation is assigned to another driver.');
        }
        if (!existingRide.isActiveAssigned) {
          throw StateError('This reservation ride is no longer active.');
        }
        if (txnActiveRideId != null &&
            txnActiveRideId.isNotEmpty &&
            txnActiveRideId != existingRideId) {
          throw StateError(
            'Finish or cancel your current ride before starting another.',
          );
        }

        if (txnActiveRideId == null || txnActiveRideId.isEmpty) {
          transaction.set(
            driverRef,
            {
              DriverFields.currentRideId: existingRideId,
              DriverFields.updatedAt: FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        // Heal legacy confirm+rideId so reservation mirrors the live ride.
        final mirrorStatus =
            _reservationMirrorStatusForRide(existingRide.status);
        if (mirrorStatus != null &&
            reservation.status.toLowerCase() != mirrorStatus) {
          transaction.update(reservationRef, {
            ReservationFields.status: mirrorStatus,
            ReservationFields.updatedAt: FieldValue.serverTimestamp(),
          });
        }

        return existingRide;
      }

      if (!ReservationStatus.isConfirm(reservation.status)) {
        throw StateError('Reservation is not confirmed.');
      }

      if (!reservation.hasPickupAndDropoffCoords) {
        throw StateError(
          'Reservation is missing pickup or drop-off coordinates.',
        );
      }

      if (txnActiveRideId != null && txnActiveRideId.isNotEmpty) {
        throw StateError(
          'Finish or cancel your current ride before starting another.',
        );
      }

      final rideId = rideRef.id;
      final customerName = reservation.fullName.isEmpty
          ? 'Customer'
          : reservation.fullName;

      final rideData = <String, dynamic>{
        RideFields.rideId: rideId,
        RideFields.customerId: reservation.userId,
        RideFields.customerName: customerName,
        RideFields.estimatedFare: reservation.fare,
        RideFields.totalMiles: reservation.distanceMiles,
        RideFields.vehicleType: reservation.vehicleType,
        RideFields.pickupLocation: reservation.pickupAddress,
        RideFields.pickupAddress: reservation.pickupAddress,
        RideFields.pickupLatitude: reservation.pickupLatitude,
        RideFields.pickupLongitude: reservation.pickupLongitude,
        RideFields.dropoffLocation: reservation.dropOffAddress,
        RideFields.dropoffAddress: reservation.dropOffAddress,
        RideFields.dropoffLatitude: reservation.dropoffLatitude,
        RideFields.dropoffLongitude: reservation.dropoffLongitude,
        RideFields.status: RideStatus.driverArriving,
        RideFields.driverId: driverId,
        RideFields.reservationId: reservationId,
        RideFields.acceptedAt: FieldValue.serverTimestamp(),
        RideFields.arrivingAt: FieldValue.serverTimestamp(),
        RideFields.createdAt: FieldValue.serverTimestamp(),
        RideFields.updatedAt: FieldValue.serverTimestamp(),
        ...assignedDriverRideFields(
          driverData: driverData,
          pickupLatitude: reservation.pickupLatitude,
          pickupLongitude: reservation.pickupLongitude,
        ),
      };

      transaction.set(rideRef, rideData);
      // Keep reservation status in sync with the linked live ride.
      transaction.update(reservationRef, {
        ReservationFields.status: ReservationStatus.driverArriving,
        ReservationFields.driverId: driverId,
        ReservationFields.rideId: rideId,
        ReservationFields.updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        driverRef,
        {
          DriverFields.currentRideId: rideId,
          DriverFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return RideModel(
        id: rideId,
        rideId: rideId,
        customerId: reservation.userId,
        customerName: customerName,
        estimatedFare: reservation.fare,
        totalMiles: reservation.distanceMiles,
        vehicleType: reservation.vehicleType,
        pickupLocation: reservation.pickupAddress,
        pickupLatitude: reservation.pickupLatitude,
        pickupLongitude: reservation.pickupLongitude,
        dropoffLocation: reservation.dropOffAddress,
        dropoffLatitude: reservation.dropoffLatitude,
        dropoffLongitude: reservation.dropoffLongitude,
        status: RideStatus.driverArriving,
        driverId: driverId,
        reservationId: reservationId,
        acceptedAt: DateTime.now(),
        arrivingAt: DateTime.now(),
        createdAt: reservation.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });
  }

  /// Atomically claims a pending ride for [driverId] as `driver_arriving`.
  ///
  /// Prefers the Cloud Function, then falls back to a guarded client
  /// transaction on the ride + driver documents (no `driverOffers`).
  Future<void> acceptRide({
    required String rideId,
    required String driverId,
    double? offeredFare,
    double? driverLatitude,
    double? driverLongitude,
    String? driverAddress,
  }) async {
    try {
      final callable = _functions.httpsCallable('acceptRide');
      final payload = <String, dynamic>{'rideId': rideId};
      if (offeredFare != null) {
        payload['offeredFare'] = offeredFare;
      }
      if (driverLatitude != null) {
        payload['driverLatitude'] = driverLatitude;
      }
      if (driverLongitude != null) {
        payload['driverLongitude'] = driverLongitude;
      }
      final address = driverAddress?.trim() ?? '';
      if (address.isNotEmpty) {
        payload['driverAddress'] = address;
      }
      await callable.call(payload);
      return;
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'acceptRide callable failed: ${error.code} ${error.message}',
        );
      }

      final canFallback = error.code == 'not-found' ||
          error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'internal' ||
          error.code == 'unimplemented';

      if (!canFallback) {
        throw StateError(error.message ?? 'Could not accept ride.');
      }

      // After an unknown CF outcome, only claim if the ride is still open.
      final latest = await fetchRide(rideId);
      if (latest != null) {
        final status = latest.status.toLowerCase().trim();
        final assigned = latest.driverId?.trim() ?? '';
        if (assigned == driverId &&
            RideStatus.isActiveAssignedStatus(status)) {
          return;
        }
        if (assigned.isNotEmpty && assigned != driverId) {
          throw StateError('Another driver accepted this ride first.');
        }
        if (status != RideStatus.pending && status != RideStatus.expired) {
          throw StateError('Ride is no longer available.');
        }
      }

      if (kDebugMode) {
        debugPrint('acceptRide: falling back to client claim transaction');
      }
    }

    await _claimRideClient(
      rideId: rideId,
      driverId: driverId,
      driverLatitude: driverLatitude,
      driverLongitude: driverLongitude,
    );
  }

  /// Client fallback: claim pending/expired ride as `driver_arriving`.
  Future<void> _claimRideClient({
    required String rideId,
    required String driverId,
    double? driverLatitude,
    double? driverLongitude,
  }) async {
    final rideRef = _rides.doc(rideId);
    final driverRef = _drivers.doc(driverId);

    final driverSnap = await driverRef.get();
    if (!driverSnap.exists) {
      throw StateError('Driver profile not found.');
    }

    final driverData = driverSnap.data() ?? const <String, dynamic>{};
    if (driverData[DriverFields.isApproved] != true) {
      throw StateError('Driver is not approved.');
    }

    final activeRideId = driverData[DriverFields.currentRideId] as String?;
    if (activeRideId != null &&
        activeRideId.isNotEmpty &&
        activeRideId != rideId) {
      throw StateError(
        'Finish or cancel your current ride before accepting another.',
      );
    }

    await _db.runTransaction((transaction) async {
      final rideSnap = await transaction.get(rideRef);
      final driverTxnSnap = await transaction.get(driverRef);

      if (!rideSnap.exists) {
        throw StateError('Ride is no longer available.');
      }

      final data = rideSnap.data() ?? const <String, dynamic>{};
      final status = data[RideFields.status] as String?;
      final existingDriverId = data[RideFields.driverId] as String?;

      if (existingDriverId == driverId &&
          RideStatus.isActiveAssignedStatus(status ?? '')) {
        return;
      }

      if (existingDriverId != null &&
          existingDriverId.isNotEmpty &&
          existingDriverId != driverId) {
        throw StateError('Another driver accepted this ride first.');
      }

      if (RideStatus.isActiveAssignedStatus(status ?? '')) {
        throw StateError('Another driver accepted this ride first.');
      }

      if (status != RideStatus.pending && status != RideStatus.expired) {
        throw StateError('Ride is no longer available.');
      }

      final txnDriverData =
          driverTxnSnap.data() ?? const <String, dynamic>{};
      final txnActiveRideId =
          txnDriverData[DriverFields.currentRideId] as String?;
      if (txnActiveRideId != null &&
          txnActiveRideId.isNotEmpty &&
          txnActiveRideId != rideId) {
        throw StateError(
          'Finish or cancel your current ride before accepting another.',
        );
      }

      final rideUpdate = <String, dynamic>{
        RideFields.status: RideStatus.driverArriving,
        RideFields.driverId: driverId,
        RideFields.acceptedAt: FieldValue.serverTimestamp(),
        RideFields.arrivingAt: FieldValue.serverTimestamp(),
        RideFields.updatedAt: FieldValue.serverTimestamp(),
        ...assignedDriverRideFields(
          driverData: driverData,
          driverLatitude: driverLatitude,
          driverLongitude: driverLongitude,
          pickupLatitude: _optionalNumber(data, RideFields.pickupLatitude),
          pickupLongitude: _optionalNumber(data, RideFields.pickupLongitude),
        ),
      };

      // Location is outside the claim allowlist in rules; write after claim
      // via the assigned-driver GPS path when needed.
      transaction.update(rideRef, rideUpdate);
      transaction.set(
        driverRef,
        {
          DriverFields.currentRideId: rideId,
          DriverFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    if (driverLatitude != null && driverLongitude != null) {
      try {
        await updateDriverLocation(
          rideId: rideId,
          latitude: driverLatitude,
          longitude: driverLongitude,
        );
      } catch (error) {
        debugPrint('acceptRide: post-claim GPS write failed: $error');
      }
    }
  }

  /// Withdraws this driver's waiting offer without cancelling the ride.
  Future<void> withdrawDriverOffer({
    required String rideId,
    required String driverId,
  }) async {
    final offerRef = _driverOfferRef(rideId, driverId);

    await _db.runTransaction((transaction) async {
      final offerSnap = await transaction.get(offerRef);
      if (!offerSnap.exists) return;

      final status =
          offerSnap.data()?[DriverOfferFields.status] as String?;
      if (status != DriverOfferStatus.driverAccepted) return;

      transaction.update(offerRef, {
        DriverOfferFields.status: DriverOfferStatus.cancelled,
        DriverOfferFields.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  /// Cancels a pending `rides/{rideId}` via a client transaction.
  ///
  /// Empty/missing status is treated as pending. Already-cancelled is
  /// idempotent. Stamps [RideFields.cancelledByDriverId] for history.
  ///
  /// Throws [StateError] if the ride is missing or no longer claimable.
  Future<void> cancelRide({
    required String rideId,
    required String driverId,
  }) async {
    final rideRef = _rides.doc(rideId);

    await _db.runTransaction((transaction) async {
      final rideSnap = await transaction.get(rideRef);

      if (!rideSnap.exists) {
        throw StateError('Ride is no longer available.');
      }

      final data = rideSnap.data() ?? const <String, dynamic>{};
      final rawStatus = data[RideFields.status];
      final statusText = rawStatus is String ? rawStatus.trim() : '';
      final status = RideStatus.normalize(
        statusText.isEmpty ? RideStatus.pending : statusText,
      );

      if (status == RideStatus.cancelled) {
        return;
      }

      if (status != RideStatus.pending && status != RideStatus.expired) {
        throw StateError('Ride is no longer available.');
      }

      transaction.update(rideRef, {
        RideFields.status: RideStatus.cancelled,
        RideFields.cancelledAt: FieldValue.serverTimestamp(),
        RideFields.cancelledBy: 'driver',
        RideFields.cancelledByDriverId: driverId,
        RideFields.updatedAt: FieldValue.serverTimestamp(),
        RideFields.expiresAt: FieldValue.delete(),
      });
    });
  }

  /// Assigned driver cancels an accepted / in-progress ride (client path).
  ///
  /// Used when the `updateRideStatus` callable is unavailable (e.g. not
  /// deployed). Clears [DriverFields.currentRideId] after the ride update.
  /// When the ride has a [RideFields.reservationId], cancels that reservation
  /// in the same transaction (never overwrites completed).
  Future<void> cancelAssignedRide({
    required String rideId,
    required String driverId,
  }) async {
    final rideRef = _rides.doc(rideId);
    final driverRef = _drivers.doc(driverId);

    await _db.runTransaction((transaction) async {
      final rideSnap = await transaction.get(rideRef);

      if (!rideSnap.exists) {
        throw StateError('Ride is no longer available.');
      }

      final data = rideSnap.data() ?? const <String, dynamic>{};
      final status = data[RideFields.status] as String?;
      final assignedDriver = data[RideFields.driverId] as String?;
      final normalized = RideStatus.normalize(status ?? '');
      final reservationId = data[RideFields.reservationId] as String?;

      DocumentSnapshot<Map<String, dynamic>>? reservationSnap;
      DocumentReference<Map<String, dynamic>>? reservationRef;
      if (reservationId != null && reservationId.isNotEmpty) {
        reservationRef = _reservations.doc(reservationId);
        reservationSnap = await transaction.get(reservationRef);
      }

      if (normalized == RideStatus.cancelled) {
        _syncLinkedReservationInTxn(
          transaction,
          reservationRef: reservationRef,
          reservationSnap: reservationSnap,
          newStatus: ReservationStatus.cancelled,
        );
        return;
      }

      if (normalized == RideStatus.completed) {
        throw StateError('A completed ride cannot be cancelled.');
      }

      if (!RideStatus.isActiveAssignedStatus(normalized)) {
        throw StateError('This ride cannot be cancelled.');
      }

      if (assignedDriver != driverId) {
        throw StateError('You are not assigned to this ride.');
      }

      transaction.update(rideRef, {
        RideFields.status: RideStatus.cancelled,
        RideFields.cancelledAt: FieldValue.serverTimestamp(),
        RideFields.cancelledBy: 'driver',
        RideFields.updatedAt: FieldValue.serverTimestamp(),
      });

      _syncLinkedReservationInTxn(
        transaction,
        reservationRef: reservationRef,
        reservationSnap: reservationSnap,
        newStatus: ReservationStatus.cancelled,
      );
    });

    await driverRef.set(
      {
        DriverFields.currentRideId: FieldValue.delete(),
        DriverFields.updatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Persists the driver's latest GPS on the existing ride document.
  ///
  /// Uses [DocumentReference.update] only — never creates a new ride.
  /// Callers should throttle writes; this method does not throttle itself.
  Future<void> updateDriverLocation({
    required String rideId,
    required double latitude,
    required double longitude,
    double? heading,
  }) {
    final location = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (heading != null) {
      location['heading'] = heading;
    }

    return _rides.doc(rideId).update({
      RideFields.driverLocation: location,
      RideFields.driverLocationUpdatedAt: FieldValue.serverTimestamp(),
      RideFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  /// Advances [RideFields.currentStopIndex] on an assigned live ride.
  ///
  /// No-ops when the stored index is already >= [index]. Never writes on
  /// every GPS tick — callers must only invoke this on a real stop arrival.
  Future<void> updateCurrentStopIndex({
    required String rideId,
    required int index,
  }) async {
    if (rideId.trim().isEmpty || index < 0) return;

    final rideRef = _rides.doc(rideId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(rideRef);
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final status = data[RideFields.status];
      if (status is String && RideStatus.isTerminalStatus(status)) {
        return;
      }

      final raw = data[RideFields.currentStopIndex];
      final current = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : 0;
      if (index <= current) return;

      txn.update(rideRef, {
        RideFields.currentStopIndex: index,
        RideFields.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  double? _optionalNumber(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is num) return value.toDouble();
    return null;
  }

  /// Updates ride lifecycle via Cloud Functions.
  ///
  /// [action] is one of: `setArriving`, `arrivePickup`, `start`, `complete`,
  /// `cancel`.
  ///
  /// For driver status transitions, tries a guarded **client transaction first**
  /// (requires updated [firestore.rules]), then falls back to the callable.
  /// Cancel still prefers the callable, then client cancel.
  Future<void> updateRideLifecycle({
    required String rideId,
    required String action,
    String? driverId,
    String? cancellationReason,
  }) async {
    if (action != 'cancel') {
      try {
        await _clientLifecycleTransition(
          rideId: rideId,
          action: action,
          driverId: driverId,
        );
        return;
      } catch (error) {
        debugPrint(
          'client lifecycle failed ($action): $error — trying Cloud Function',
        );
      }
    }

    final callable = _functions.httpsCallable('updateRideStatus');

    try {
      final payload = <String, dynamic>{
        'rideId': rideId,
        'action': action,
      };
      if (cancellationReason != null && cancellationReason.isNotEmpty) {
        payload['cancellationReason'] = cancellationReason;
      }
      await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      debugPrint('updateRideStatus failed: ${error.code} ${error.message}');

      final canFallback = error.code == 'not-found' ||
          error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'internal' ||
          error.code == 'unimplemented' ||
          (action == 'cancel' && error.code == 'failed-precondition');

      if (!canFallback) rethrow;

      debugPrint(
        'updateRideStatus unavailable ($action); falling back to client txn',
      );

      if (action == 'cancel') {
        if (driverId == null || driverId.isEmpty) rethrow;
        await cancelAssignedRide(rideId: rideId, driverId: driverId);
        return;
      }

      await _clientLifecycleTransition(
        rideId: rideId,
        action: action,
        driverId: driverId,
      );
    }
  }

  /// Guarded client status transitions when Cloud Functions are unavailable.
  ///
  /// When the ride has a [RideFields.reservationId], the linked reservation
  /// status is updated in the same transaction so both documents stay in sync.
  /// Reservation does not mirror `passenger_arriving` (stays `driver_arrived`
  /// until the trip starts).
  Future<void> _clientLifecycleTransition({
    required String rideId,
    required String action,
    String? driverId,
  }) async {
    final rideRef = _rides.doc(rideId);

    await _db.runTransaction((transaction) async {
      final rideSnap = await transaction.get(rideRef);
      if (!rideSnap.exists) {
        throw StateError('Ride is no longer available.');
      }

      final data = rideSnap.data() ?? const <String, dynamic>{};
      final status = data[RideFields.status] as String?;
      final assignedDriver = data[RideFields.driverId] as String?;
      final reservationId = data[RideFields.reservationId] as String?;

      DocumentSnapshot<Map<String, dynamic>>? reservationSnap;
      DocumentReference<Map<String, dynamic>>? reservationRef;
      if (reservationId != null && reservationId.isNotEmpty) {
        reservationRef = _reservations.doc(reservationId);
        reservationSnap = await transaction.get(reservationRef);
      }

      if (driverId != null &&
          driverId.isNotEmpty &&
          assignedDriver != null &&
          assignedDriver != driverId) {
        throw StateError('You are not assigned to this ride.');
      }

      if (action == 'setArriving') {
        if (status == RideStatus.driverArriving ||
            status == RideStatus.driverArrived ||
            status == RideStatus.passengerArriving ||
            RideStatus.isTripInProgressStatus(status ?? '')) {
          return;
        }
        if (!RideStatus.isPreArrivingAssignedStatus(status ?? '')) {
          throw StateError('Invalid status for setArriving: $status');
        }
        transaction.update(rideRef, {
          RideFields.status: RideStatus.driverArriving,
          RideFields.arrivingAt: FieldValue.serverTimestamp(),
          RideFields.updatedAt: FieldValue.serverTimestamp(),
        });
        _syncLinkedReservationInTxn(
          transaction,
          reservationRef: reservationRef,
          reservationSnap: reservationSnap,
          newStatus: ReservationStatus.driverArriving,
        );
        return;
      }

      if (action == 'arrivePickup') {
        if (status == RideStatus.driverArrived ||
            status == RideStatus.passengerArriving ||
            RideStatus.isTripInProgressStatus(status ?? '')) {
          return;
        }
        if (status != RideStatus.driverArriving) {
          throw StateError('Invalid status for arrivePickup: $status');
        }
        transaction.update(rideRef, {
          RideFields.status: RideStatus.driverArrived,
          RideFields.driverArrivedAt: FieldValue.serverTimestamp(),
          RideFields.updatedAt: FieldValue.serverTimestamp(),
        });
        _syncLinkedReservationInTxn(
          transaction,
          reservationRef: reservationRef,
          reservationSnap: reservationSnap,
          newStatus: ReservationStatus.driverArrived,
        );
        return;
      }

      if (action == 'start') {
        if (RideStatus.isTripInProgressStatus(status ?? '')) return;
        if (status != RideStatus.passengerArriving) {
          throw StateError('Invalid status for start: $status');
        }
        transaction.update(rideRef, {
          RideFields.status: RideStatus.rideStarted,
          RideFields.startedAt: FieldValue.serverTimestamp(),
          RideFields.updatedAt: FieldValue.serverTimestamp(),
        });
        _syncLinkedReservationInTxn(
          transaction,
          reservationRef: reservationRef,
          reservationSnap: reservationSnap,
          newStatus: ReservationStatus.rideStarted,
        );
        return;
      }

      if (action == 'complete') {
        if (status == RideStatus.completed) return;
        if (!RideStatus.isTripInProgressStatus(status ?? '')) {
          throw StateError('Invalid status for complete: $status');
        }
        transaction.update(rideRef, {
          RideFields.status: RideStatus.completed,
          RideFields.completedAt: FieldValue.serverTimestamp(),
          RideFields.updatedAt: FieldValue.serverTimestamp(),
        });
        _syncLinkedReservationInTxn(
          transaction,
          reservationRef: reservationRef,
          reservationSnap: reservationSnap,
          newStatus: ReservationStatus.completed,
        );
        return;
      }

      throw StateError('Unsupported lifecycle action: $action');
    });

    if (action == 'complete' && driverId != null && driverId.isNotEmpty) {
      await clearCurrentRideId(driverId);
    }
  }

  /// Maps a live ride status onto the reservation mirror status.
  ///
  /// `passenger_arriving` maps to [ReservationStatus.driverArrived] because
  /// reservations do not use a passenger_arriving status.
  String? _reservationMirrorStatusForRide(String rideStatus) {
    final normalized = RideStatus.normalize(rideStatus);
    if (normalized == RideStatus.driverArriving) {
      return ReservationStatus.driverArriving;
    }
    if (normalized == RideStatus.driverArrived ||
        normalized == RideStatus.passengerArriving) {
      return ReservationStatus.driverArrived;
    }
    if (RideStatus.isTripInProgressStatus(normalized)) {
      return ReservationStatus.rideStarted;
    }
    if (normalized == RideStatus.completed) {
      return ReservationStatus.completed;
    }
    if (normalized == RideStatus.cancelled) {
      return ReservationStatus.cancelled;
    }
    return null;
  }

  /// Empty/missing reservation status is treated as pending (matches rules).
  String _normalizedReservationStatus(Object? raw) {
    if (raw is! String) return ReservationStatus.pending;
    final value = raw.trim().toLowerCase();
    return value.isEmpty ? ReservationStatus.pending : value;
  }

  /// Updates the linked reservation status inside an open transaction.
  ///
  /// Skips missing docs, already-matching status, and never overwrites
  /// [ReservationStatus.completed] with cancelled.
  void _syncLinkedReservationInTxn(
    Transaction transaction, {
    required DocumentReference<Map<String, dynamic>>? reservationRef,
    required DocumentSnapshot<Map<String, dynamic>>? reservationSnap,
    required String newStatus,
  }) {
    if (reservationRef == null || reservationSnap == null) return;
    if (!reservationSnap.exists) return;

    final data = reservationSnap.data() ?? const <String, dynamic>{};
    final current =
        ((data[ReservationFields.status] as String?) ?? '').toLowerCase();
    if (ReservationStatus.isCompleted(current) &&
        newStatus == ReservationStatus.cancelled) {
      return;
    }
    if (current == newStatus.toLowerCase()) return;

    transaction.update(reservationRef, {
      ReservationFields.status: newStatus,
      ReservationFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  /// Legacy direct status write — blocked by rules for drivers.
  /// Prefer [updateRideLifecycle].
  @Deprecated('Use updateRideLifecycle callable')
  Future<void> updateRideStatus({
    required String rideId,
    required String status,
  }) {
    final fields = <String, dynamic>{
      RideFields.status: status,
      RideFields.updatedAt: FieldValue.serverTimestamp(),
    };

    if (status == RideStatus.completed) {
      fields[RideFields.completedAt] = FieldValue.serverTimestamp();
    }

    return _rides.doc(rideId).update(fields);
  }
}
