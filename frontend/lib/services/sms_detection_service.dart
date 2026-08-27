class SmsAnalysisResult {
  final double threatLevel;
  final String classification; // 'Safe', 'Spam', 'Fraud'
  final String feedback;
  final List<String> matchedReasons;

  const SmsAnalysisResult({
    required this.threatLevel,
    required this.classification,
    required this.feedback,
    required this.matchedReasons,
  });

  Map<String, dynamic> toJson() => {
        'threatLevel': threatLevel,
        'classification': classification,
        'feedback': feedback,
        'matchedReasons': matchedReasons,
      };

  factory SmsAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SmsAnalysisResult(
      threatLevel: (json['threatLevel'] as num).toDouble(),
      classification: json['classification'] as String,
      feedback: json['feedback'] as String,
      matchedReasons: List<String>.from(json['matchedReasons'] ?? []),
    );
  }
}

class SmsDetectionService {
  /// Reusable rule-based SMS threat analysis engine
  static SmsAnalysisResult analyze({
    required String message,
    required String sender,
  }) {
    final lowerText = message.toLowerCase();
    final lowerSender = sender.toLowerCase();
    
    List<String> reasons = [];
    bool isFraud = false;
    bool isSpam = false;

    // 1. Check Sender ID reputation
    bool suspiciousSender = false;
    if (lowerSender.contains('alert') || 
        lowerSender.contains('verify') || 
        lowerSender.contains('secure') || 
        lowerSender.contains('bank') || 
        lowerSender.contains('support')) {
      suspiciousSender = true;
      reasons.add('Sender ID contains suspicious keywords ($sender)');
    }

    // 2. Check Phishing / Financial Reward Patterns
    bool hasFinancial = lowerText.contains('win') ||
        lowerText.contains('won') ||
        lowerText.contains('prize') ||
        lowerText.contains('voucher') ||
        lowerText.contains('gift card');
        
    bool hasLink = lowerText.contains('click') ||
        lowerText.contains('link') ||
        lowerText.contains('http') ||
        lowerText.contains('https');

    if (hasFinancial) {
      isFraud = true;
      reasons.add('Contains lottery/financial reward keywords (e.g. win, prize, voucher)');
    }
    if (hasLink) {
      isFraud = true;
      reasons.add('Contains external hyperlink or link call-to-action');
    }

    // 3. Check Bank Impersonation / Urgency / Credential Verification
    bool hasUrgency = lowerText.contains('urgent');
    bool hasVerification = lowerText.contains('verify') || lowerText.contains('update');
    bool hasBankOrLogin = lowerText.contains('account') ||
        lowerText.contains('unauthorized') ||
        lowerText.contains('bank') ||
        lowerText.contains('login');

    if (hasUrgency || hasVerification || hasBankOrLogin) {
      isFraud = true;
      if (hasUrgency) reasons.add('High urgency indicator ("urgent")');
      if (hasVerification) reasons.add('Account credential update/verification request');
      if (hasBankOrLogin) reasons.add('Financial institution or login page reference');
    }

    // 4. Check Unsolicited Promotional / Sales (only if not already fraud)
    bool hasPromo = lowerText.contains('promo') ||
        lowerText.contains('offer') ||
        lowerText.contains('subscribe') ||
        lowerText.contains('free') ||
        lowerText.contains('buy') ||
        lowerText.contains('sale');

    if (hasPromo) {
      if (!isFraud) {
        isSpam = true;
      }
      reasons.add('Unsolicited promotional keywords detected (e.g. offer, sale, promo, free)');
    }

    // 5. Calculate Threat Level & Feedback
    double calculatedThreat = 0.0;
    String feedback = '';

    if (isFraud) {
      calculatedThreat = 0.85 + (0.14 * (message.length % 10) / 10);
      feedback = 'This message contains high-risk external link, urgency triggers, or financial fraud patterns.';
    } else if (isSpam) {
      calculatedThreat = 0.50 + (0.25 * (message.length % 10) / 10);
      feedback = 'Unsolicited promotional content patterns detected.';
    } else {
      calculatedThreat = 0.01 + (0.09 * (message.length % 10) / 10);
      feedback = 'No suspicious characteristics detected. This message appears normal.';
      reasons.add('No suspicious patterns matched');
    }

    // Boost threat level if sender name is deceptive
    if (suspiciousSender && calculatedThreat < 0.95) {
      calculatedThreat = (calculatedThreat + 0.15).clamp(0.0, 0.99);
      if (isSpam || !isFraud) {
        isSpam = false;
        isFraud = true; // Upgrade to fraud if sender name is spoofed
      }
      reasons.add('Threat rating increased due to deceptive Sender ID');
    }

    final classification = isFraud ? 'Fraud' : (isSpam ? 'Spam' : 'Safe');

    return SmsAnalysisResult(
      threatLevel: calculatedThreat,
      classification: classification,
      feedback: feedback,
      matchedReasons: reasons,
    );
  }
}
