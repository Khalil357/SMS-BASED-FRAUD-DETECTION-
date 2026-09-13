import 'package:flutter/services.dart';

/// Android system blocklist integration. Calls can throw [PlatformException]
/// when the app has not been selected as the default SMS app.
class NativeSmsBlockService {
  static const _channel = MethodChannel('com.example.secure_signal/sms_block');

  static Future<bool> isDefaultSmsApp() async {
    return await _channel.invokeMethod<bool>('isDefaultSmsApp') ?? false;
  }

  /// Opens Android's default-SMS role dialog and resolves after the user has
  /// accepted or declined it.
  static Future<bool> requestDefaultSmsRole() async {
    return await _channel.invokeMethod<bool>('requestDefaultSmsRole') ?? false;
  }

  static Future<bool> blockNumberOnDevice(String number) async {
    return await _channel.invokeMethod<bool>('blockNumber', {'number': number}) ?? false;
  }

  static Future<bool> unblockNumberOnDevice(String number) async {
    return await _channel.invokeMethod<bool>('unblockNumber', {'number': number}) ?? false;
  }
}
