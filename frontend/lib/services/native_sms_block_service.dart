import 'package:flutter/services.dart';

/// Talks to MainActivity.kt to perform real, OS-level SMS blocking via
/// Android's BlockedNumberContract. Only works once this app is set as
/// the device's default SMS app (Android requirement, not a bug).
class NativeSmsBlockService {
  static const _channel = MethodChannel('com.example.secure_signal/sms_block');

  static Future<bool> isDefaultSmsApp() async {
    try {
      return await _channel.invokeMethod<bool>('isDefaultSmsApp') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Shows the OS's own "set as default SMS app" prompt.
  /// Returns true if the role was granted.
  static Future<bool> requestDefaultSmsRole() async {
    try {
      return await _channel.invokeMethod<bool>('requestDefaultSmsRole') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns true if the OS-level block succeeded.
  /// Returns false (never throws) if the app isn't the default SMS app yet —
  /// callers should fall back to the existing in-app blocklist either way.
  static Future<bool> blockNumberOnDevice(String number) async {
    try {
      return await _channel.invokeMethod<bool>('blockNumber', {'number': number}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> unblockNumberOnDevice(String number) async {
    try {
      return await _channel.invokeMethod<bool>('unblockNumber', {'number': number}) ?? false;
    } on PlatformException {
      return false;
    }
  }
}
