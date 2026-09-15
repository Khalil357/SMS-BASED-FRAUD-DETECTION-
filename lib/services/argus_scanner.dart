import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_detection_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';

enum ScanVerdict { scan, notScan }

class ArgusScanResult {
  final String id;
  final String sender;
  final String message;
  final String type; // 'Safe', 'Spam', 'Fraud'
  final double threatLevel;
  final List<String> matchedReasons;
  final String feedback;
  final ScanVerdict verdict; // scan or notScan
  final bool isTrainedModel;
  final DateTime scannedAt;
  final String source;

  ArgusScanResult({
    required this.id,
    required this.sender,
    required this.message,
    required this.type,
    required this.threatLevel,
    required this.matchedReasons,
    required this.feedback,
    required this.verdict,
    required this.isTrainedModel,
    required this.scannedAt,
    required this.source,
  });

  Map<String, dynamic> toLogEntry() {
    return {
      'id': id,
      'sender': sender,
      'message': message,
      'type': type,
      'threat': threatLevel,
      'matchedReasons': matchedReasons,
      'feedback': feedback,
      'hasFeedback': false,
      'userFeedback': null,
      'isScanned': true,
      'isTrainedModel': isTrainedModel,
      'scannedAt': scannedAt.toIso8601String(),
      'source': source,
    };
  }
}

class ArgusScanner {
  static final ArgusScanner _instance = ArgusScanner._internal();
  factory ArgusScanner() => _instance;
  ArgusScanner._internal();

  static const String _keyScanEnabled = 'argus_scan_enabled';
  static const String _keyAutoScanThreshold = 'argus_auto_scan_threshold';

  Future<bool> get isScanEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyScanEnabled) ?? true;
  }

  Future<double> get autoScanThreshold async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyAutoScanThreshold) ?? 0.50;
  }

  Future<ArgusScanResult> scanSms({
    required String sender,
    required String message,
    String source = 'AUTO_LISTENER',
  }) async {
    final scannedAt = DateTime.now();
    final id = 'scan_${scannedAt.millisecondsSinceEpoch}_${sender.hashCode}';

    if (!(await isScanEnabled)) {
      final localResult = SmsDetectionService.analyze(message: message, sender: sender);
      return _buildResult(
        id: id,
        sender: sender,
        message: message,
        localResult: localResult,
        isTrainedModel: false,
        scannedAt: scannedAt,
        source: source,
      );
    }

    SmsDetectionResult backendResult;
    bool usedModel = false;

    try {
      final backendResponse = await AuthService.submitScan(
        sender: sender,
        messageBody: message,
        source: source,
      );

      if (backendResponse['success'] == true &&
          backendResponse['data'] != null) {
        final data = backendResponse['data'] as Map<String, dynamic>;
        backendResult = SmsDetectionService.parseBackendResult(
          backendData: data,
          originalMessage: message,
          sender: sender,
        );
        usedModel = true;
      } else {
        throw Exception('Backend scan failed');
      }
    } catch (_) {
      final localResult = SmsDetectionService.analyze(message: message, sender: sender);
      return _buildResult(
        id: id,
        sender: sender,
        message: message,
        localResult: localResult,
        isTrainedModel: false,
        scannedAt: scannedAt,
        source: source,
      );
    }

    return _buildResult(
      id: id,
      sender: sender,
      message: message,
      localResult: backendResult,
      isTrainedModel: usedModel,
      scannedAt: scannedAt,
      source: source,
    );
  }

  ArgusScanResult _buildResult({
    required String id,
    required String sender,
    required String message,
    required SmsDetectionResult localResult,
    required bool isTrainedModel,
    required DateTime scannedAt,
    required String source,
  }) {
    final classification = localResult.classification;
    final threatLevel = localResult.threatLevel;
    final matchedReasons = List<String>.from(localResult.matchedReasons);
    final feedback = localResult.feedback;

    final verdict = (classification == 'Fraud' || classification == 'Spam')
        ? ScanVerdict.scan
        : ScanVerdict.notScan;

    return ArgusScanResult(
      id: id,
      sender: sender,
      message: message,
      type: classification,
      threatLevel: threatLevel,
      matchedReasons: matchedReasons,
      feedback: feedback,
      verdict: verdict,
      isTrainedModel: isTrainedModel,
      scannedAt: scannedAt,
      source: source,
    );
  }

  Future<void> takeAction(ArgusScanResult result) async {
    switch (result.verdict) {
      case ScanVerdict.scan:
        await _handleThreat(result);
        break;
      case ScanVerdict.notScan:
        await _handleSafe(result);
        break;
    }
  }

  Future<void> _handleThreat(ArgusScanResult result) async {
    final threatLevel = result.threatLevel;
    final isFraud = result.type == 'Fraud';

    await NotificationService.showThreatAlert(
      sender: result.sender,
      message: result.message,
      threatLevel: threatLevel,
    );

    if (isFraud) {
      final reasonsSummary = result.matchedReasons.join('; ');
      await NotificationService.showThreatNotification(
        title: '🛡️ Argus: Fraud SMS Blocked',
        body: 'From ${result.sender}: $reasonsSummary',
      );
    } else if (result.type == 'Spam') {
      final reasonsSummary = result.matchedReasons.join('; ');
      await NotificationService.showThreatNotification(
        title: '⚠️ Argus: Spam SMS Detected',
        body: 'From ${result.sender}: $reasonsSummary',
      );
    }
  }

  Future<void> _handleSafe(ArgusScanResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final notifyOnSafe = prefs.getBool('notify_on_safe') ?? false;
    if (!notifyOnSafe) return;

    await NotificationService.showThreatNotification(
      title: '✅ Argus: SMS Verified Safe',
      body: 'Message from ${result.sender} classified as safe by trained model.',
    );
  }
}
