import 'package:shared_preferences/shared_preferences.dart';

class SafetyTip {
  final String id;
  final String title;
  final String category; // 'Banking', 'Delivery', 'Rewards', 'Impersonation', 'General'
  final String summary;
  final List<String> redFlags;
  final List<String> actionSteps;
  final String realExample;

  const SafetyTip({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.redFlags,
    required this.actionSteps,
    required this.realExample,
  });
}

class QuizQuestion {
  final String id;
  final String sender;
  final String message;
  final bool isScam;
  final String category;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.sender,
    required this.message,
    required this.isScam,
    required this.category,
    required this.explanation,
  });
}

class SafetyTipsService {
  static const String _keyBookmarks = 'bookmarked_safety_tips';
  static const String _keyHighQuizScore = 'high_quiz_score';

  static const List<SafetyTip> tips = [
    SafetyTip(
      id: 'tip_1',
      title: 'Never Share One-Time Passcodes (OTPs)',
      category: 'Banking',
      summary: 'Banks and legit financial services will NEVER ask you to disclose an SMS OTP code over text or phone.',
      redFlags: [
        'Urgent request claiming your bank account will be blocked within 1 hour.',
        'SMS containing a link like bit.ly/bank-verify-otp.',
        'Requests asking you to forward your code to a random phone number.',
      ],
      actionSteps: [
        'Immediately ignore and delete the message.',
        'Call your bank directly using the phone number on your bank card.',
        'Enable 2FA using authenticator apps instead of plain SMS where available.',
      ],
      realExample: '"ALERT: Your Standard Bank account has been restricted. Enter OTP 849302 at hxxps://secure-bank-login.com to unblock immediately."',
    ),
    SafetyTip(
      id: 'tip_2',
      title: 'Watch Out for Fake Delivery & Customs Charges',
      category: 'Delivery',
      summary: 'Scammers send fake package tracking notifications demanding small payments (\$1 to \$5) to steal credit card info.',
      redFlags: [
        'Text from an unknown international number claiming a package cannot be delivered.',
        'Shortened URL or domain mimicking DHL, FedEx, or Post Office.',
        'Demand for immediate fee payment via unverified online link.',
      ],
      actionSteps: [
        'Check your official courier app or tracking code on the official site.',
        'Do not click shortened or suspicious links in package SMS.',
        'Block the sender number.',
      ],
      realExample: '"DHL Express: Your parcel #ZA-9812 has a pending tariff fee of R29.99. Pay now at hxxp://dhl-parcel-fee.info to avoid return."',
    ),
    SafetyTip(
      id: 'tip_3',
      title: 'Beware of "Hi Mom / Hi Dad" Family Emergency Scams',
      category: 'Impersonation',
      summary: 'Fraudsters impersonate a family member claiming they broke their phone and need an urgent funds transfer.',
      redFlags: [
        'Unrecognized number claiming to be your child or parent.',
        'Urgent request for instant money transfer (EFT, eWallet, gift cards).',
        'Excuses for why they cannot make a voice call right now.',
      ],
      actionSteps: [
        'Call your relative on their original known phone number first.',
        'Ask a personal verification question only your real family member would know.',
        'Never send funds to unverified bank details.',
      ],
      realExample: '"Hi mom, I dropped my phone in water and this is my temp number. Can you please send R1500 for emergency bills? I will pay back tomorrow."',
    ),
    SafetyTip(
      id: 'tip_4',
      title: 'Unsolicited Prize & Lottery Reward Scams',
      category: 'Rewards',
      summary: 'Messages claiming you won a cash lottery or gift voucher from competitions you never entered are 100% fraudulent.',
      redFlags: [
        'Claims of winning large cash sums or luxury cars from unknown lotteries.',
        'Requirement to pay a "processing fee" or "tax release fee" upfront.',
        'Suspicious WhatsApp links or international call back numbers.',
      ],
      actionSteps: [
        'Remember: Real lotteries never demand money to claim a legitimate prize.',
        'Do not supply personal identity numbers, bank details, or copies of ID.',
      ],
      realExample: '"CONGRATS! Your phone number won R250,000 in the SA Mega Draw. Contact Mr. David on WhatsApp +234... to claim code WIN777."',
    ),
    SafetyTip(
      id: 'tip_5',
      title: 'Inspect Links Before Tapping (Domain Spoofing)',
      category: 'General',
      summary: 'Scammers register domain names that look almost identical to real websites (e.g., paypaI-verify.com instead of paypal.com).',
      redFlags: [
        'Subtle typos or extra dashes in the domain name.',
        'HTTP instead of secure HTTPS URL protocol.',
        'Generic greetings like "Dear Customer" instead of your actual name.',
      ],
      actionSteps: [
        'Hover over or closely inspect the domain suffix before tapping.',
        'Use the Argus Manual Scan tab to analyze suspicious text snippets before opening.',
      ],
      realExample: '"Security Alert: Unauthorized sign-in detected. Secure your account now at hxxp://amazon-security-update.net/login."',
    ),
  ];

  static const List<QuizQuestion> quizQuestions = [
    QuizQuestion(
      id: 'quiz_1',
      sender: 'ABSA-ALERT',
      message: 'ABSA: A transfer of R4,500 was initiated. If this was not you, log in immediately to stop transaction: hxxp://absa-sec-portal.co.za',
      isScam: true,
      category: 'Banking',
      explanation: 'SCAM! Banks do not send web links ending in unverified domains like .co.za-sec-portal to cancel transactions. This is a credential phishing site.',
    ),
    QuizQuestion(
      id: 'quiz_2',
      sender: 'Vodacom',
      message: 'Your monthly bill statement for account #98231 is now ready in your MyVodacom app. View details in app.',
      isScam: false,
      category: 'General',
      explanation: 'REAL! Legitimate notification directing you to use the official mobile app without demanding sensitive passwords or external links.',
    ),
    QuizQuestion(
      id: 'quiz_3',
      sender: '+2771239847',
      message: 'Hello, your parcel is waiting at distribution center. Please pay R18.50 re-delivery fee at hxxps://post-office-delivery.org',
      isScam: true,
      category: 'Delivery',
      explanation: 'SCAM! Real post offices do not charge small re-delivery fees via third-party web links over SMS.',
    ),
    QuizQuestion(
      id: 'quiz_4',
      sender: 'FNB-Notice',
      message: 'FNB: Your eWallet payment of R500 to 0821234567 is complete. Ref: W89123.',
      isScam: false,
      category: 'Banking',
      explanation: 'REAL! Standard informational transaction notification with reference code and no suspicious links.',
    ),
    QuizQuestion(
      id: 'quiz_5',
      sender: 'UN-Global',
      message: r'You have been selected for UN Poverty Relief Fund grant of $50,000 USD. Email your passport copy to un-grant@consultant.com',
      isScam: true,
      category: 'Rewards',
      explanation: 'SCAM! International agencies never distribute random grants via SMS or request sensitive identity copies via free email accounts.',
    ),
  ];

  /// Get Tip of the Day based on day of year
  static SafetyTip getTipOfTheDay() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final index = dayOfYear % tips.length;
    return tips[index];
  }

  /// Get bookmarked tip IDs
  static Future<List<String>> getBookmarkedTipIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyBookmarks) ?? [];
  }

  /// Toggle bookmark status
  static Future<bool> toggleBookmark(String tipId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_keyBookmarks) ?? [];
    bool isBookmarked = false;

    if (bookmarks.contains(tipId)) {
      bookmarks.remove(tipId);
      isBookmarked = false;
    } else {
      bookmarks.add(tipId);
      isBookmarked = true;
    }

    await prefs.setStringList(_keyBookmarks, bookmarks);
    return isBookmarked;
  }

  /// Get High Score for Spot-the-Scam Quiz
  static Future<int> getHighQuizScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyHighQuizScore) ?? 0;
  }

  /// Save new high score
  static Future<void> saveQuizScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt(_keyHighQuizScore) ?? 0;
    if (score > currentHigh) {
      await prefs.setInt(_keyHighQuizScore, score);
    }
  }
}
