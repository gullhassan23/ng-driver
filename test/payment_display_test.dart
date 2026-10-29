import 'package:flutter_test/flutter_test.dart';
import 'package:ngtowncardriver/constants/payment_constants.dart';

void main() {
  group('PaymentStatus', () {
    test('treats paid aliases as verified success', () {
      expect(PaymentStatus.isPaid('paid'), isTrue);
      expect(PaymentStatus.isPaid('completed'), isTrue);
      expect(PaymentStatus.isPaid('succeeded'), isTrue);
      expect(PaymentStatus.isPaid('PAID'), isTrue);
    });

    test('does not treat pending or failed as paid', () {
      expect(PaymentStatus.isPaid(null), isFalse);
      expect(PaymentStatus.isPaid('pending'), isFalse);
      expect(PaymentStatus.isPaid('processing'), isFalse);
      expect(PaymentStatus.isPaid('failed'), isFalse);
      expect(PaymentStatus.isPaid('declined'), isFalse);
    });

    test('recognizes pending and failed gateway states', () {
      expect(PaymentStatus.isPending('pending'), isTrue);
      expect(PaymentStatus.isPending('processing'), isTrue);
      expect(PaymentStatus.isPending('authorized'), isTrue);
      expect(PaymentStatus.isFailed('failed'), isTrue);
      expect(PaymentStatus.isFailed('declined'), isTrue);
      expect(PaymentStatus.isFailed('error'), isTrue);
    });
  });

  group('PaymentDisplay', () {
    test('cash is collect-on-trip and never shown as paid from a status flag', () {
      expect(PaymentDisplay.isCashMethod(null), isTrue);
      expect(PaymentDisplay.isCashMethod('cash'), isTrue);
      expect(PaymentDisplay.methodLabel('cash'), 'Cash');
      expect(PaymentDisplay.statusLabel('cash', 'paid'), 'Collect cash');
      expect(
        PaymentDisplay.fareWithMethod(fare: 40, method: 'cash', status: 'paid'),
        r'$40 · Cash',
      );
    });

    test('card pending, paid, and failed stay distinct', () {
      expect(PaymentDisplay.isCardMethod('card'), isTrue);
      expect(PaymentDisplay.isCardMethod('authorize_net'), isTrue);
      expect(
        PaymentDisplay.statusLabel('card', 'pending'),
        'Payment pending',
      );
      expect(PaymentDisplay.statusLabel('card', 'paid'), 'Paid');
      expect(
        PaymentDisplay.statusLabel('card', 'failed'),
        'Payment failed',
      );
      expect(
        PaymentDisplay.statusLabel('card', 'paid', last4: '4242'),
        'Paid · ••••4242',
      );
      expect(
        PaymentDisplay.fareWithMethod(
          fare: 40,
          method: 'card',
          status: 'pending',
        ),
        r'$40 · Card · Pending',
      );
      expect(
        PaymentDisplay.fareWithMethod(
          fare: 40,
          method: 'card',
          status: 'paid',
        ),
        r'$40 · Card · Paid',
      );
      expect(
        PaymentDisplay.fareWithMethod(
          fare: 40,
          method: 'card',
          status: 'failed',
        ),
        r'$40 · Card · Failed',
      );
    });

    test('driver cannot infer paid from a missing card status', () {
      expect(PaymentStatus.isPaid(null), isFalse);
      expect(
        PaymentDisplay.statusLabel('card', null),
        'Payment pending',
      );
    });
  });
}
