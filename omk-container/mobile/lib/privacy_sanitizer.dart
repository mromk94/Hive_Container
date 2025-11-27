import 'dart:core';

/// Stronger PII sanitizer used before any cloud transmission.
class PrivacySanitizer {
  static final RegExp _email =
      RegExp(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}");

  // Very loose credit card detector (13–19 digits with optional spaces/dashes)
  static final RegExp _card =
      RegExp(r"\b(?:\d[ -]*?){13,19}\b");

  // US SSN pattern
  static final RegExp _ssn = RegExp(r"\b\d{3}-\d{2}-\d{4}\b");

  // Generic long digit sequences (phone, IDs, etc.)
  static final RegExp _longDigits = RegExp(r"\b\d{6,}\b");

  static String sanitize(String input) {
    var out = input;
    out = out.replaceAll(_email, '[email_redacted]');
    out = out.replaceAll(_ssn, '[ssn_redacted]');
    out = out.replaceAll(_card, '[card_redacted]');
    out = out.replaceAll(_longDigits, '[digits_redacted]');
    return out;
  }
}
