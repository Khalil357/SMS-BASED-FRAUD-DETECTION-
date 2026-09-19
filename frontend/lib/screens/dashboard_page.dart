import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/sms_detection_service.dart';
import '../services/sms_storage_service.dart';
import '../services/sms_ingestion_service.dart';
import '../services/notification_service.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../main.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/interactive_threat_chart.dart';
import '../widgets/message_classification_chart.dart';
import '../services/safety_tips_service.dart';
import 'safety_tips_page.dart';
import 'terms_and_conditions_page.dart';

class DashboardPage extends StatefulWidget {
  final Navigate onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

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
  String _filterThreat = 'All';
  String _filterTimeframe = 'All';

  // Settings & Permission State
  bool _isIngestionEnabled = true;
  bool _isNotificationsEnabled = true;
  double _notificationThreshold = 0.50;
  bool _hasSmsPermission = false;
  bool _isTipDismissed = false;

  // Logs list
  List<Map<String, dynamic>> _smsLogs = [];

  // NEW: tracks which log id is currently being marked-as-safe (backend call in flight)
  String? _markingSafeLogId;

  // Blocklist state
  final List<Map<String, String>> _blockedNumbers = [
    {'number': '+27829876543', 'date': '2026-08-20'},
    {'number': '+27831112222', 'date': '2026-08-21'},
    {'number': '+14155552671', 'date': '2026-08-22'},
  ];

  StreamSubscription? _smsStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDataAndPermissions();

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStoredData();
    }
  }

  Future<void> _loadDataAndPermissions() async {
    await NotificationService.requestPermission();
    await _loadStoredData();
    await _checkPermissions();
    _checkFirstTimeIngestionPrompt();
  }

  void _checkFirstTimeIngestionPrompt() async {
    final hasSeenPrompt = await SmsStorageService.getBoolSetting(
        'has_seen_ingestion_onboarding', false);
    if (!hasSeenPrompt && (!_hasSmsPermission || !_isIngestionEnabled)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showIngestionOnboardingBottomSheet();
        }
      });
    }
  }

  void _showIngestionOnboardingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.red,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Activate Real-Time SMS Protection',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Argus protects you from SMS phishing, bank scams, and fake lottery rewards by automatically analyzing incoming texts in real-time.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildOnboardingFeatureItem(
                icon: Icons.flash_on_rounded,
                title: 'Instant Background Ingestion',
                subtitle:
                    'Automatically scans SMS as soon as they land on your phone.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildOnboardingFeatureItem(
                icon: Icons.lock_outline_rounded,
                title: 'On-Device Privacy First',
                subtitle:
                    'Messages are analyzed locally on your device using rule-based AI.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildOnboardingFeatureItem(
                icon: Icons.notifications_active_outlined,
                title: 'Live Threat Alerts',
                subtitle:
                    'Get notified immediately if a message is identified as fraud.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.security),
                label: const Text(
                  'Enable Auto Protection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () async {
                  await SmsStorageService.saveBoolSetting(
                      'has_seen_ingestion_onboarding', true);
                  if (mounted) Navigator.pop(context);
                  await _requestPermissions();
                  await _updateIngestion(true);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await SmsStorageService.saveBoolSetting(
                      'has_seen_ingestion_onboarding', true);
                  if (mounted) Navigator.pop(context);
                },
                child: Text(
                  'Skip for Now',
                  style: TextStyle(
                      color:
                          isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnboardingFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanController.dispose();
    _blockNumberController.dispose();
    _searchController.dispose();
    _smsStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    final logs = await SmsStorageService.getLogs();
    final ingestion = await SmsStorageService.getBoolSetting(
        SmsStorageService.keyIngestionEnabled, true);
    final notifications = await SmsStorageService.getBoolSetting(
        SmsStorageService.keyNotificationsEnabled, true);
    final threshold = await SmsStorageService.getDoubleSetting(
        SmsStorageService.keyNotificationThreshold, 0.50);

    setState(() {
      _smsLogs = logs;
      _isIngestionEnabled = ingestion;
      _isNotificationsEnabled = notifications;
      _notificationThreshold = threshold;
    });

    _fetchBackendFraudScans();
    AuthService.fetchUserProfile().then((_) {
      if (mounted) setState(() {});
    });
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

            final exists =
                _smsLogs.any((l) => l['message'] == msgText.toString());
            if (!exists) {
              final isScam = item['is_scam'] ??
                  item['isScam'] ??
                  (item['label'] == 'scam' || item['label'] == 'fraud');
              final conf = (item['confidence'] as num?)?.toDouble() ?? 0.95;
              final type = isScam == true ? 'Fraud' : 'Safe';
              final threatLevel = (type == 'Safe')
                  ? (1.0 - conf).clamp(0.0, 1.0)
                  : conf.clamp(0.0, 1.0);
              final backendScanId = item['id']?.toString();
              final logEntry = {
                'id': backendScanId ??
                    'backend_fraud_${DateTime.now().millisecondsSinceEpoch}_${item.hashCode}',
                'backendId': backendScanId,
                'sender': item['sender'] ?? 'Backend Shield Alert',
                'message': msgText.toString(),
                'type': type,
                'time': item['createdAt'] ??
                    item['time'] ??
                    DateTime.now().toIso8601String(),
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
    setState(() {
      _hasSmsPermission = hasPerm;
    });
  }

  Future<void> _requestPermissions({bool forcePrompt = false}) async {
    final granted = await SmsIngestionService.requestSmsPermission(forcePrompt: forcePrompt);
    setState(() {
      _hasSmsPermission = granted;
    });
    if (granted) {
      await SmsIngestionService.startListening();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('SMS permissions granted! Auto-ingestion active.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('SMS permissions denied. Auto-ingestion unavailable.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showForegroundThreatSnackBar(Map<String, dynamic> log) {
    if (log['type'] == 'Fraud') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.gpp_bad, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alert: Threat detected from ${log['sender']}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              setState(() {
                _currentIndex = 1;
              });
              _showLogDetail(log);
            },
          ),
        ),
      );
    }
  }

  Future<void> _updateIngestion(bool val) async {
    await SmsStorageService.saveBoolSetting(
        SmsStorageService.keyIngestionEnabled, val);
    setState(() {
      _isIngestionEnabled = val;
    });
    if (val) {
      await _requestPermissions(forcePrompt: true);
      if (_hasSmsPermission) {
        await SmsIngestionService.startListening();
      }
    }
  }

  /// Shows an informational dialog when the user tries to turn ON
  /// auto-ingestion explaining what it does before activating.
  Future<void> _showEnableIngestionInfoDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(42),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cyberGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppTheme.cyberGreen,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enable Automatic Ingestion',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Automatic Ingestion monitors incoming SMS in real-time to analyze potential threat vectors and alert you instantly if a fraud or phishing attempt is detected.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppTheme.subtleDark
                        : AppTheme.subtleLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Cancel button
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        width: 103,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(34),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 19),
                    // Enable button
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        width: 103,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.cyberGreen,
                          borderRadius: BorderRadius.circular(34),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Enable',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _updateIngestion(true);
    }
  }

  /// Shows a custom confirmation dialog when the user tries to turn OFF
  /// auto-ingestion. If confirmed, calls [_updateIngestion(false)].
  Future<void> _showTurnOffIngestionDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(42),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Turn Off Automatic\nIngestion',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want\nto turn off automatic ingestion',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppTheme.subtleDark
                        : AppTheme.subtleLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Cancel button
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        width: 103,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(34),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 19),
                    // Turn Off button
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        width: 103,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.primaryDark
                              : AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(34),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Turn Off',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _updateIngestion(false);
    }
  }

  Future<void> _updateNotifications(bool val) async {
    await SmsStorageService.saveBoolSetting(
        SmsStorageService.keyNotificationsEnabled, val);
    if (val) {
      final granted = await NotificationService.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission is required for live threat alerts.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() {
      _isNotificationsEnabled = val;
    });
  }

  Future<void> _updateThreshold(double val) async {
    await SmsStorageService.saveDoubleSetting(
        SmsStorageService.keyNotificationThreshold, val);
    setState(() {
      _notificationThreshold = val;
    });
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
            const Icon(Icons.logout_rounded, color: AppTheme.red),
            const SizedBox(width: 10),
            Text(
              'Confirm Logout',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
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
              backgroundColor: AppTheme.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: Text(
              'Yes, Logout',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      widget.onNavigate(AuthPage.login);
    }
  }

  int get _scannedCount => _smsLogs.length;
  int get _threatsCount => _smsLogs.where((l) => l['type'] == 'Fraud').length;

  double get _safetyIndex {
    // Argus System Protection Index represents real-time shield coverage.
    // When live threat shield is active, 100% of incoming messages are guarded and intercepted.
    if (_isIngestionEnabled && _hasSmsPermission) {
      return 100.0;
    }
    return 50.0;
  }

  List<Map<String, dynamic>> get _filteredLogs {
    return _smsLogs.where((log) {
      final message = (log['message'] as String).toLowerCase();
      final sender = (log['sender'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty &&
          !message.contains(query) &&
          !sender.contains(query)) {
        return false;
      }

      final type = log['type'] as String;
      if (_filterThreat != 'All' && type != _filterThreat) {
        return false;
      }

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

    final backendResponse = await AuthService.submitScan(
      sender: 'Manual Scan',
      messageBody: text,
      source: 'MANUAL_QUERY',
    );

    SmsAnalysisResult result;
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
      result =
          SmsDetectionService.analyze(message: text, sender: 'Manual Scan');
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
      final modelTag =
          evaluatedByBackend ? 'AI Trained Model' : 'Local Rule Engine';

      if (result.classification == 'Fraud') {
        _scanResult =
            '🚨 High Risk Alert ($modelTag):\nScam/Phishing detected with $threatPct% Threat Index!\n\n${result.feedback}';
      } else {
        _scanResult =
            '🛡️ Verified Safe ($modelTag):\nMessage evaluated as safe ($safeConfPct% Confidence, $threatPct% Threat Index).\n\n${result.feedback}';
      }

      _smsLogs.insert(0, logEntry);
    });
  }

  void _handleFeedbackSubmit(String id, String feedbackType) async {
    await SmsStorageService.submitFeedback(
        logId: id, feedbackType: feedbackType);

    final logs = await SmsStorageService.getLogs();
    setState(() {
      _smsLogs = logs;
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Feedback saved. SMS cataloged as "$feedbackType" for model optimization.'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showMessageActionSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _reportToAuthorities(Map<String, dynamic> log) async {
    final fraudsterNumber = log['sender']?.toString().trim() ?? '';
    if (fraudsterNumber.isEmpty || fraudsterNumber == 'Unknown') {
      _showMessageActionSnackBar(
          'Unable to find a phone number for this message.',
          isError: true);
      return;
    }

    try {
      final launched = await launchUrl(
        Uri(
            scheme: 'sms',
            path: '15040',
            queryParameters: {'body': 'Fraud $fraudsterNumber'}),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showMessageActionSnackBar('Unable to open the messaging app.',
            isError: true);
      }
    } catch (_) {
      _showMessageActionSnackBar('Unable to open the messaging app.',
          isError: true);
    }
  }

  void _confirmMarkAsSafe(Map<String, dynamic> log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 10),
            Text(
              'Mark as Safe?',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to mark this message as safe?',
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
              backgroundColor: AppTheme.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _markAsSafe(log);
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmMarkAsFraud(Map<String, dynamic> log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.gpp_bad, color: AppTheme.red),
            const SizedBox(width: 10),
            Text(
              'Mark as Fraud?',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to mark this message as fraud?',
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
              backgroundColor: AppTheme.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _markAsFraud(log);
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// CHANGED: now calls the backend to delete the fraud row first.
  /// Local state (and the "Safe" reclassification) is only applied once
  /// the backend confirms the row is gone. If there's no backendId (e.g.
  /// this was a manual scan, never stored server-side as fraud), it skips
  /// the backend call and just updates locally, same as before.
  Future<void> _markAsSafe(Map<String, dynamic> log) async {
    final logId = log['id']?.toString() ?? '';
    final backendId = log['backendId']?.toString() ?? log['scanId']?.toString() ?? log['id']?.toString();

    if (backendId != null &&
        backendId.isNotEmpty &&
        !backendId.startsWith('manual_') &&
        !backendId.startsWith('auto_') &&
        !backendId.startsWith('mock_')) {
      setState(() {
        _markingSafeLogId = logId;
      });

      final result = await AuthService.deleteFraudScan(id: backendId);

      if (!mounted) return;

      setState(() {
        _markingSafeLogId = null;
      });

      if (result['success'] != true) {
        _showMessageActionSnackBar(
          result['message'] ?? 'Failed to delete record on the server.',
          isError: true,
        );
        return; // Stop here — do NOT remove local record if authenticated backend DELETE call failed!
      }
    }

    // Reaches here only if: there was no backendId to check,
    // OR the backend confirmed the row was deleted.
    await SmsStorageService.submitFeedback(logId: logId, feedbackType: 'Safe');
    final logs = await SmsStorageService.getLogs();
    if (!mounted) return;

    setState(() {
      _smsLogs = logs;
    });
    Navigator.pop(context);
    _showMessageActionSnackBar('Record marked as safe and updated successfully.');
  }

  Future<void> _markAsFraud(Map<String, dynamic> log) async {
    final result = await AuthService.addFraudScan(
      sender: log['sender']?.toString() ?? '',
      message: log['message']?.toString() ?? '',
    );
    if (!mounted) return;

    if (result['success'] != true) {
      _showMessageActionSnackBar(
        result['message']?.toString() ?? 'Failed to update on the server.',
        isError: true,
      );
      return;
    }

    final logId = log['id']?.toString() ?? '';
    await SmsStorageService.submitFeedback(logId: logId, feedbackType: 'Fraud');
    final logs = await SmsStorageService.getLogs();
    if (!mounted) return;

    setState(() {
      _smsLogs = logs;
    });
    Navigator.pop(context);
    _showMessageActionSnackBar(
      result['message']?.toString() ??
          'Your response has successfully been updated.',
    );
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
        final threatVal = (type == 'Safe' && rawThreat > 0.50)
            ? (1.0 - rawThreat)
            : rawThreat;
        final matchedReasons = List<String>.from(log['matchedReasons'] ?? []);

        final Color classificationColor =
            type == 'Safe' ? Colors.green : AppTheme.red;

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
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade300,
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
                        color:
                            isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
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
                              color: isDark
                                  ? AppTheme.subtleDark
                                  : AppTheme.subtleLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: classificationColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: classificationColor.withOpacity(0.3)),
                      ),
                      child: Icon(
                        type == 'Safe' ? Icons.gpp_good : Icons.gpp_bad,
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
                    backgroundColor: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(classificationColor),
                  ),
                ),
                const SizedBox(height: 24),

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

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: classificationColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: classificationColor.withOpacity(0.1),
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
                          color: isDark
                              ? AppTheme.subtleDark
                              : AppTheme.subtleLight,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // NEW: show a spinner instead of the action buttons
                      // while a mark-as-safe backend call is in flight for
                      // this specific log.
                      if (_markingSafeLogId == log['id']?.toString())
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (type == 'Fraud') ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Mark Safe (FP)',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () => _confirmMarkAsSafe(log),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.red,
                                  side: const BorderSide(color: AppTheme.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                ),
                                icon: const Icon(Icons.flag_outlined, size: 16),
                                label: const Text('Report',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () => _reportToAuthorities(log),
                              ),
                            ],
                            if (type == 'Safe')
                              OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.red,
                                        side: const BorderSide(
                                            color: AppTheme.red),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        alignment: Alignment.center,
                                      ),
                                      icon: const Icon(Icons.gpp_bad, size: 16),
                                      label: const Text('Mark Fraud',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () =>
                                          _confirmMarkAsFraud(log),
                              ),
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

  void _handleAddBlockedNumber() {
    final number = _blockNumberController.text.trim();
    if (number.isEmpty) return;
    if (number.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number.')),
      );
      return;
    }

    setState(() {
      _blockedNumbers.insert(0, {
        'number': number,
        'date': DateTime.now().toString().split(' ')[0],
      });
      _blockNumberController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$number added to blocklist.'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleRemoveBlockedNumber(int index) {
    final number = _blockedNumbers[index]['number'];
    setState(() {
      _blockedNumbers.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$number removed from blocklist.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? user['fullName'] ?? user['name'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: _currentIndex == 4 ? 0 : 16,
        leading: _currentIndex == 4
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Home',
                onPressed: () => setState(() => _currentIndex = 0),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentIndex != 4) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/sms_fraud_inapp_icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/sms_fraud_app_icon.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.shield,
                      color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _currentIndex == 0
                  ? 'Argus'
                  : _currentIndex == 1
                      ? 'Scan Logs'
                      : _currentIndex == 2
                          ? 'Analytics'
                          : _currentIndex == 3
                              ? 'Safety Tips'
                              : 'Profile',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: isDark ? AppTheme.cyberTextPrimary : null,
              ),
            ),
          ],
        ),
        actions: [
          // Interactive Status Pill
          InkWell(
            onTap: () {
              final isActive = _isIngestionEnabled && _hasSmsPermission;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        isActive ? Icons.shield_rounded : Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isActive
                              ? 'Auto-Ingestion Active: Real-time SMS threat shield is monitoring incoming messages.'
                              : 'Auto-Ingestion Inactive: Real-time SMS shield is currently turned off.',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: isActive ? Colors.green.shade700 : AppTheme.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(milliseconds: 2500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_isIngestionEnabled && _hasSmsPermission)
                    ? AppTheme.cyberGreen.withOpacity(0.12)
                    : AppTheme.cyberRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (_isIngestionEnabled && _hasSmsPermission)
                      ? AppTheme.cyberGreen.withOpacity(0.4)
                      : AppTheme.cyberRed.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: (_isIngestionEnabled && _hasSmsPermission)
                          ? AppTheme.cyberGreen
                          : AppTheme.cyberRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    (_isIngestionEnabled && _hasSmsPermission) ? 'Active' : 'Inactive',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (_isIngestionEnabled && _hasSmsPermission)
                          ? AppTheme.cyberGreen
                          : AppTheme.cyberRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentIndex = 4;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _currentIndex == 4
                        ? (isDark ? AppTheme.cyberRed : theme.colorScheme.primary)
                        : (isDark ? AppTheme.cyberBorder : const Color(0xFFE2E8F0)),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: isDark
                      ? AppTheme.cyberRed.withOpacity(0.15)
                      : theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
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
        2 => _buildAnalyticsTab(theme, isDark),
        3 => const SafetyTipsPage(),
        4 => _buildProfileTab(fullName, user, theme, isDark),
        _ => const SizedBox(),
      },
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              theme: theme,
              isDark: isDark,
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.shield_outlined,
              activeIcon: Icons.shield_rounded,
              label: 'Logs',
              badgeCount: _threatsCount,
              theme: theme,
              isDark: isDark,
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics_rounded,
              label: 'Analytics',
              theme: theme,
              isDark: isDark,
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.lightbulb_outline,
              activeIcon: Icons.lightbulb_rounded,
              label: 'Tips',
              theme: theme,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? activeColor
                      : (isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
                  size: 22,
                ),
                if (badgeCount > 0 && index == 1)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: activeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(ThemeData theme, bool isDark) {
    final cardBg = isDark ? AppTheme.cyberCard : AppTheme.cardLight;
    final borderColor = isDark ? AppTheme.cyberBorder : AppTheme.borderLight;
    final textPrimary = isDark ? AppTheme.cyberTextPrimary : AppTheme.textBodyLight;
    final textMuted = isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THREAT ANALYTICS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Scanned Messages & Risk Breakdown',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visual breakdown of your scanned messages and daily security trends.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Message Classification Distribution Chart
          MessageClassificationChart(logs: _smsLogs),
          const SizedBox(height: 16),

          // Daily Threat Analysis Trend Bar Chart
          InteractiveThreatChart(logs: _smsLogs),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTipOfTheDayBanner(ThemeData theme, bool isDark) {
    final accentColor = AppTheme.cyberRed;
    if (_isTipDismissed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cyberCard : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: accentColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Safety Tip Hidden',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _isTipDismissed = false;
                });
              },
              child: Text(
                'Show Safety Tip',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return TipOfTheDayBannerWidget(
      key: ValueKey(_isTipDismissed),
      theme: theme,
      isDark: isDark,
      onDismiss: () {
        if (mounted) {
          setState(() {
            _isTipDismissed = true;
          });
        }
      },
      onViewAll: () {
        if (mounted) {
          setState(() {
            _currentIndex = 3;
          });
        }
      },
    );
  }

  Widget _buildHomeAnalyticsDirectiveCard(
    ThemeData theme,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THREAT ANALYTICS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'View charts and trends of scanned messages.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              setState(() {
                _currentIndex = 2; // Switch to Analytics tab
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Analytics',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(String name, ThemeData theme, bool isDark) {
    final cardBg = isDark ? AppTheme.cyberCard : AppTheme.cardLight;
    final cardSecBg = isDark ? AppTheme.cyberCardSecondary : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.cyberBorder : AppTheme.borderLight;
    final textPrimary = isDark ? AppTheme.cyberTextPrimary : AppTheme.textBodyLight;
    final textMuted = isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tip of the Day Banner
          _buildTipOfTheDayBanner(theme, isDark),
          const SizedBox(height: 16),

          // Security Status Card
          _buildCyberSecurityStatusCard(theme, isDark, cardBg, borderColor, textPrimary, textMuted),
          const SizedBox(height: 16),

          // Statistics Cards Row (SMS Scanned / Threats Blocked)
          _buildCyberStatsRow(theme, isDark, cardBg, cardSecBg, borderColor, textPrimary, textMuted),
          const SizedBox(height: 12),

          // Analytics Directive Card (Right after 2 stats cards, short & compact)
          _buildHomeAnalyticsDirectiveCard(theme, isDark, cardBg, borderColor, textPrimary, textMuted),
          const SizedBox(height: 16),

          // Analyze SMS & Links Section
          _buildCyberAnalyzeSection(theme, isDark, cardBg, borderColor, textPrimary, textMuted),
          const SizedBox(height: 16),

          // Recent Activity Section
          _buildCyberRecentActivitySection(theme, isDark, cardBg, borderColor, textPrimary, textMuted),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCyberSecurityStatusCard(
    ThemeData theme,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    final isProtected = _isIngestionEnabled && _hasSmsPermission;
    final statusTitle = isProtected ? 'System Protected' : 'Action Required';
    final statusDesc = isProtected
        ? 'Argus AI sentinel is monitoring incoming communications.'
        : 'Enable auto-ingestion & SMS permissions to activate real-time shield.';
    final percentageText = '${_safetyIndex.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyberRed.withOpacity(isDark ? 0.08 : 0.04),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECURITY STATUS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.cyberRed,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusTitle,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusDesc,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Circular progress indicator with red glow ring
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppTheme.cyberCardSecondary : const Color(0xFFF1F5F9),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyberRed.withOpacity(0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                  border: Border.all(color: AppTheme.cyberRed, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      percentageText,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'SECURE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.cyberGreen,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: borderColor,
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _threatsCount == 0 ? AppTheme.cyberGreen : AppTheme.cyberRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _threatsCount == 0
                        ? 'Zero critical exploits detected'
                        : '$_threatsCount threat alerts detected',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      'Scan Details',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.cyberCyan,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.cyberCyan),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calculateWeeklyScannedStats() {
    if (_smsLogs.isEmpty) {
      return '0% this week';
    }
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    int currentWeekCount = 0;
    int previousWeekCount = 0;

    for (final log in _smsLogs) {
      DateTime? logTime;
      final rawTs = log['timestamp'] ?? log['time'] ?? log['date'] ?? log['receivedAt'];
      if (rawTs is DateTime) {
        logTime = rawTs;
      } else if (rawTs is String) {
        logTime = DateTime.tryParse(rawTs);
      } else if (rawTs is int) {
        logTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
      }

      if (logTime != null) {
        if (logTime.isAfter(sevenDaysAgo)) {
          currentWeekCount++;
        } else if (logTime.isAfter(fourteenDaysAgo)) {
          previousWeekCount++;
        }
      } else {
        currentWeekCount++;
      }
    }

    if (previousWeekCount == 0) {
      if (currentWeekCount == 0) {
        return '0% this week';
      }
      return '↑ 100% this week';
    }

    final diff = currentWeekCount - previousWeekCount;
    final percent = ((diff / previousWeekCount) * 100).round();

    if (percent > 0) {
      return '↑ $percent% this week';
    } else if (percent < 0) {
      return '↓ ${percent.abs()}% this week';
    } else {
      return '0% this week';
    }
  }

  Widget _buildCyberStatsRow(
    ThemeData theme,
    bool isDark,
    Color cardBg,
    Color cardSecBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    final weeklyStatText = _calculateWeeklyScannedStats();
    final isUp = weeklyStatText.startsWith('↑');
    final isDown = weeklyStatText.startsWith('↓');
    final trendColor = isUp
        ? AppTheme.cyberGreen
        : (isDown ? AppTheme.cyberRed : textMuted);
    final trendIcon = isUp
        ? Icons.trending_up_rounded
        : (isDown ? Icons.trending_down_rounded : Icons.remove_rounded);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SMS Scanned',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const Icon(Icons.mark_chat_read_outlined, size: 18, color: AppTheme.cyberCyan),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_scannedCount',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(trendIcon, size: 13, color: trendColor),
                    const SizedBox(width: 4),
                    Text(
                      weeklyStatText,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Threats Detected',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                    const Icon(Icons.gpp_bad_outlined, size: 18, color: AppTheme.cyberRed),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_threatsCount',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.cyberRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Real-time shield',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.cyberRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCyberAnalyzeSection(
    ThemeData theme,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyze SMS',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paste suspicious messages to verify safety of a message through the Argus Detection System',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _scanController,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            style: GoogleFonts.inter(fontSize: 13, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Paste suspicious SMS or message link...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: textMuted),
              prefixIcon: Icon(Icons.sms_outlined, color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary, size: 20),
              filled: true,
              fillColor: isDark ? AppTheme.cyberCardSecondary : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyberRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.security_rounded, size: 18),
              label: Text(
                _isScanning ? 'Analyzing Heuristics...' : '● Analyze Message',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              onPressed: _isScanning ? null : _handleManualScan,
            ),
          ),

          if (_scanResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _scanIsSafe == true
                    ? AppTheme.cyberGreen.withOpacity(0.1)
                    : AppTheme.cyberRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _scanIsSafe == true ? AppTheme.cyberGreen : AppTheme.cyberRed,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _scanIsSafe == true ? Icons.gpp_good_rounded : Icons.gpp_bad_rounded,
                            color: _scanIsSafe == true ? AppTheme.cyberGreen : AppTheme.cyberRed,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Threat Level: ${(_threatLevel * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _scanIsSafe == true ? AppTheme.cyberGreen : AppTheme.cyberRed,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, size: 18),
                        color: textMuted,
                        tooltip: 'Dismiss result',
                        onPressed: () {
                          setState(() {
                            _scanResult = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _scanResult!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCyberRecentActivitySection(
    ThemeData theme,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
  ) {
    final recentLogs = _smsLogs.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT ACTIVITY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.cyberCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (recentLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No recent activity logged yet.',
                  style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                ),
              ),
            )
          else
            ...List.generate(recentLogs.length, (idx) {
              final log = recentLogs[idx];
              final type = log['type'] as String? ?? 'Safe';
              final isSafe = type == 'Safe';
              final sender = log['sender'] as String? ?? 'Unknown';
              final msg = log['message'] as String? ?? '';
              final timeStr = _formatLogTime(log['time'] as String? ?? '');

              return Padding(
                padding: EdgeInsets.only(bottom: idx == recentLogs.length - 1 ? 0 : 12.0),
                child: InkWell(
                  onTap: () => _showLogDetail(log),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cyberCardSecondary : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSafe
                                ? AppTheme.cyberGreen.withOpacity(0.12)
                                : AppTheme.cyberRed.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSafe ? Icons.shield_outlined : Icons.warning_amber_rounded,
                            color: isSafe ? AppTheme.cyberGreen : AppTheme.cyberRed,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSafe ? 'Message Verified Safe' : 'Suspicious Message Detected',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$sender • $msg',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSafe
                                    ? AppTheme.cyberGreen.withOpacity(0.15)
                                    : AppTheme.cyberRed.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSafe ? 'Safe' : 'Scam',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSafe ? AppTheme.cyberGreen : AppTheme.cyberRed,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(fontSize: 9, color: textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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
              color: iconColor.withOpacity(0.1),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Threat:',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: ['All', 'Safe', 'Fraud'].map((type) {
                    final isSelected = _filterThreat == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _filterThreat = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(width: 16),

                Text(
                  'Time:',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: ['All', 'Today', '7 Days'].map((frame) {
                    final isSelected = _filterTimeframe == frame;
                    return ChoiceChip(
                      label: Text(frame),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
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

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadStoredData();
              },
              child: filtered.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 350,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: isDark
                                  ? AppTheme.subtleDark
                                  : AppTheme.subtleLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No matching SMS logs found.',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pull down to refresh and sync remote alerts.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.subtleDark
                                    : AppTheme.subtleLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final log = filtered[index];
                        final type = log['type'] ?? 'Safe';
                        final isSafe = type == 'Safe';
                        final isFraud = type == 'Fraud';
                        final Color statusColor = isSafe
                            ? AppTheme.cyberGreen
                            : (isFraud ? AppTheme.cyberRed : AppTheme.cyberCyan);

                        final cardBg = isDark ? AppTheme.cyberCard : AppTheme.cardLight;
                        final borderColor = isDark ? AppTheme.cyberBorder : AppTheme.borderLight;
                        final textPrimary = isDark ? AppTheme.cyberTextPrimary : AppTheme.textBodyLight;
                        final textMuted = isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight;

                        final rawThreat = (log['threat'] as num?)?.toDouble() ?? 0.0;
                        final displayThreat = (isSafe && rawThreat > 0.50)
                            ? (1.0 - rawThreat)
                            : rawThreat;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(isDark ? 0.08 : 0.04),
                                blurRadius: 12,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
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
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isSafe
                                                    ? Icons.mark_email_read_rounded
                                                    : (isFraud ? Icons.gpp_bad_rounded : Icons.campaign_rounded),
                                                color: statusColor,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                log['sender']?.toString() ?? 'Unknown Sender',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          isSafe ? 'SAFE' : (isFraud ? 'FRAUD THREAT' : 'SPAM PROMO'),
                                          style: GoogleFonts.inter(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      log['message']?.toString() ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatLogTime(log['time']),
                                        style: GoogleFonts.inter(
                                          color: textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (displayThreat > 0.60 ? AppTheme.cyberRed : AppTheme.cyberGreen).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Threat Index: ${(displayThreat * 100).toStringAsFixed(0)}%',
                                              style: GoogleFonts.inter(
                                                color: displayThreat > 0.60 ? AppTheme.cyberRed : AppTheme.cyberGreen,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.chevron_right_rounded, size: 16, color: textMuted),
                                        ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildBlocklistTab(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Blocked Senders',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'SMS messages from numbers on this blocklist will be automatically rejected and reported.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _blockNumberController,
                  labelText: 'Block Number',
                  hintText: 'e.g. +27820000000',
                  prefixIcon: Icons.block,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _handleAddBlockedNumber,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _blockedNumbers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: isDark
                              ? AppTheme.subtleDark
                              : AppTheme.subtleLight,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No numbers blocked yet',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _blockedNumbers.length,
                    itemBuilder: (context, index) {
                      final item = _blockedNumbers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.red,
                            child: Icon(Icons.block,
                                color: Colors.white, size: 16),
                          ),
                          title: Text(
                            item['number']!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('Blocked on ${item['date']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _handleRemoveBlockedNumber(index),
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

  Widget _buildProfileTab(
      String name, Map<String, dynamic> user, ThemeData theme, bool isDark) {
    final fullName = user['full_name'] ?? user['fullName'] ?? user['name'] ?? user['username'] ?? (name.isNotEmpty ? name : 'User');
    final rawEmail = user['email'] ?? user['email_address'] ?? user['emailAddress'] ?? user['gmail'] ?? user['user_email'];
    final email = (rawEmail != null && rawEmail.toString().isNotEmpty) ? rawEmail.toString() : 'Not Provided';
    final rawPhone = user['phone_number'] ?? user['phoneNumber'] ?? user['phone'] ?? user['mobile'] ?? user['phone_no'];
    final phone = (rawPhone != null && rawPhone.toString().isNotEmpty) ? rawPhone.toString() : 'Not Provided';
    final rawGender = user['gender'] ?? user['sex'];
    final gender = (rawGender != null && rawGender.toString().isNotEmpty) ? rawGender.toString() : 'Not Specified';

    final cardBg = isDark ? AppTheme.cyberCard : AppTheme.cardLight;
    final borderColor = isDark ? AppTheme.cyberBorder : AppTheme.borderLight;
    final textPrimary = isDark ? AppTheme.cyberTextPrimary : AppTheme.textBodyLight;
    final textMuted = isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cyberRed, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyberRed.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: isDark
                        ? AppTheme.cyberRed.withOpacity(0.15)
                        : theme.colorScheme.primary.withOpacity(0.12),
                    child: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Settings Section
          Text(
            'SECURITY & SYSTEM PREFERENCES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Auto Ingestion Switch Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? AppTheme.cyberRed : theme.colorScheme.primary).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.mark_chat_unread_outlined, color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto SMS Ingestion',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              Platform.isAndroid ? 'Real-time background shield' : 'Unsupported on iOS',
                              style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isIngestionEnabled && _hasSmsPermission,
                      activeColor: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                      onChanged: Platform.isAndroid
                          ? (val) {
                              if (val) {
                                _showEnableIngestionInfoDialog();
                              } else {
                                _showTurnOffIngestionDialog();
                              }
                            }
                          : null,
                    ),
                  ],
                ),
                if (Platform.isAndroid && !_hasSmsPermission) ...[
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    color: borderColor,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'SMS Permission required to run background shield.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.cyberRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _requestPermissions,
                        child: const Text('Grant Now'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // High Threat Notifications Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? AppTheme.cyberRed : theme.colorScheme.primary).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_active_outlined, color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Live Threat Alerts',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isNotificationsEnabled,
                      activeColor: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                      onChanged: (val) => _updateNotifications(val),
                    ),
                  ],
                ),
                if (_isNotificationsEnabled) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notification Threshold',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                      ),
                      Text(
                        '${(_notificationThreshold * 100).toStringAsFixed(0)}% Threat',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Slider(
                    value: _notificationThreshold.clamp(0.50, 1.00),
                    min: 0.50,
                    max: 1.00,
                    divisions: 10,
                    activeColor: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                    inactiveColor: isDark ? AppTheme.cyberCardSecondary : const Color(0xFFE2E8F0),
                    onChanged: (val) => _updateThreshold(val),
                  ),
                  Text(
                    'Receive live alerts for incoming SMS rated above this threat index.',
                    style: GoogleFonts.inter(fontSize: 10, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Dark Theme Toggle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.cyberRed : theme.colorScheme.primary).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Dark Mode Theme',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isDark,
                  activeColor: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                  onChanged: (val) {
                    SecureSignalApp.of(context).toggleTheme();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Legal Section
          Text(
            'LEGAL & POLICIES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => showTermsAndConditionsPage(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cyberCyan.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_outlined, color: AppTheme.cyberCyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Terms of Service & Privacy Policy',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cyberRed,
                side: const BorderSide(color: AppTheme.cyberRed, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Logout from Argus',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              onPressed: _confirmLogout,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class TipOfTheDayBannerWidget extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onDismiss;
  final VoidCallback onViewAll;

  const TipOfTheDayBannerWidget({
    super.key,
    required this.theme,
    required this.isDark,
    required this.onDismiss,
    required this.onViewAll,
  });

  @override
  State<TipOfTheDayBannerWidget> createState() => _TipOfTheDayBannerWidgetState();
}

class _TipOfTheDayBannerWidgetState extends State<TipOfTheDayBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const int _timerSeconds = 15;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _timerSeconds),
    );
    _controller.reverse(from: 1.0);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = SafetyTipsService.getTipOfTheDay();
    final cardBg = widget.isDark ? AppTheme.cyberCard : AppTheme.cardLight;
    final textPrimary = widget.isDark ? AppTheme.cyberTextPrimary : AppTheme.textBodyLight;
    final textMuted = widget.isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight;
    final accentColor = AppTheme.cyberRed;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(widget.isDark ? 0.12 : 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timer Unfilling Progress Bar at top of card
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      color: accentColor.withOpacity(0.15),
                    ),
                    FractionallySizedBox(
                      widthFactor: _controller.value.clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              Colors.redAccent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.15),
                    accentColor.withOpacity(0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: accentColor.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.security_rounded, color: accentColor, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SAFETY TIP',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Countdown seconds pill
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final secs = (_controller.value * _timerSeconds).ceil();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${secs}s',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          );
                        },
                      ),
                      InkWell(
                        onTap: widget.onViewAll,
                        child: Row(
                          children: [
                            Text(
                              'View All',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.cyberCyan,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.cyberCyan),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onDismiss,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 14, color: accentColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tip Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.summary,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: textMuted,
                    ),
                  ),
                  if (tip.actionSteps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: AppTheme.cyberGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Action: ${tip.actionSteps.first}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark ? AppTheme.cyberGreen : Colors.green.shade800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
