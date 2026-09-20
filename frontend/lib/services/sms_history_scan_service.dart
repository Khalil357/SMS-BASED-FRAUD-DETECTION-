import 'dart:io';
import 'package:telephony/telephony.dart';
import 'sms_detection_service.dart';
import 'sms_storage_service.dart';

/// Outcome of a one-shot inbox sweep.
class HistoryScanSummary {
  final int totalInbox;
  final int newScanned;
  final int fraudCount;
  final int safeCount;
  final int skipped;
  final List<Map<String, dynamic>> logs;
  final String? error;

  const HistoryScanSummary({
    required this.totalInbox,
    required this.newScanned,
    required this.fraudCount,
    required this.safeCount,
    required this.skipped,
    this.logs = const [],
    this.error,
  });
}

class SmsHistoryScanService {
  /// Scans every message currently in the device SMS inbox, runs the on-device
  /// rule-based analysis engine over each one, and persists newly classified
  /// entries into the shared log store. Messages already present in the logs
  /// (matched by system SMS id, or sender+body) are skipped.
  ///
  /// [onProgress] is invoked periodically (throttled) with (scanned, fraudFound).
  /// The scan is fully on-device and does not depend on backend connectivity.
  static Future<HistoryScanSummary> scanInbox({
    void Function(int scanned, int fraudFound)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      return const HistoryScanSummary(
        totalInbox: 0,
        newScanned: 0,
        fraudCount: 0,
        safeCount: 0,
        skipped: 0,
        error: 'Scan previous messages is only available on Android.',
      );
    }

    List<SmsMessage> messages;
    try {
      messages = await Telephony.instance.getInboxSms();
    } catch (e) {
      return const HistoryScanSummary(
        totalInbox: 0,
        newScanned: 0,
        fraudCount: 0,
        safeCount: 0,
        skipped: 0,
        error: 'Could not read SMS inbox. Check that SMS permission is granted.',
      );
    }

    final existingLogs = await SmsStorageService.getLogs();
    final existingSmsIds = existingLogs
        .map((log) => log['systemSmsId']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    final newLogs = <Map<String, dynamic>>[];
    int scanned = 0;
    int fraudCount = 0;
    int safeCount = 0;
    int skipped = 0;

    DateTime lastEmit = DateTime.now();
    for (final msg in messages) {
      final body = (msg.body ?? '').trim();
      final sender = (msg.address ?? 'Unknown').trim();
      if (body.isEmpty) continue;

      final systemId = msg.id?.toString();
      if (systemId != null && existingSmsIds.contains(systemId)) {
        skipped++;
        continue;
      }

      final alreadyKnown = existingLogs.any((log) =>
          log['sender'] == sender &&
          log['message'] == body) ||
          newLogs.any((log) => log['sender'] == sender && log['message'] == body);
      if (alreadyKnown) {
        skipped++;
        continue;
      }

      final result = SmsDetectionService.analyze(message: body, sender: sender);

      final logEntry = <String, dynamic>{
        'id': 'history_${systemId ?? '${DateTime.now().microsecondsSinceEpoch}'}',
        'systemSmsId': systemId,
        'sender': sender,
        'message': body,
        'type': result.classification,
        'time': msg.date != null
            ? DateTime.fromMillisecondsSinceEpoch(msg.date!).toIso8601String()
            : DateTime.now().toIso8601String(),
        'threat': result.threatLevel,
        'matchedReasons': List<String>.from(result.matchedReasons),
        'source': 'HISTORY_SCAN',
        'hasFeedback': false,
        'userFeedback': null,
      };

      newLogs.add(logEntry);
      scanned++;
      if (result.classification == 'Fraud') {
        fraudCount++;
      } else {
        safeCount++;
      }

      final now = DateTime.now();
      if (now.difference(lastEmit).inMilliseconds >= 120) {
        lastEmit = now;
        onProgress?.call(scanned, fraudCount);
      }
    }
    onProgress?.call(scanned, fraudCount);

    if (newLogs.isNotEmpty) {
      await SmsStorageService.saveLogs([...newLogs, ...existingLogs]);
    }

    return HistoryScanSummary(
      totalInbox: messages.length,
      newScanned: scanned,
      fraudCount: fraudCount,
      safeCount: safeCount,
      skipped: skipped,
      logs: newLogs,
    );
  }

  }