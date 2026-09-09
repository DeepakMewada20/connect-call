import 'package:connect_call/core/utils/phone_number_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumberUtil.normalize Tests', () {
    test('normalizes numbers with spaces and +91 prefix', () {
      expect(PhoneNumberUtil.normalize('+91 98765 43210'), '+919876543210');
    });

    test('normalizes numbers with dashes and +91 prefix', () {
      expect(PhoneNumberUtil.normalize('+91-9876543210'), '+919876543210');
    });

    test('normalizes numbers with domestic 0 prefix (11 digits)', () {
      expect(PhoneNumberUtil.normalize('09876543210'), '+919876543210');
    });

    test('normalizes 10-digit Indian numbers without country code', () {
      expect(PhoneNumberUtil.normalize('9876543210'), '+919876543210');
    });

    test('normalizes 12-digit Indian numbers with 91 prefix and no plus', () {
      expect(PhoneNumberUtil.normalize('919876543210'), '+919876543210');
    });

    test('normalizes standard format +919876543210 unchanged', () {
      expect(PhoneNumberUtil.normalize('+919876543210'), '+919876543210');
    });

    test('normalizes numbers with parentheses and spaces', () {
      expect(PhoneNumberUtil.normalize('(91) 98765 43210'), '+919876543210');
    });

    test('normalizes numbers with 0091 international prefix', () {
      expect(PhoneNumberUtil.normalize('00919876543210'), '+919876543210');
    });

    test('normalizes US international numbers with +1 and punctuation', () {
      expect(PhoneNumberUtil.normalize('+1 (555) 019-2834'), '+15550192834');
    });

    test('normalizes UK international numbers with +44 and spaces', () {
      expect(PhoneNumberUtil.normalize('+44 7911 123456'), '+447911123456');
    });

    test('returns null for short/invalid numbers', () {
      expect(PhoneNumberUtil.normalize('12345'), isNull);
      expect(PhoneNumberUtil.normalize(''), isNull);
      expect(PhoneNumberUtil.normalize(null), isNull);
      expect(PhoneNumberUtil.normalize('   '), isNull);
      expect(PhoneNumberUtil.normalize('not-a-number'), isNull);
    });

    test('isValid correctly reflects normalize result', () {
      expect(PhoneNumberUtil.isValid('9876543210'), isTrue);
      expect(PhoneNumberUtil.isValid('+91 98765 43210'), isTrue);
      expect(PhoneNumberUtil.isValid('12345'), isFalse);
    });

    test('formatForDisplay formats numbers cleanly', () {
      expect(PhoneNumberUtil.formatForDisplay('+919876543210'), '+91 98765 43210');
      expect(PhoneNumberUtil.formatForDisplay('9876543210'), '+91 98765 43210');
      expect(PhoneNumberUtil.formatForDisplay(''), '');
    });
  });
}
