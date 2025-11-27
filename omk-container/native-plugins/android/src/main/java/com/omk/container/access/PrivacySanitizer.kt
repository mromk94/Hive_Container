package com.omk.container.access

/**
 * Very small PII sanitizer for native-side logging.
 *
 * Heavy-duty sanitization before cloud calls lives in the Dart layer; this
 * keeps native logs from accidentally storing obvious PII.
 */
object PrivacySanitizer {

    private val emailRegex = Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
    private val ccRegex = Regex("\\b(?:\\d[ -]*?){13,19}\\b")
    private val ssnRegex = Regex("\\b\\d{3}-\\d{2}-\\d{4}\\b")

    fun sanitizeForLogging(input: String): String {
        var out = input
        out = emailRegex.replace(out, "[email_redacted]")
        out = ssnRegex.replace(out, "[ssn_redacted]")
        out = ccRegex.replace(out, "[card_redacted]")
        return out
    }
}
