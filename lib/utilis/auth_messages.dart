/// User-facing copy for authentication validation and Firebase Auth errors.
/// Keep messages exact — never surface raw Firebase exception text.
class AuthMessages {
  AuthMessages._();

  // Shared
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String noInternet =
      'Check your internet connection and try again.';

  // Login
  static const String loginEmailRequired = 'Email is required.';
  static const String loginPasswordRequired = 'Password is required.';
  static const String loginWrongPassword =
      'Password is incorrect. Please try again.';
  static const String loginUserNotFound =
      'Unable to find user .. go to Signup';
  static const String loginFailed =
      'Unable to sign in. Please try again later.';

  // Sign up
  static const String signupNameRequired = 'Please enter your full name.';
  static const String signupNameTooLong =
      'Full name must be at most 20 characters.';
  static const String signupPhoneRequired = 'Please enter your phone number.';
  static const String signupPasswordRequired = 'Please create a password.';
  static const String signupWeakPassword =
      'Password must be at least 8 characters long.';
  static const String signupConfirmPasswordRequired =
      'Please enter your confirm password.';
  static const String signupPasswordsMismatch = 'Passwords do not match.';
  static const String signupEmailExists = 'This email is already registered.';
  static const String signupFailed =
      'Unable to create your account. Please try again.';
  static const String signupSuccess = 'Account created successfully. Welcome!';

  // Forgot password
  static const String forgotEmailRequired =
      'Please enter your registered email.';
  static const String forgotAccountNotFound =
      'No account found with this email.';
  static const String forgotResetFailed =
      'Unable to send the reset link. Please try again.';

  /// Maps a Firebase Auth error code to the copy for [flow].
  static String fromFirebase(String code, AuthFlow flow) {
    switch (code) {
      case 'invalid-email':
        return invalidEmail;
      case 'network-request-failed':
        return noInternet;
      case 'user-not-found':
        return flow == AuthFlow.forgotPassword
            ? forgotAccountNotFound
            : loginUserNotFound;
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return loginWrongPassword;
      case 'email-already-in-use':
        return signupEmailExists;
      case 'weak-password':
        return signupWeakPassword;
      default:
        return fallbackFor(flow);
    }
  }

  static String fallbackFor(AuthFlow flow) {
    switch (flow) {
      case AuthFlow.login:
        return loginFailed;
      case AuthFlow.signup:
        return signupFailed;
      case AuthFlow.forgotPassword:
        return forgotResetFailed;
      case AuthFlow.other:
        return loginFailed;
    }
  }
}

/// Which auth operation is in progress — used to map Firebase codes to copy.
enum AuthFlow { login, signup, forgotPassword, other }
