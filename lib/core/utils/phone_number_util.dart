/// Utility class for normalizing and validating phone numbers.
///
/// Follows E.164 standard formatting guidelines, with domestic India (+91)
/// default resolution for numbers without country codes.
class PhoneNumberUtil {
  PhoneNumberUtil._();

  /// Normalizes a phone number into standard international format (e.g. +919876543210).
  ///
  /// Returns `null` if the input is null, empty, or cannot be normalized into
  /// a valid phone number format.
  static String? normalize(String? rawNumber) {
    if (rawNumber == null) return null;

    final trimmed = rawNumber.trim();
    if (trimmed.isEmpty) return null;

    final bool hadLeadingPlus = trimmed.startsWith('+');

    // Remove all non-digit characters
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return null;

    String normalized;

    if (hadLeadingPlus) {
      // It had an explicit country code prefix with '+'
      normalized = '+$digitsOnly';
    } else if (digitsOnly.startsWith('00') && digitsOnly.length > 2) {
      // International call prefix 00 (e.g., 00919876543210 -> +919876543210)
      normalized = '+${digitsOnly.substring(2)}';
    } else if (digitsOnly.length == 10) {
      // 10-digit standard Indian mobile number without country code
      normalized = '+91$digitsOnly';
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
      // 11-digit Indian domestic trunk prefix 0 (e.g., 09876543210)
      normalized = '+91${digitsOnly.substring(1)}';
    } else if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      // 12-digit Indian number with country code without '+' (e.g., 919876543210)
      normalized = '+$digitsOnly';
    } else {
      // Other numbers without explicit country code or unrecognized length
      return null;
    }

    // E.164 validation: excluding '+', digits must be between 7 and 15
    final totalDigits = normalized.length - 1;
    if (totalDigits < 7 || totalDigits > 15) {
      return null;
    }

    return normalized;
  }

  /// Checks whether a raw phone number can be normalized into a valid number.
  static bool isValid(String? rawNumber) {
    return normalize(rawNumber) != null;
  }

  /// Formats a normalized or raw phone number for friendly UI display.
  /// (e.g., +91 98765 43210)
  static String formatForDisplay(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return '';
    final normalized = normalize(phoneNumber);
    if (normalized == null) return phoneNumber;

    if (normalized.startsWith('+91') && normalized.length == 13) {
      final code = normalized.substring(0, 3);
      final part1 = normalized.substring(3, 8);
      final part2 = normalized.substring(8);
      return '$code $part1 $part2';
    }

    return normalized;
  }
}
