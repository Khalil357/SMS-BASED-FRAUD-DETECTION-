import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/sms_detection_service.dart';
import '../services/sms_storage_service.dart';
import 'package:sms_based_fraud_detection/services/system_blocker.dart';
import '../services/sms_ingestion_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../main.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/interactive_threat_chart.dart';
import '../widgets/scam_detected_screen.dart';
import '../services/safety_tips_service.dart';
import 'safety_tips_page.dart';
import 'blocked_numbers_screen.dart';
import 'auth/login_page.dart';
import '../widgets/argus_nav_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Controllers
  final _scanController = TextEditingController();
  final _blockNumberController = TextEditingController();
  final _searchController = TextEditingController();

  // Scan state
  bool _isScanning = false;
  String? _scanResult;
  bool? _scanIsSafe;
  double _threatLevel = 0.0;

  // Search & Filter State
  String _searchQuery = '';
  String _filterThreat = 'All'; // 'All', 'Safe', 'Spam', 'Fraud'
  String _filterTimeframe = 'All'; // 'All', 'Today', '7 Days'

  // Settings & Permission State
  bool _isIngestionEnabled = true;
  bool _isNotificationsEnabled = true;
  double _notificationThreshold = 0.80;
  bool _hasSmsPermission = false;
  bool _hasNotificationPermission = true;

  // Logs list
  List<Map<String, dynamic>> _smsLogs = [];

  // Blocklist state
  List<Map<String, String>> _blockedNumbers = [];
  bool _isDefaultSmsApp = false;

  StreamSubscription? _smsStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.onSessionExpired = (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Your session has expired. Please log in again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    };
    _loadStoredData();
    _checkPermissions();

    // Listen to live incoming foreground messages
    _smsStreamSubscription = SmsIngestionService.smsStream.listen((newLog) {
      if (mounted) {
        setState(() {
          _smsLogs.insert(0, newLog);
        });
        _showForegroundThreatSnackBar(newLog);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanController.dispose();
    _blockNumberController.dispose();
    _searchController.dispose();
    _smsStreamSubscription?.cancel();
    AuthService.onSessionExpired = null;
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    final logs = await SmsStorageService.getLogs();
    final ingestion = await SmsStorageService.getBoolSetting(SmsStorageService.keyIngestionEnabled, true);
    final notifications = await SmsStorageService.getBoolSetting(SmsStorageService.keyNotificationsEnabled, true);
    final threshold = await SmsStorageService.getDoubleSetting(SmsStorageService.keyNotificationThreshold, 0.80);

    setState(() {
      _smsLogs = logs;
      _isIngestionEnabled = ingestion;
      _isNotificationsEnabled = notifications;
      _notificationThreshold = threshold;
    });

    _loadBlockedNumbers();

    // Fetch backend Fraud Scans (GET /api/scans/fraud?page=0&size=20)
    _fetchBackendFraudScans();
  }

  Future<void> _loadBlockedNumbers() async {
    final storedBlocked = await SmsStorageService.getBlockedNumberEntries();
    final isDefault = await SystemBlocker.isDefaultSmsApp();
    if (!mounted) return;
    setState(() {
      _blockedNumbers = storedBlocked
          .map((e) => {
                'number': e['number'] ?? '',
                'date': e['date'] ?? '',
                'reason': e['reason'] ?? '',
              })
          .toList();
      _isDefaultSmsApp = isDefault;
    });
    if (!isDefault) return;
    await SystemBlocker.syncBlocklistFromSystem();
    final synced = await SmsStorageService.getBlockedNumberEntries();
    if (mounted) {
      setState(() {
        _blockedNumbers = synced
            .map((e) => {
                  'number': e['number'] ?? '',
                  'date': e['date'] ?? '',
                  'reason': e['reason'] ?? '',
                })
            .toList();
      });
    }
  }

  Future<void> _fetchBackendFraudScans() async {
    try {
      final res = await AuthService.getFraudScans(page: 0, size: 20);
      if (res['success'] == true && res['content'] is List) {
        final List content = res['content'];
        bool hasNew = false;
        for (final item in content) {
          if (item is Map<String, dynamic>) {
            final msgText = item['message'] ?? item['messageBody'] ?? '';
            if (msgText.toString().trim().isEmpty) continue;

            final exists = _smsLogs.any((l) => l['message'] == msgText.toString());
            if (!exists) {
              final isScam = item['is_scam'] ?? item['isScam'] ?? (item['label'] == 'scam' || item['label'] == 'fraud');
              final conf = (item['confidence'] as num?)?.toDouble() ?? 0.95;
              final type = (isScam == true) ? 'Fraud' : ((item['label'] == 'spam') ? 'Spam' : 'Safe');
              final threatLevel = (type == 'Safe') ? (1.0 - conf).clamp(0.0, 1.0) : conf.clamp(0.0, 1.0);
              final logEntry = {
                'id': 'backend_fraud_${DateTime.now().millisecondsSinceEpoch}_${item.hashCode}',
                'sender': item['sender'] ?? 'Backend Shield Alert',
                'message': msgText.toString(),
                'type': type,
                'time': item['createdAt'] ?? item['time'] ?? DateTime.now().toIso8601String(),
                'threat': threatLevel,
                'matchedReasons': [
                  'Trained Model Label: ${item['label'] ?? (isScam ? 'scam' : 'safe')}',
                  'Threat Index: ${(threatLevel * 100).toStringAsFixed(1)}%'
                ],
                'hasFeedback': false,
                'userFeedback': null,
              };
              _smsLogs.insert(0, logEntry);
              await SmsStorageService.addLog(logEntry);
              hasNew = true;
            }
          }
        }
        if (hasNew && mounted) {
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _checkPermissions() async {
    final hasPerm = await SmsIngestionService.hasSmsPermission();
    final hasNotifPerm = await NotificationService.hasPermission();
    if (!mounted) return;
    setState(() {
      _hasSmsPermission = hasPerm;
      _hasNotificationPermission = hasNotifPerm;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await SmsIngestionService.requestSmsPermission();
    setState(() {
      _hasSmsPermission = granted;
    });
    if (granted) {
      await SmsIngestionService.startListening();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('SMS permissions granted! Auto-ingestion active.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permissions denied. Auto-ingestion unavailable.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showForegroundThreatSnackBar(Map<String, dynamic> log) {
    if (log['type'] == 'Fraud' || log['type'] == 'Spam') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                log['type'] == 'Fraud' ? Icons.gpp_bad : Icons.warning_amber_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alert: Threat detected from ${log['sender']}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: log['type'] == 'Fraud' ? AppTheme.primaryLight : Colors.amber.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              setState(() {
                _currentIndex = 1; // Go to Logs tab
              });
              _showLogDetail(log);
            },
          ),
        ),
      );
    }
  }

  void _confirmLogout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppTheme.primaryLight),
            const SizedBox(width: 10),
            Text(
              'Confirm Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of Argus SMS Fraud Interception Platform?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: Text(
              'Yes, Logout',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // Settings modification updates
  Future<void> _updateIngestion(bool val) async {
    await SmsStorageService.saveBoolSetting(SmsStorageService.keyIngestionEnabled, val);
    setState(() {
      _isIngestionEnabled = val;
    });
    if (val) {
      if (_hasSmsPermission) {
        await SmsIngestionService.startListening();
      }
    }
  }

  Future<void> _updateNotifications(bool val) async {
    await SmsStorageService.saveBoolSetting(SmsStorageService.keyNotificationsEnabled, val);
    if (!mounted) return;
    setState(() {
      _isNotificationsEnabled = val;
    });

    if (!val || !Platform.isAndroid) return;

    final granted = await NotificationService.requestPermission();
    if (!mounted) return;
    setState(() => _hasNotificationPermission = granted);
    if (!granted) {
      _showNotificationSettingsPrompt();
    }
  }

  void _showNotificationSettingsPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notifications are turned off for Argus. Open your phone\'s notification settings to allow them.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open settings',
          onPressed: () => _openNotificationSettings(),
        ),
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    final opened = await SystemBlocker.openNotificationSettings();
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open notification settings. Enable them manually in phone Settings > Apps > Argus > Notifications.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateThreshold(double val) async {
    await SmsStorageService.saveDoubleSetting(SmsStorageService.keyNotificationThreshold, val);
    setState(() {
      _notificationThreshold = val;
    });
  }

  // Live Metric Getters
  int get _scannedCount => _smsLogs.length;
  int get _threatsCount => _smsLogs.where((l) => l['type'] == 'Fraud').length;
  
  double get _safetyIndex {
    if (_scannedCount == 0) return 100.0;
    final safeCount = _smsLogs.where((l) => l['type'] == 'Safe').length;
    return (safeCount / _scannedCount) * 100.0;
  }

  List<Map<String, dynamic>> get _filteredLogs {
    return _smsLogs.where((log) {
      // 1. Search Query
      final message = (log['message'] as String).toLowerCase();
      final sender = (log['sender'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty && !message.contains(query) && !sender.contains(query)) {
        return false;
      }

      // 2. Threat Classification Filter
      final type = log['type'] as String;
      if (_filterThreat != 'All' && type != _filterThreat) {
        return false;
      }

      // 3. Timeframe Filter
      if (_filterTimeframe != 'All') {
        try {
          final logTime = DateTime.parse(log['time'] as String);
          final now = DateTime.now();
          if (_filterTimeframe == 'Today') {
            final todayStart = DateTime(now.year, now.month, now.day);
            if (logTime.isBefore(todayStart)) return false;
          } else if (_filterTimeframe == '7 Days') {
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            if (logTime.isBefore(sevenDaysAgo)) return false;
          }
        } catch (_) {
          return _filterTimeframe == 'All';
        }
      }

      return true;
    }).toList();
  }

  String _formatLogTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return timeStr;
    }
  }

  void _handleManualScan() async {
    final text = _scanController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isScanning = true;
      _scanResult = null;
    });

    // Submit scan to Backend API (POST /api/scans) to run trained ML model
    final backendResponse = await AuthService.submitScan(
      sender: 'Manual Scan',
      messageBody: text,
      source: 'MANUAL_QUERY',
    );

    SmsDetectionResult result;
    bool evaluatedByBackend = false;

    if (backendResponse['success'] == true && backendResponse['data'] != null) {
      final data = backendResponse['data'] as Map<String, dynamic>;
      result = SmsDetectionService.parseBackendResult(
        backendData: data,
        originalMessage: text,
        sender: 'Manual Scan',
      );
      evaluatedByBackend = true;
    } else {
      // Fallback to local rule engine if backend is unreachable
      result = SmsDetectionService.analyze(message: text, sender: 'Manual Scan');
    }

    final logEntry = {
      'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'Manual Scan',
      'message': text,
      'type': result.classification,
      'time': DateTime.now().toIso8601String(),
      'threat': result.threatLevel,
      'matchedReasons': result.matchedReasons,
      'hasFeedback': false,
      'userFeedback': null,
    };

    await SmsStorageService.addLog(logEntry);

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _scanIsSafe = result.classification == 'Safe';
      _threatLevel = result.threatLevel;

      final safeConfPct = ((1.0 - result.threatLevel) * 100).toStringAsFixed(1);
      final threatPct = (result.threatLevel * 100).toStringAsFixed(1);
      final modelTag = evaluatedByBackend ? 'AI Trained Model' : 'Local Rule Engine';

      if (result.classification == 'Fraud') {
        _scanResult = '🚨 High Risk Alert ($modelTag):\nScam/Phishing detected with $threatPct% Threat Index!\n\n${result.feedback}';
      } else if (result.classification == 'Spam') {
        _scanResult = '⚠️ Moderate Risk ($modelTag):\nSpam content detected with $threatPct% Threat Index.\n\n${result.feedback}';
      } else {
        _scanResult = '🛡️ Verified Safe ($modelTag):\nMessage evaluated as safe ($safeConfPct% Confidence, $threatPct% Threat Index).\n\n${result.feedback}';
      }

      if (result.classification == 'Fraud') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScamDetectedScreen(
              sender: 'Manual Scan',
              message: text,
              reasons: result.matchedReasons,
              onBlock: () {
                Navigator.pop(context);
                _blockNumberController.text = 'Manual Scan';
                _handleAddBlockedNumber(
                  reason: _deriveBlockReason(result.matchedReasons, text),
                );
              },
              onDismiss: () => Navigator.pop(context),
              onNavigateToTab: (index) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                setState(() => _currentIndex = index);
              },
            ),
          ),
        );
      }

      _smsLogs.insert(0, logEntry);
    });
  }

  void _handleFeedbackSubmit(String id, String feedbackType) async {
    await SmsStorageService.submitFeedback(logId: id, feedbackType: feedbackType);
    
    // Reload logs
    final logs = await SmsStorageService.getLogs();
    setState(() {
      _smsLogs = logs;
    });

    if (mounted) {
      Navigator.pop(context); // Close details modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback saved. SMS cataloged as "$feedbackType" for model optimization.'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLogDetail(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        final type = log['type'] as String;
        final rawThreat = (log['threat'] as num).toDouble();
        final threatVal = (type == 'Safe' && rawThreat > 0.50) ? (1.0 - rawThreat) : rawThreat;
        final matchedReasons = List<String>.from(log['matchedReasons'] ?? []);
        
        final Color classificationColor = type == 'Safe'
            ? Colors.green
            : (type == 'Fraud' ? AppTheme.primaryLight : Colors.amber.shade700);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SMS Threat Analysis',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                
                // Metadata Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sender: ${log['sender']}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatLogTime(log['time']),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // SMS Body Block
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    log['message'],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Threat Level Gauge
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Classification: $type',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: classificationColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Threat Index: ${(threatVal * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: classificationColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: classificationColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        type == 'Safe'
                            ? Icons.gpp_good
                            : (type == 'Fraud' ? Icons.gpp_bad : Icons.warning_amber),
                        color: classificationColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: threatVal,
                    minHeight: 8,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(classificationColor),
                  ),
                ),
                const SizedBox(height: 24),

                // Breakdown of analysis rules
                Text(
                  'ANALYSIS DETECTOR CHECKS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                  ),
                ),
                const SizedBox(height: 10),
                if (matchedReasons.isEmpty)
                  Text(
                    'No threat triggers found.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  ...matchedReasons.map((reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              type == 'Safe' ? Icons.check_circle : Icons.error,
                              size: 16,
                              color: classificationColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reason,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                const SizedBox(height: 28),

                // Feedback Section for ML optimization
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: classificationColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: classificationColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Is this classification incorrect?',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Help train the Argus ML Threat Engine by reporting misclassified messages in real-time.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (type != 'Safe')
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Mark Safe (FP)', style: TextStyle(fontSize: 12)),
                                onPressed: () => _handleFeedbackSubmit(log['id'], 'Safe'),
                              ),
                            ),
                          if (type == 'Safe') ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryLight,
                                  side: const BorderSide(color: AppTheme.primaryLight),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.gpp_bad, size: 16),
                                label: const Text('Mark Fraud', style: TextStyle(fontSize: 12)),
                                onPressed: () => _handleFeedbackSubmit(log['id'], 'Fraud'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber.shade800,
                                  side: BorderSide(color: Colors.amber.shade800),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.warning, size: 16),
                                label: const Text('Mark Spam', style: TextStyle(fontSize: 12)),
                                onPressed: () => _handleFeedbackSubmit(log['id'], 'Spam'),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDefaultSmsStatus();
      _checkPermissions();
    }
  }

  Future<void> _checkDefaultSmsStatus() async {
    final isDefault = await SystemBlocker.isDefaultSmsApp();
    if (!mounted || _isDefaultSmsApp == isDefault) return;
    setState(() => _isDefaultSmsApp = isDefault);
    if (isDefault) {
      await _loadBlockedNumbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Argus is now your default SMS app. Real blocking is active.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSetDefaultSmsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Opening your system default SMS settings — choose Argus to enable real blocking.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
    final opened = await SystemBlocker.requestDefaultSmsApp();
    if (!mounted) return;
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open the settings screen. Please pick Argus as your default SMS app in phone Settings.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _checkDefaultSmsStatus();
    }
  }

  void _handleAddBlockedNumber({String? reason}) async {
    final number = _blockNumberController.text.trim();
    if (number.isEmpty) return;
    final digitCount = number.replaceAll(RegExp(r'[^\d+]'), '').length;
    if (digitCount < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number.')),
      );
      return;
    }

    final normalized = SmsStorageService.normalizeNumber(number);
    final finalReason = reason ?? 'User blocked';
    final today = DateTime.now().toIso8601String().split('T').first;

    setState(() {
      _blockedNumbers.insert(0, {
        'number': normalized,
        'date': today,
        'reason': finalReason,
      });
      _blockNumberController.clear();
    });

    await SmsStorageService.addBlockedNumber(normalized, reason: finalReason);

    try {
      await AuthService.blockNumber(phoneNumber: normalized);
    } catch (_) {}

    final isDefault = await SystemBlocker.isDefaultSmsApp();
    bool systemBlocked = false;
    if (isDefault) {
      systemBlocked = await SystemBlocker.blockSystemNumber(normalized);
    }

    if (!mounted) return;

    if (!isDefault || !systemBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$normalized added. Enable Argus as default SMS app for real system blocking.'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'ENABLE',
            textColor: Colors.white,
            onPressed: _handleSetDefaultSmsApp,
          ),
        ),
      );
      setState(() => _isDefaultSmsApp = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$normalized added and blocked system-wide.'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleRemoveBlockedNumber(int index) async {
    final number = _blockedNumbers[index]['number'] as String;
    setState(() {
      _blockedNumbers.removeAt(index);
    });

    await SmsStorageService.removeBlockedNumber(number);

    try {
      await AuthService.unblockNumber(phoneNumber: number);
    } catch (_) {}

    if (await SystemBlocker.isDefaultSmsApp()) {
      await SystemBlocker.unblockSystemNumber(number);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$number removed from blocklist.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _deriveBlockReason(List<String> reasons, String message) {
    final lower = message.toLowerCase();
    final joinedReasons = reasons.join(' ').toLowerCase();
    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('www.') ||
        lower.contains('bit.ly') ||
        lower.contains('tinyurl') ||
        lower.contains('.xyz') ||
        lower.contains('.info')) {
      return 'Suspicious link';
    }
    if (joinedReasons.contains('phish') ||
        joinedReasons.contains('credential') ||
        joinedReasons.contains('account') ||
        lower.contains('bank') ||
        lower.contains('verify') ||
        lower.contains('otp')) {
      return 'Phishing';
    }
    return 'Scam SMS';
  }

  void _handleLogout() {
    AuthService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? 'Demo User';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/sms_fraud_inapp_icon.png',
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/sms_fraud_app_icon.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.shield,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currentIndex == 0
                  ? 'Argus'
                  : _currentIndex == 1
                      ? 'Scan Logs'
                      : _currentIndex == 2
                          ? 'Blocked'
                          : 'Profile & Settings',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          // 1. Light/Dark Mode Toggle Button (to the left of Profile)
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : theme.colorScheme.primary,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              SecureSignalApp.of(context).toggleTheme();
            },
          ),
          // 2. Profile Avatar Button on the Far Top Right
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentIndex = 3; // Open Profile & Settings view
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _currentIndex == 3
                        ? theme.colorScheme.primary
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: switch (_currentIndex) {
        0 => _buildHomeTab(fullName, theme, isDark),
        1 => _buildLogsTab(theme, isDark),
        2 => _buildBlocklistTab(theme, isDark),
        3 => _buildProfileTab(fullName, user, theme, isDark),
        _ => const SizedBox(),
      },
      bottomNavigationBar: ArgusNavBar(
        currentIndex: _currentIndex,
        onChanged: (index) {
          setState(() => _currentIndex = index);
          if (index == 2 || index == 3) {
            _checkDefaultSmsStatus();
          }
        },
      ),
    );
  }

  Widget _buildAnalyticsTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InteractiveThreatChart(logs: _smsLogs),
        ],
      ),
    );
  }

  Widget _buildTipOfTheDayBanner(ThemeData theme, bool isDark) {
    final tip = SafetyTipsService.getTipOfTheDay();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.shade700.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade700.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_rounded, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'FRAUD SAFETY TIP OF THE DAY',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SafetyTipsPage(),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tip.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tip.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              height: 1.3,
              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(String name, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tip of the Day Banner
          _buildTipOfTheDayBanner(theme, isDark),

          // Welcome Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: isDark ? AppTheme.heroBgGradientDark : AppTheme.heroBgGradientLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isIngestionEnabled && _hasSmsPermission
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isIngestionEnabled && _hasSmsPermission
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isIngestionEnabled && _hasSmsPermission
                                ? Icons.gpp_good
                                : Icons.gpp_maybe,
                            color: _isIngestionEnabled && _hasSmsPermission
                                ? Colors.green
                                : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isIngestionEnabled && _hasSmsPermission
                                ? 'Auto Ingestion Active'
                                : 'Auto Ingestion Inactive',
                            style: GoogleFonts.inter(
                              color: _isIngestionEnabled && _hasSmsPermission
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Statistics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'SMS Scanned',
                  value: _scannedCount.toString(),
                  icon: Icons.mark_chat_read_outlined,
                  iconColor: theme.colorScheme.primary,
                  theme: theme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'Threats Detected',
                  value: _threatsCount.toString(),
                  icon: Icons.gpp_bad_outlined,
                  iconColor: AppTheme.red,
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMetricCard(
            title: 'System Safety Index',
            value: '${_safetyIndex.toStringAsFixed(1)}% Secure',
            icon: Icons.insights,
            iconColor: Colors.teal,
            theme: theme,
            isDark: isDark,
            subtitle: _safetyIndex > 90
                ? 'Outstanding security level'
                : (_safetyIndex > 70 ? 'Moderate security warning' : 'High vulnerability warning'),
          ),
          const SizedBox(height: 24),

          // Interactive Threat Analysis Chart
          InteractiveThreatChart(logs: _smsLogs),
          const SizedBox(height: 24),

          // Manual Scan Title
          Text(
            'Analyze SMS Content',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a message below to analyze it for phishing attempts or malware distribution.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
            ),
          ),
          const SizedBox(height: 14),

          // Manual Scan Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: AppTheme.cardShadow(isDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _scanController,
                  labelText: 'Suspicious SMS Text',
                  hintText: 'e.g. You have won a parcel, claim here http://...',
                  prefixIcon: Icons.sms_outlined,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Analyze SMS',
                  isLoading: _isScanning,
                  icon: Icons.security_outlined,
                  onPressed: _handleManualScan,
                ),
                if (_scanResult != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: _scanIsSafe == true
                          ? Colors.green.withValues(alpha: 0.08)
                          : (_threatLevel > 0.8
                              ? Colors.red.withValues(alpha: 0.08)
                              : Colors.amber.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _scanIsSafe == true
                            ? Colors.green.withValues(alpha: 0.2)
                            : (_threatLevel > 0.8
                                ? Colors.red.withValues(alpha: 0.2)
                                : Colors.amber.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Threat Level: ${(_threatLevel * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: _scanIsSafe == true
                                ? Colors.green.shade700
                                : (_threatLevel > 0.8
                                    ? Colors.red.shade700
                                    : Colors.amber.shade700),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _scanResult!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required ThemeData theme,
    required bool isDark,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.teal.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab(ThemeData theme, bool isDark) {
    final filtered = _filteredLogs;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search Box
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by sender or message content...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Threat Filter Title
                Text(
                  'Threat:',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: ['All', 'Safe', 'Spam', 'Fraud'].map((type) {
                    final isSelected = _filterThreat == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _filterThreat = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(width: 16),
                
                // Date Filter Title
                Text(
                  'Time:',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: ['All', 'Today', '7 Days'].map((frame) {
                    final isSelected = _filterTimeframe == frame;
                    return ChoiceChip(
                      label: Text(frame),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _filterTimeframe = frame);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Logs List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching SMS logs found.',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final log = filtered[index];
                      final type = log['type'];
                      final Color statusColor = type == 'Safe'
                          ? Colors.green
                          : (type == 'Fraud' ? AppTheme.primaryLight : Colors.amber.shade700);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showLogDetail(log),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Sender: ${log['sender']}',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        type,
                                        style: GoogleFonts.inter(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  log['message'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatLogTime(log['time']),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Row(
                                      children: (() {
                                        final logType = log['type'] ?? 'Safe';
                                        final rawThreat = (log['threat'] as num?)?.toDouble() ?? 0.0;
                                        final displayThreat = (logType == 'Safe' && rawThreat > 0.50) ? (1.0 - rawThreat) : rawThreat;
                                        return [
                                          Text(
                                            'Threat: ${(displayThreat * 100).toStringAsFixed(0)}%',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.chevron_right, size: 14, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
                                        ];
                                      })(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocklistTab(ThemeData theme, bool isDark) {
    return Column(
      children: [
        if (_isDefaultSmsApp)
          _buildBlockingEnabledBanner(theme, isDark)
        else
          _buildBlockingOffHint(theme, isDark),
        Expanded(
          child: BlockedNumbersScreen(
            blockedNumbers: _blockedNumbers,
            onUnblock: _handleRemoveBlockedNumber,
            onBack: () => setState(() => _currentIndex = 0),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockingOffHint(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: _handleSetDefaultSmsApp,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        color: isDark ? const Color(0xFF3B2F16) : const Color(0xFFFFF4E5),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: Colors.amber.shade800, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Blocking is not enabled. Tap to set Argus as your default SMS app.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFFFE0B2) : Color(0xFF7A4B12),
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? const Color(0xFFFFE0B2) : Color(0xFF7A4B12),
                size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockingEnabledBanner(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: isDark ? const Color(0xFF123B2D) : const Color(0xFFE5F6EC),
      child: Row(
        children: [
          Icon(Icons.verified_user,
              color: isDark ? Colors.greenAccent.shade200 : AppTheme.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocking is active',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppTheme.textBodyLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Argus is your default SMS app — blocked numbers are intercepted at the system level.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.3,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppTheme.subtleLight,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle,
              size: 18,
              color: isDark ? Colors.greenAccent.shade200 : AppTheme.emerald),
        ],
      ),
    );
  }

  Widget _buildProfileTab(String name, Map<String, dynamic> user, ThemeData theme, bool isDark) {
    final email = user['email'] ?? 'demo@argus.com';
    final phone = user['phone_number'] ?? '+27820000000';
    final gender = user['gender'] ?? 'Male';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Details Header
          Center(
            child: Column(
              children: [
                const SizedBox(height: 10),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // User Info Fields
          Text(
            'ACCOUNT DETAILS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_android, 'Phone Number', phone, theme, isDark),
          _buildInfoRow(Icons.face_outlined, 'Gender', gender, theme, isDark),
          const SizedBox(height: 24),

          // Settings Section
          Text(
            'SETTINGS & PREFERENCES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Real SMS blocking (set Argus as default SMS app)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isDefaultSmsApp ? Icons.shield_outlined : Icons.info_outline,
                        color: _isDefaultSmsApp ? AppTheme.emerald : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Real SMS blocking',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _isDefaultSmsApp
                                  ? 'Active — Argus is your default SMS app. Blocked numbers are intercepted at the system level.'
                                  : 'Not enabled — Argus must be your default SMS app to intercept blocked numbers.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleSetDefaultSmsApp,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isDefaultSmsApp
                              ? AppTheme.emerald.withValues(alpha: 0.5)
                              : theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        foregroundColor: _isDefaultSmsApp ? AppTheme.emerald : theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(_isDefaultSmsApp ? Icons.manage_accounts_outlined : Icons.phonelink_setup, size: 18),
                      label: Text(_isDefaultSmsApp ? 'Manage default SMS app' : 'Enable blocking'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Auto-Ingestion SMS (Android only permission control)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mark_chat_unread_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto SMS Ingestion',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                Platform.isAndroid ? 'Background listen' : 'Unsupported on iOS',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isIngestionEnabled,
                        activeThumbColor: theme.colorScheme.primary,
                        onChanged: Platform.isAndroid
                            ? (val) => _updateIngestion(val)
                            : null, // Disabled on iOS
                      ),
                    ],
                  ),
                  if (Platform.isAndroid && !_hasSmsPermission) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'SMS Permission required to run background interception.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _requestPermissions,
                          child: const Text('Grant'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Threat Notifications Toggle
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary),
                          const SizedBox(width: 14),
                          Text(
                            'High Threat Notifications',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isNotificationsEnabled,
                        activeThumbColor: theme.colorScheme.primary,
                        onChanged: (val) => _updateNotifications(val),
                      ),
                    ],
                  ),
                  if (Platform.isAndroid && !_hasNotificationPermission) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Notifications are off for Argus. Allow them in your phone settings.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openNotificationSettings,
                          child: const Text('Open settings'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Alert Threshold Slider
          if (_isNotificationsEnabled)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notification Alert Threshold',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '${(_notificationThreshold * 100).toStringAsFixed(0)}% Threat',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Slider(
                      value: _notificationThreshold,
                      min: 0.1,
                      max: 0.95,
                      divisions: 17, // step of 0.05
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) => _updateThreshold(val),
                    ),
                    Text(
                      'You will only receive local device notifications for SMS messages rated above this threat index.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Theme Switch Card
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Dark Theme',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Switch(
                    value: isDark,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      SecureSignalApp.of(context).toggleTheme();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Logout Button
          CustomButton(
            text: 'Logout from System',
            type: ButtonType.ghost,
            icon: Icons.logout,
            onPressed: _handleLogout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value, ThemeData theme, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
