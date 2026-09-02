class SmsDetectionResult {
  final String classification; // 'Safe', 'Spam', 'Fraud'
  final double threatLevel; // 0.0 to 1.0
  final List<String> matchedReasons;
  final String feedback;

  SmsDetectionResult({
    required this.classification,
    required this.threatLevel,
    required this.matchedReasons,
    required this.feedback,
  });
}

class SmsDetectionService {
  // Common phishing keywords
  static const List<String> _fraudKeywords = [
    'claim', 'won', 'voucher', 'winner', 'account suspended',
    'security alert', 'unauthorized login', 'verify details',
    'password reset link', 'bank detail', 'click here',
    'fnb', 'absa', 'capitec', 'standard bank', 'nedbank',
    'urgent action', 'lottery', 'bit.ly', 'tinyurl.com', 'shorturl',
    'package pending', 'delivery failed', 'post office', 'update address'
  ];

  // Common spam keywords
  static const List<String> _spamKeywords = [
    'promo', 'discount', 'special offer', 'buy now', 'cheap',
    'subscribe', 'opt out', 'stop to opt', 'reply stop', 'free trial',
    'loans', 'debt relief', 'insurance quote', 'casino', 'betting'
  ];

  static SmsDetectionResult analyze({required String message, required String sender}) {
    final cleanMsg = message.toLowerCase();
    final matchedReasons = <String>[];
    double score = 0.0;

    // Check sender format
    final isShortCode = sender.length <= 6 && !sender.contains('+');
    final isUnknownIntl = sender.startsWith('+') && !sender.startsWith('+27') && sender.length > 8; // e.g. out of South Africa

    if (isShortCode) {
      // Shortcodes are often marketing/spam, or high-volume SMS channels.
      // We don't mark as fraud automatically, but it raises suspicion.
      score += 0.1;
    }

    // Check Fraud Keywords
    for (final kw in _fraudKeywords) {
      if (cleanMsg.contains(kw)) {
        matchedReasons.add('Contains fraudulent/phishing trigger phrase: "$kw"');
        score += 0.35;
      }
    }

    // Check Spam Keywords
    for (final kw in _spamKeywords) {
      if (cleanMsg.contains(kw)) {
        matchedReasons.add('Contains advertising/spam trigger phrase: "$kw"');
        score += 0.20;
      }
    }

    // Check URL patterns
    final hasUrl = cleanMsg.contains('http://') || cleanMsg.contains('https://') || cleanMsg.contains('www.');
    if (hasUrl) {
      score += 0.25;
      matchedReasons.add('Message contains web links (often used to harvest credentials).');
      
      // Specifically check for unsafe links or link shorteners
      if (cleanMsg.contains('bit.ly') || cleanMsg.contains('tinyurl.com') || cleanMsg.contains('t.co') || cleanMsg.contains('.info') || cleanMsg.contains('.xyz')) {
        score += 0.25;
        matchedReasons.add('Uses known link shorteners or suspicious top-level domains.');
      }
    }

    // Check urgency triggers
    if (cleanMsg.contains('urgent') || cleanMsg.contains('immediate') || cleanMsg.contains('within 24 hours') || cleanMsg.contains('asap')) {
      score += 0.15;
      matchedReasons.add('Contains urgency triggers prompting immediate action.');
    }

    // Final categorization
    final double finalThreat = score.clamp(0.0, 1.0);
    String classification = 'Safe';
    String feedback = 'No malicious patterns detected. This message is likely safe.';

    if (finalThreat >= 0.70) {
      classification = 'Fraud';
      feedback = 'High Threat: Phishing attempt or brand impersonation detected. Do NOT click any links or share credentials.';
    } else if (finalThreat >= 0.35) {
      classification = 'Spam';
      feedback = 'Moderate Threat: Typical spam message or marketing communication. Avoid interacting if unrecognized.';
    }

    return SmsDetectionResult(
      classification: classification,
      threatLevel: finalThreat,
      matchedReasons: matchedReasons,
      feedback: feedback,
    );
  }
}
