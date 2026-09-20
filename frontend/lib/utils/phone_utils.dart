/// Normalizes Tanzanian phone numbers to a single comparable form (E.164),
/// so "0712345678", "712345678", "255712345678" and "+255712345678" are
/// all recognized as the same number when checking the blocklist.
class PhoneUtils {
  static String normalizeToE164(String raw) {
    var n = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (n.isEmpty) return n;

    if (n.startsWith('+255')) return n;
    if (n.startsWith('255') && n.length >= 12) return '+$n';
    if (n.startsWith('0') && n.length == 10) return '+255${n.substring(1)}';
    if (n.length == 9 && !n.startsWith('0')) return '+255$n'; // bare subscriber number
    return n; // unrecognized format (e.g. non-TZ number) — left unchanged
  }

  static bool sameNumber(String a, String b) =>
      normalizeToE164(a) == normalizeToE164(b);
}
