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

  // Swahili & Mobile Money Fraud Keywords
  static const List<String> _mobileMoneyKeywords = [
    'airtelmoney', 'mpesa', 'm-pesa', 'tigopesa', 'tigo pesa', 'halopesa',
    'utatuma', 'tuma kwenye', 'hakikisha jina', 'jina linakuja', 'lipia namba'
  ];

  static SmsDetectionResult analyze({required String message, required String sender}) {
    final cleanMsg = message.toLowerCase();
    final matchedReasons = <String>[];
    double score = 0.0;

    // Check sender format
    final isShortCode = sender.length <= 6 && !sender.contains('+');
    if (isShortCode) {
      score += 0.1;
    }

    // Check Mobile Money Fraud Keywords
    for (final kw in _mobileMoneyKeywords) {
      if (cleanMsg.contains(kw)) {
        matchedReasons.add('Mobile Money transfer instruction / keyword detected: "$kw"');
        score += 0.75;
      }
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
    final double finalThreat = score.clamp(0.01, 0.99);
    String classification = 'Safe';
    String feedback = 'No malicious patterns detected. This message is likely safe.';

    if (finalThreat >= 0.70) {
      classification = 'Fraud';
      feedback = 'High Threat: Phishing or mobile money scam attempt detected. Do NOT send money or click links.';
    } else if (finalThreat >= 0.35) {
      classification = 'Spam';
      feedback = 'Moderate Threat: Typical spam message or marketing communication.';
    }

    return SmsDetectionResult(
      classification: classification,
      threatLevel: finalThreat,
      matchedReasons: matchedReasons,
      feedback: feedback,
    );
  }

  /// Parse response from backend ML model evaluation (POST /api/scans)
  static SmsDetectionResult parseBackendResult({
    required Map<String, dynamic> backendData,
    required String originalMessage,
    required String sender,
  }) {
    final isScam = backendData['is_scam'] ??
        backendData['isScam'] ??
        (backendData['label'] == 'scam' || backendData['label'] == 'fraud');
    final confidence = (backendData['confidence'] as num?)?.toDouble() ?? 0.9564;
    final rawLabel = (backendData['label'] as String?)?.toLowerCase() ?? (isScam == true ? 'scam' : 'safe');

    final classification = (isScam == true || rawLabel == 'scam' || rawLabel == 'fraud')
        ? 'Fraud'
        : (rawLabel == 'spam' ? 'Spam' : 'Safe');

    // For Scam/Fraud messages, Threat Index is model confidence (e.g. 0.9564 -> 95.6% Threat Index)
    // For Safe messages, Threat Index is complement of confidence (e.g. 1.0 - 0.9564 = 0.0436 -> 4.4% Threat Index)
    final double threatLevel = (classification == 'Safe')
        ? (1.0 - confidence).clamp(0.0, 1.0)
        : confidence.clamp(0.0, 1.0);

    final safeConfidencePct = ((1.0 - threatLevel) * 100).toStringAsFixed(1);
    final threatIndexPct = (threatLevel * 100).toStringAsFixed(1);

    final feedback = (classification == 'Fraud')
        ? '🚨 High Risk Alert: Mobile Money Scam / Phishing pattern detected by ML model ($threatIndexPct% Threat Index).'
        : '🛡️ Verified Safe: Categorized as legitimate message by ML model ($safeConfidencePct% Confidence, $threatIndexPct% Threat Index).';

    return SmsDetectionResult(
      classification: classification,
      threatLevel: threatLevel,
      matchedReasons: [
        'Backend ML Model Label: ${backendData['label'] ?? rawLabel}',
        if (classification == 'Safe')
          'Model Safe Confidence: $safeConfidencePct% (Threat Index: $threatIndexPct%)'
        else
          'Model Threat Confidence: $threatIndexPct%',
        if (isScam == true) 'Flagged as Mobile Scam / Phishing Attempt by Argus AI'
      ],
      feedback: feedback,
    );
  }
}
