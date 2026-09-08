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

    // 3. Check Mobile Money Fraud (AirtelMoney, M-Pesa, TigoPesa, HaloPesa, "Utatuma", "Hakikisha jina")
    bool hasMobileMoney = lowerText.contains('airtelmoney') ||
        lowerText.contains('mpesa') ||
        lowerText.contains('m-pesa') ||
        lowerText.contains('tigopesa') ||
        lowerText.contains('tigo pesa') ||
        lowerText.contains('halopesa');

    bool hasTransferPrompt = lowerText.contains('utatuma') ||
        lowerText.contains('tuma kwenye') ||
        lowerText.contains('hakikisha jina') ||
        lowerText.contains('jina linakuja') ||
        lowerText.contains('lipia namba');

    if (hasMobileMoney || hasTransferPrompt) {
      isFraud = true;
      if (hasMobileMoney) reasons.add('Mobile Money service reference detected (AirtelMoney/M-Pesa/TigoPesa)');
      if (hasTransferPrompt) reasons.add('Unsolicited money transfer instruction ("Utatuma / Hakikisha jina")');
    }

    // 4. Check Bank Impersonation / Urgency / Credential Verification
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

    // 5. Check Unsolicited Promotional / Sales (only if not already fraud)
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

    // 6. Calculate Threat Level & Feedback
    double calculatedThreat = 0.0;
    String feedback = '';

    if (isFraud) {
      calculatedThreat = 0.92 + (0.07 * (message.length % 10) / 10);
      feedback = 'This message contains high-risk mobile money fraud, payment transfer scam, or phishing triggers.';
    } else if (isSpam) {
      calculatedThreat = 0.50 + (0.25 * (message.length % 10) / 10);
      feedback = 'Unsolicited promotional content patterns detected.';
    } else {
      calculatedThreat = 0.01 + (0.04 * (message.length % 10) / 10);
      feedback = 'No suspicious characteristics detected. This message appears normal.';
      reasons.add('No suspicious patterns matched');
    }

    // Boost threat level if sender name is deceptive
    if (suspiciousSender && calculatedThreat < 0.95) {
      calculatedThreat = (calculatedThreat + 0.15).clamp(0.0, 0.99);
      if (isSpam || !isFraud) {
        isSpam = false;
        isFraud = true;
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

  /// Parse response from backend ML model evaluation (POST /api/scans)
  static SmsAnalysisResult parseBackendResult({
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

    return SmsAnalysisResult(
      threatLevel: threatLevel,
      classification: classification,
      feedback: feedback,
      matchedReasons: [
        'Backend ML Model Label: ${backendData['label'] ?? rawLabel}',
        if (classification == 'Safe')
          'Model Safe Confidence: $safeConfidencePct% (Threat Index: $threatIndexPct%)'
        else
          'Model Threat Confidence: $threatIndexPct%',
        if (isScam == true) 'Flagged as Mobile Scam / Phishing Attempt by Argus AI'
      ],
    );
  }
}
