import 'package:flutter/services.dart';

class SmsRoleManager {
  static const MethodChannel platform =
      MethodChannel('com.yourapp.fraud_detector/sms_role');

  static Future<bool> isDefaultSmsApp() async {
    try {
      final bool? result = await platform.invokeMethod<bool>('isDefaultSmsApp');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to check SMS role status: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> requestDefaultSmsApp() async {
    try {
      final bool? result =
          await platform.invokeMethod<bool>('requestDefaultSmsApp');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to request SMS role: '${e.message}'.");
      return false;
    }
  }
}
