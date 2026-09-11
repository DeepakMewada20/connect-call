import 'package:flutter/widgets.dart';

/// StringUtils provides safe Unicode/UTF-16 operations across the app.
class StringUtils {
  /// Sanitizes any string to ensure it is valid, well-formed UTF-16 without unpaired surrogates.
  /// Any orphaned high (0xD800-0xDBFF) or low (0xDC00-0xDFFF) surrogates are safely replaced.
  static String sanitize(String? str, [String fallback = '']) {
    if (str == null) return fallback;
    final input = str;
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code >= 0xD800 && code <= 0xDBFF) {
        // High surrogate
        if (i + 1 < input.length) {
          final next = input.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            // Valid surrogate pair
            buffer.writeCharCode(code);
            buffer.writeCharCode(next);
            i++;
            continue;
          }
        }
        // Unpaired high surrogate -> replace
        buffer.writeCharCode(0xFFFD);
      } else if (code >= 0xDC00 && code <= 0xDFFF) {
        // Unpaired low surrogate -> replace
        buffer.writeCharCode(0xFFFD);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// Safely extracts the first display character (initial) from a string.
  /// Handles multi-byte Unicode, emojis, and surrogate pairs cleanly without slicing UTF-16 code units.
  static String safeInitial(String? name, [String fallback = 'U']) {
    if (name == null || name.trim().isEmpty) return fallback;
    final clean = sanitize(name.trim());
    if (clean.isEmpty) return fallback;
    final chars = clean.characters;
    if (chars.isEmpty) return fallback;
    return chars.first.toUpperCase();
  }
}
