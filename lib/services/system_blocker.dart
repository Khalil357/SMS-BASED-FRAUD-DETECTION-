import 'package:flutter/services.dart';
import 'sms_storage_service.dart';

class SystemBlocker {
  static const platform = MethodChannel('com.yourapp.fraud_detector/blocklist');
  static const _roleChannel = MethodChannel('com.yourapp.fraud_detector/sms_role');

  static Future<bool> isDefaultSmsApp() async {
    try {
      final bool result = await _roleChannel.invokeMethod<bool>('isDefaultSmsApp') ?? false;
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> requestDefaultSmsApp() async {
    try {
      await _roleChannel.invokeMethod('requestDefaultSmsApp');
    } on PlatformException catch (_) {}
  }

  static Future<bool> blockSystemNumber(String phoneNumber) async {
    try {
      await platform.invokeMethod('blockNumber', {'phoneNumber': phoneNumber});
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'DEFAULT_SMS_REQUIRED') {
        return false;
      }
      return false;
    }
  }

  static Future<bool> unblockSystemNumber(String phoneNumber) async {
    try {
      await platform.invokeMethod('unblockNumber', {'phoneNumber': phoneNumber});
      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> isSystemBlocked(String phoneNumber) async {
    try {
      final bool result = await platform.invokeMethod<bool>('isNumberBlocked', {'phoneNumber': phoneNumber}) ?? false;
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<List<String>> getSystemBlockedNumbers() async {
    try {
      final List<dynamic> result = await platform.invokeMethod<List>('getBlockedNumbers') ?? [];
      return result.map((e) => e.toString()).toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  static Future<void> syncBlocklistFromSystem() async {
    if (!await isDefaultSmsApp()) return;
    final systemNumbers = await getSystemBlockedNumbers();
    final localNumbers = await SmsStorageService.getBlockedNumbers();

    for (final number in systemNumbers) {
      if (!localNumbers.contains(number)) {
        await SmsStorageService.addBlockedNumber(number);
      }
    }

    for (final number in localNumbers) {
      if (!systemNumbers.contains(number)) {
        await blockSystemNumber(number);
      }
    }
  }
}