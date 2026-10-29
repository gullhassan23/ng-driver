/// Canonical payment methods and statuses shared across NG Town Ride.
///
/// The driver app is display-only for these values. Card charges, verified
/// amounts, and gateway transaction IDs are written by the trusted backend.
class PaymentMethod {
  PaymentMethod._();

  static const String cash = 'cash';
  static const String card = 'card';
  static const String authorizeNet = 'authorize_net';
  static const String authorizenet = 'authorizenet';
  static const String creditCard = 'credit_card';
}

class PaymentStatus {
  PaymentStatus._();

  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String authorized = 'authorized';
  static const String paid = 'paid';
  static const String completed = 'completed';
  static const String succeeded = 'succeeded';
  static const String failed = 'failed';
  static const String declined = 'declined';
  static const String error = 'error';
  static const String refunded = 'refunded';

  /// True when the payment has been verified as successful.
  static bool isPaid(String? status) {
    if (status == null) return false;
    final normalized = status.trim().toLowerCase();
    return normalized == paid ||
        normalized == completed ||
        normalized == succeeded;
  }

  /// True when the card payment has been initiated or authorized but not yet settled/paid.
  static bool isPending(String? status) {
    if (status == null || status.trim().isEmpty) return true;
    final normalized = status.trim().toLowerCase();
    return normalized == pending ||
        normalized == processing ||
        normalized == authorized;
  }

  /// True when the payment gateway reported a failure or decline.
  static bool isFailed(String? status) {
    if (status == null) return false;
    final normalized = status.trim().toLowerCase();
    return normalized == failed ||
        normalized == declined ||
        normalized == error;
  }

  static bool isRefunded(String? status) {
    if (status == null) return false;
    return status.trim().toLowerCase() == refunded;
  }
}

/// Driver-facing labels derived from Firestore payment fields.
class PaymentDisplay {
  PaymentDisplay._();

  static bool isCashMethod(String? method) {
    if (method == null) return true;
    final normalized = method.trim().toLowerCase();
    return normalized.isEmpty || normalized == PaymentMethod.cash;
  }

  static bool isCardMethod(String? method) {
    if (isCashMethod(method)) return false;
    final normalized = method!.trim().toLowerCase();
    return normalized == PaymentMethod.card ||
        normalized == PaymentMethod.authorizeNet ||
        normalized == PaymentMethod.authorizenet ||
        normalized == PaymentMethod.creditCard;
  }

  static String methodLabel(String? method) {
    if (isCashMethod(method)) return 'Cash';
    if (isCardMethod(method)) return 'Card';
    return method!.trim();
  }

  /// Cash stays collect-on-trip. Card uses backend-verified status only.
  static String statusLabel(String? method, String? status, {String? last4}) {
    if (isCashMethod(method)) return 'Collect cash';
    var label = 'Payment pending';
    if (PaymentStatus.isPaid(status)) {
      label = 'Paid';
    } else if (PaymentStatus.isFailed(status)) {
      label = 'Payment failed';
    } else if (PaymentStatus.isRefunded(status)) {
      label = 'Refunded';
    }
    final digits = last4?.trim() ?? '';
    if (digits.isNotEmpty) {
      return '$label · ••••$digits';
    }
    return label;
  }

  /// e.g. `$40 · Cash` or `$40 · Card · Pending`.
  static String fareWithMethod({
    required double fare,
    String? method,
    String? status,
  }) {
    final amount = fare > 0 ? '\$${fare.round()}' : '';
    if (isCashMethod(method)) {
      return amount.isEmpty ? 'Cash' : '$amount · Cash';
    }

    final methodPart = methodLabel(method);
    final statusPart = PaymentStatus.isPaid(status)
        ? 'Paid'
        : PaymentStatus.isFailed(status)
        ? 'Failed'
        : PaymentStatus.isRefunded(status)
        ? 'Refunded'
        : 'Pending';
    if (amount.isEmpty) return '$methodPart · $statusPart';
    return '$amount · $methodPart · $statusPart';
  }
}
