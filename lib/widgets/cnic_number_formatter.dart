import 'package:flutter/services.dart';

/// Formats CNIC / National ID input as `123-45-6789` while typing.
class CnicNumberFormatter extends TextInputFormatter {
  const CnicNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 9 ? digits.substring(0, 9) : digits;
    final formatted = format(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Formats up to 9 digits as `123-45-6789`.
  static String format(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 5) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Returns 9-digit CNIC digits, or empty if invalid.
  static String digitsOf(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 9 ? digits : '';
  }
}
