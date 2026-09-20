import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/driver_model.dart';
import '../routes/app_routes.dart';
import '../services/firestore_service.dart';
import '../services/map_warmup_service.dart';
import '../services/notification_service.dart';
import '../utilis/auth_messages.dart';
import '../utilis/firestore_paths.dart';
import '../widgets/app_snackbar_widget.dart';
import '../widgets/phone_text_field_widget.dart';
import 'location_permission_controller.dart';
import 'signup_controller.dart';

class AuthController extends GetxController {
  AuthController({
    FirebaseAuth? auth,
    FirestoreService? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirestoreService();

  final FirebaseAuth _auth;
  final FirestoreService _firestore;

  // ==========================================
  // SIGN IN FORM
  // ==========================================

  final signInEmail = TextEditingController();
  final signInPassword = TextEditingController();

  // ==========================================
  // SIGN UP FORM
  // ==========================================

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final signUpEmail = TextEditingController();
  final phone = TextEditingController();
  final signUpPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  /// Password entered on the Delete Account screen for re-auth.
  final deleteAccountPassword = TextEditingController();

  final isLoading = false.obs;
  final isDeletingAccount = false.obs;
  final obscurePassword = true.obs;
  final obscureSignUpPassword = true.obs;
  final obscureConfirmPassword = true.obs;
  final obscureDeletePassword = true.obs;
  final deleteAccountConfirmed = false.obs;

  /// True only after a Firestore read that returned `isApproved == true`.
  /// Used by route middleware (GetX redirect is synchronous).
  final hasConfirmedApproval = false.obs;

  /// When true, foreground FCM snackbars are suppressed (Settings toggle).
  final notificationsPaused = false.obs;

  bool _isColdStartRunning = false;
  bool _coldStartScheduledFromRestore = false;

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  /// Waits until Firebase Auth has restored a persisted session, or confirmed
  /// there isn't one. [currentUser] is often already set after initializeApp.
  Future<void> awaitAuthReady() async {
    if (_auth.currentUser != null) return;

    try {
      await _auth.authStateChanges().first.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Fall through with whatever [currentUser] is after timeout.
    }
  }

  String? get uid => _auth.currentUser?.uid;

  @override
  void onReady() {
    super.onReady();
    // Cold start is owned by SessionRestoreView to avoid a dual entry race.
    // Fallback only if the restore gate never scheduled bootstrap (tests / deep links).
    if (!_coldStartScheduledFromRestore) {
      bootstrapColdStart();
    }
  }

  /// Marks that [SessionRestoreView] will call [bootstrapColdStart].
  void markColdStartFromSessionRestore() {
    _coldStartScheduledFromRestore = true;
  }

  /// Restores session on cold start from the session-restore gate, then
  /// replaces it with dashboard, active ride, waiting, or Sign In.
  Future<void> bootstrapColdStart() async {
    if (_isColdStartRunning) return;
    _isColdStartRunning = true;

    try {
      await awaitAuthReady();
      final route =
          isSignedIn ? await resolveStartRoute() : AppRoutes.signIn;
      await navigatePostAuth(route);
    } finally {
      _isColdStartRunning = false;
    }
  }

  /// Drops the restore gate without animating through Sign In.
  /// Approved destinations are gated behind location permission first.
  Future<void> navigatePostAuth(String route) async {
    if (route == AppRoutes.dashboard || route == AppRoutes.activeRide) {
      if (Get.isRegistered<LocationPermissionController>()) {
        final location = Get.find<LocationPermissionController>();
        await location.ensureStatus();
        if (!location.isGranted) {
          await Get.offAllNamed(
            AppRoutes.locationPermission,
            arguments: route,
            predicate: (_) => false,
          );
          return;
        }
      }

      // Warm icons + GPS before dashboard / active-ride map mounts
      // (critical when session restore skips the dashboard).
      if (Get.isRegistered<MapWarmupService>()) {
        Get.find<MapWarmupService>().warmInBackground(requestPermission: false);
      }
    }

    if (Get.currentRoute == route) return;

    if (route == AppRoutes.activeRide) {
      final id = uid;
      final driver =
          id == null ? null : await _firestore.fetchDriver(id);
      final rideId = driver?.currentRideId?.trim();
      await Get.offAllNamed(
        route,
        arguments: (rideId != null && rideId.isNotEmpty)
            ? {'rideId': rideId}
            : null,
        predicate: (_) => false,
      );
      return;
    }

    await Get.offAllNamed(
      route,
      predicate: (_) => false,
    );
  }

  @override
  void onClose() {
    signInEmail.dispose();
    signInPassword.dispose();
    firstName.dispose();
    lastName.dispose();
    signUpEmail.dispose();
    phone.dispose();
    signUpPassword.dispose();
    confirmPassword.dispose();
    deleteAccountPassword.dispose();
    super.onClose();
  }

  // ==========================================
  // SIGN IN
  // ==========================================

  Future<void> signIn() async {
    final email = signInEmail.text.trim();
    final password = signInPassword.text;

    if (email.isEmpty) {
      _showError(AuthMessages.loginEmailRequired, title: 'Sign in failed');
      return;
    }

    if (!GetUtils.isEmail(email)) {
      _showError(AuthMessages.invalidEmail, title: 'Sign in failed');
      return;
    }

    if (password.isEmpty) {
      _showError(AuthMessages.loginPasswordRequired, title: 'Sign in failed');
      return;
    }

    isLoading.value = true;

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _routeAfterSignIn();
    } on FirebaseAuthException catch (error) {
      _showError(
        AuthMessages.fromFirebase(error.code, AuthFlow.login),
        title: 'Sign in failed',
      );
    } on FirebaseException catch (error) {
      _showError(
        _authFirestoreMessage(error, AuthFlow.login),
        title: 'Sign in failed',
      );
    } catch (_) {
      _showError(AuthMessages.loginFailed, title: 'Sign in failed');
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // SIGN UP
  // ==========================================

  Future<void> signUp() async {
    final first = firstName.text.trim();
    final last = lastName.text.trim();
    final email = signUpEmail.text.trim();
    final password = signUpPassword.text;
    final confirm = confirmPassword.text;

    if (first.isEmpty || last.isEmpty) {
      _showError(AuthMessages.signupNameRequired, title: 'Sign up failed');
      return;
    }

    if (first.length > 20 || last.length > 20) {
      _showError(AuthMessages.signupNameTooLong, title: 'Sign up failed');
      return;
    }

    if (email.isEmpty || !GetUtils.isEmail(email)) {
      _showError(AuthMessages.invalidEmail, title: 'Sign up failed');
      return;
    }

    final phoneDigits = UsPhoneNumberFormatter.digitsOf(phone.text);
    if (phoneDigits.isEmpty) {
      _showError(AuthMessages.signupPhoneRequired, title: 'Sign up failed');
      return;
    }

    if (password.isEmpty) {
      _showError(AuthMessages.signupPasswordRequired, title: 'Sign up failed');
      return;
    }

    if (password.length < 8) {
      _showError(AuthMessages.signupWeakPassword, title: 'Sign up failed');
      return;
    }

    if (confirm.isEmpty) {
      _showError(
        AuthMessages.signupConfirmPasswordRequired,
        title: 'Sign up failed',
      );
      return;
    }

    if (password != confirm) {
      _showError(AuthMessages.signupPasswordsMismatch, title: 'Sign up failed');
      return;
    }

    isLoading.value = true;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      final uid = user?.uid;

      if (user == null || uid == null) {
        _showError(AuthMessages.signupFailed, title: 'Sign up failed');
        return;
      }

      // Ensure Firestore receives a fresh ID token (avoids permission-denied
      // right after createUserWithEmailAndPassword).
      await user.getIdToken(true);

      try {
        await _firestore.updateDriverFields(uid, {
          DriverFields.uid: uid,
          DriverFields.firstName: first,
          DriverFields.lastName: last,
          DriverFields.email: email,
          DriverFields.phone: phoneDigits,
          DriverFields.profileComplete: false,
          DriverFields.isOnline: false,
          DriverFields.isApproved: false,
          DriverFields.createdAt: FieldValue.serverTimestamp(),
        });
      } catch (firestoreError) {
        // Auth user exists but profile write failed — remove orphan account
        // so the user can retry signup with the same email.
        await _deleteOrphanAuthUser();
        rethrow;
      }

      rememberApproval(false);
      AppSnackbar.success(
        title: 'Sign up',
        message: AuthMessages.signupSuccess,
      );
      Get.offAllNamed(AppRoutes.signUpDetail);
    } on FirebaseAuthException catch (error) {
      _showError(
        AuthMessages.fromFirebase(error.code, AuthFlow.signup),
        title: 'Sign up failed',
      );
    } on FirebaseException catch (error) {
      _showError(
        _authFirestoreMessage(error, AuthFlow.signup),
        title: 'Sign up failed',
      );
    } catch (_) {
      _showError(AuthMessages.signupFailed, title: 'Sign up failed');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _deleteOrphanAuthUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // Best-effort cleanup; user may need password reset if email is stuck.
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  // ==========================================
  // PASSWORD RESET
  // ==========================================

  Future<bool> sendPasswordReset() async {
    if (isLoading.value) return false;

    final email = signInEmail.text.trim();

    if (email.isEmpty) {
      _showError(AuthMessages.forgotEmailRequired, title: 'Password reset');
      return false;
    }

    if (!GetUtils.isEmail(email)) {
      _showError(AuthMessages.invalidEmail, title: 'Password reset');
      return false;
    }

    isLoading.value = true;
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (error) {
      _showError(
        AuthMessages.fromFirebase(error.code, AuthFlow.forgotPassword),
        title: 'Password reset',
      );
      return false;
    } catch (_) {
      _showError(AuthMessages.forgotResetFailed, title: 'Password reset');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // SIGN OUT
  // ==========================================

  void clearAuthForms() {
    signInEmail.clear();
    signInPassword.clear();
    firstName.clear();
    lastName.clear();
    signUpEmail.clear();
    phone.clear();
    signUpPassword.clear();
    confirmPassword.clear();
    clearDeleteAccountForm();
    obscurePassword.value = true;
    obscureSignUpPassword.value = true;
    obscureConfirmPassword.value = true;
    isLoading.value = false;
  }

  void clearDeleteAccountForm() {
    deleteAccountPassword.clear();
    obscureDeletePassword.value = true;
    deleteAccountConfirmed.value = false;
  }

  Future<void> signOut({bool navigate = true}) async {
    final id = uid;

    if (id != null) {
      try {
        await _firestore.setOnlineStatus(id, false);
      } catch (_) {
        // Presence is best effort; always complete sign-out.
      }
    }

    rememberApproval(false);
    notificationsPaused.value = false;
    await NotificationService.resetListeners();
    await _auth.signOut();
    clearAuthForms();

    if (Get.isRegistered<SignupController>()) {
      Get.find<SignupController>().clearForm();
    }

    if (navigate) {
      Get.offAllNamed(AppRoutes.signIn);
    }
  }

  // ==========================================
  // DELETE ACCOUNT
  // ==========================================

  Future<bool> deleteAccount({String? password}) async {
    if (isDeletingAccount.value) return false;

    final user = _auth.currentUser;
    final email = user?.email?.trim();
    final id = user?.uid;
    final resolvedPassword =
        (password ?? deleteAccountPassword.text).trim();

    if (user == null || email == null || email.isEmpty || id == null) {
      _showError('You are not signed in.', title: 'Delete failed');
      return false;
    }

    if (resolvedPassword.isEmpty) {
      _showError(
        'Enter your password to confirm.',
        title: 'Delete failed',
      );
      return false;
    }

    if (!deleteAccountConfirmed.value) {
      _showError(
        'Please confirm that you understand this cannot be undone.',
        title: 'Delete failed',
      );
      return false;
    }

    isDeletingAccount.value = true;

    try {
      // Server-truth active-ride guard (DashboardController may be disposed).
      final driver = await _firestore.fetchDriver(id);
      final activeRideId = driver?.currentRideId?.trim();
      if (activeRideId != null && activeRideId.isNotEmpty) {
        _showError(
          'Finish or cancel your active ride before deleting your account.',
          title: 'Cannot delete account',
        );
        return false;
      }

      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: email,
          password: resolvedPassword,
        ),
      );

      // Soft pre-clean while still authenticated (best effort).
      if (driver != null) {
        try {
          await _firestore.deactivateDriverAccount(id);
        } catch (_) {}
      }

      // Hard-delete driver-owned docs. Failures must block Auth deletion
      // except when docs are already missing (handled in the service).
      await _firestore.deleteDriverOwnedData(id);

      rememberApproval(false);
      await user.delete();

      clearAuthForms();

      if (Get.isRegistered<SignupController>()) {
        Get.find<SignupController>().clearForm();
      }

      await Get.offAllNamed(AppRoutes.signIn);

      AppSnackbar.success(
        title: 'Account deleted',
        message: 'Your driver account has been permanently removed.',
      );
      return true;
    } on FirebaseAuthException catch (error) {
      _showError(
        AuthMessages.fromFirebase(error.code, AuthFlow.other),
        title: 'Delete failed',
      );
      return false;
    } on FirebaseException catch (error) {
      _showError(_firestoreMessageFor(error), title: 'Delete failed');
      return false;
    } catch (_) {
      _showError(
        'Could not delete your account. Please try again.',
        title: 'Delete failed',
      );
      return false;
    } finally {
      // Only reset if Auth user still exists (deletion failed / still on screen).
      if (_auth.currentUser != null) {
        isDeletingAccount.value = false;
      }
    }
  }

  // ==========================================
  // ROUTING
  // ==========================================

  void rememberApproval(bool approved) {
    hasConfirmedApproval.value = approved;
  }

  /// Sends a signed-in driver to details, waiting, location, or dashboard.
  Future<void> _routeAfterSignIn() async {
    final route = await resolvePostAuthRoute();
    await navigatePostAuth(route);
  }

  /// Skips Sign In for a returning driver on cold start.
  /// Incomplete / missing profiles are treated as logged out on cold start.
  Future<String> resolveStartRoute() async {
    final route = await resolvePostAuthRoute(signInOnError: true);

    if (route == AppRoutes.signUpDetail) {
      await signOut(navigate: false);
      return AppRoutes.signIn;
    }

    return route;
  }

  /// Firestore-backed destination after login, signup, cold start, or approval.
  /// Incomplete profiles go to details before the waiting-for-approval screen.
  Future<String> resolvePostAuthRoute({bool signInOnError = false}) async {
    final id = uid;

    if (id == null) {
      rememberApproval(false);
      return AppRoutes.signIn;
    }

    try {
      const timeout = Duration(seconds: 5);

      final driverFuture = _firestore.fetchDriver(id).timeout(timeout);
      final infoFuture =
          _firestore.fetchDriverInformation(id).timeout(timeout);

      final driver = await driverFuture;
      final info = await infoFuture;

      if (driver == null) {
        rememberApproval(false);
        return AppRoutes.signUpDetail;
      }

      final needsDetails = info == null ||
          info.vehicleRegistration.isEmpty ||
          info.vehicleType.isEmpty;

      if (needsDetails) {
        rememberApproval(false);
        return AppRoutes.signUpDetail;
      }

      if (!driver.isApproved) {
        rememberApproval(false);
        return AppRoutes.waitingApproval;
      }

      rememberApproval(true);

      final activeRideId = driver.currentRideId;
      if (activeRideId != null && activeRideId.isNotEmpty) {
        try {
          final activeRide =
              await _firestore.fetchRide(activeRideId).timeout(timeout);

          if (activeRide != null && activeRide.isActiveAssigned) {
            return AppRoutes.activeRide;
          }

          // Confirmed missing/terminal — clear stale pointer.
          if (activeRide == null ||
              RideStatus.isTerminalStatus(activeRide.status)) {
            await _firestore.clearCurrentRideId(id);
          }
        } catch (_) {
          // Network/timeout: still open Active Ride with the known id so the
          // driver is not stranded on dashboard while owning a trip.
          return AppRoutes.activeRide;
        }
      }

      return AppRoutes.dashboard;
    } catch (_) {
      // Do not wipe approval on transient network errors during cold start.
      if (signInOnError) {
        rememberApproval(false);
        return AppRoutes.signIn;
      }

      rethrow;
    }
  }

  /// Basic profile captured at sign up, used to seed the details form.
  DriverModel draftProfile(String uid) {
    return DriverModel(
      uid: uid,
      firstName: firstName.text.trim(),
      lastName: lastName.text.trim(),
      email: signUpEmail.text.trim(),
      phone: UsPhoneNumberFormatter.digitsOf(phone.text),
    );
  }

  // ==========================================
  // FEEDBACK
  // ==========================================

  void _showError(String message, {required String title}) {
    AppSnackbar.error(
      title: title,
      message: message,
      duration: const Duration(seconds: 4),
    );
  }

  String _authFirestoreMessage(FirebaseException error, AuthFlow flow) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return AuthMessages.noInternet;
      default:
        return AuthMessages.fallbackFor(flow);
    }
  }

  String _firestoreMessageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to complete this action.';
      case 'unavailable':
        return AuthMessages.noInternet;
      case 'not-found':
        return 'Could not find the requested data.';
      case 'deadline-exceeded':
        return AuthMessages.noInternet;
      default:
        return AuthMessages.fallbackFor(AuthFlow.other);
    }
  }
}
