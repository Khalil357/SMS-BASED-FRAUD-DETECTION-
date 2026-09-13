import 'package:flutter_test/flutter_test.dart';
import 'package:secure_signal/services/sms_detection_service.dart';

void main() {
  group('SmsDetectionService Rule Engine Tests', () {
    test('Should flag high-risk link and financial reward patterns as Fraud', () {
      final message = 'Congratulations! You won a Woolworths voucher. Click http://bit.ly/woolies to claim!';
      final result = SmsDetectionService.analyze(message: message, sender: '+27821110000');
      
      expect(result.classification, equals('Fraud'));
      expect(result.threatLevel, greaterThan(0.8));
      expect(result.matchedReasons.any((r) => r.contains('lottery/financial')), isTrue);
      expect(result.matchedReasons.any((r) => r.contains('external hyperlink')), isTrue);
    });

    test('Should flag bank credential update impersonations as Fraud', () {
      final message = 'URGENT: Please verify your bank account login at https://secure-bank.login';
      final result = SmsDetectionService.analyze(message: message, sender: 'BankSupport');

      expect(result.classification, equals('Fraud'));
      expect(result.threatLevel, greaterThan(0.9));
      expect(result.matchedReasons.any((r) => r.contains('update/verification')), isTrue);
      expect(result.matchedReasons.any((r) => r.contains('deceptive Sender ID')), isTrue);
    });

    test('Should flag marketing messages as Spam', () {
      final message = 'Get 50% off on your next purchase! Use code SALE50 at checkout.';
      final result = SmsDetectionService.analyze(message: message, sender: 'PromoShop');

      expect(result.classification, equals('Spam'));
      expect(result.threatLevel, isRangeNotifier(0.4, 0.8)); // standard spam threat is ~0.5-0.75
    });

    test('Should class ordinary friendly messages as Safe', () {
      final message = 'Hey, are we still meeting for lunch today?';
      final result = SmsDetectionService.analyze(message: message, sender: 'Mom');

      expect(result.classification, equals('Safe'));
      expect(result.threatLevel, lessThan(0.1));
    });
  });
}

// Helper matcher for range
Matcher isRangeNotifier(double min, double max) => 
    allOf(greaterThanOrEqualTo(min), lessThanOrEqualTo(max));
