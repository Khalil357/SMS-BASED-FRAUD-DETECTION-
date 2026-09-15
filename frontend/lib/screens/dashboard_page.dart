import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/sms_detection_service.dart';
import '../services/sms_storage_service.dart';
import '../services/sms_ingestion_service.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../main.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/interactive_threat_chart.dart';
import '../widgets/security_illustrations.dart';
import '../services/safety_tips_service.dart';
import '../widgets/scam_detected_card.dart';
import 'safety_tips_page.dart';
import 'terms_and_conditions_page.dart';
import 'blocked_numbers_screen.dart';

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
  double _notificationThreshold = 0.80;
  bool _hasSmsPermission = false;

  // Logs list
  List<Map<String, dynamic>> _smsLogs = [];

  // Tracks which log id is currently being marked-as-safe (backend call in flight)
  String? _markingSafeLogId;

  // Blocklist state
  List<Map<String, String>> _blockedNumbers = [];

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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanController.dispose();
    _blockNumberController.dispose();
    _searchController.dispose();
    _smsStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStoredData();
    }
  }

  Future<void> _loadDataAndPermissions() async {
    await _loadStoredData();
    await _checkPermissions();
    _checkFirstTimeIngestionPrompt();
  }

  void _checkFirstTimeIngestionPrompt() async {
    final hasSeenPrompt = await SmsStorageService.getBoolSetting('has_seen_ingestion_onboarding', false);
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
                subtitle: 'Automatically scans SMS as soon as they land on your phone.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildOnboardingFeatureItem(
                icon: Icons.lock_outline_rounded,
                title: 'On-Device Privacy First',
                subtitle: 'Messages are analyzed locally on your device using rule-based AI.',
                theme: theme,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildOnboardingFeatureItem(
                icon: Icons.notifications_active_outlined,
                title: 'Live Threat Alerts',
                subtitle: 'Get notified immediately if a message is identified as fraud.',
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
                  await SmsStorageService.saveBoolSetting('has_seen_ingestion_onboarding', true);
                  if (mounted) Navigator.pop(context);
                  await _requestPermissions();
                  await _updateIngestion(true);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await SmsStorageService.saveBoolSetting('has_seen_ingestion_onboarding', true);
                  if (mounted) Navigator.pop(context);
                },
                child: Text(
                  'Skip for Now',
                  style: TextStyle(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
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
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
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

  Future<void> _loadStoredData() async {
    final logs = await SmsStorageService.getLogs();
    final blocklist = await SmsStorageService.getBlockedNumbers();
    final ingestion = await SmsStorageService.getBoolSetting(
        SmsStorageService.keyIngestionEnabled, true);
    final notifications = await SmsStorageService.getBoolSetting(
        SmsStorageService.keyNotificationsEnabled, true);
    final threshold = await SmsStorageService.getDoubleSetting(
        SmsStorageService.keyNotificationThreshold, 0.80);

    setState(() {
      _smsLogs = logs;
      _blockedNumbers = blocklist;
      _isIngestionEnabled = ingestion;
      _isNotificationsEnabled = notifications;
      _notificationThreshold = threshold;
    });

    _fetchBackendFraudScans();
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

            final backendScanId = item['scanId']?.toString();
            final exactBackendMatch = backendScanId == null
                ? -1
                : _smsLogs.indexWhere((log) =>
                    (log['scanId'] ?? log['backendId'])?.toString() ==
                    backendScanId);
            if (exactBackendMatch >= 0) continue;

            final cachedMatchWithoutId = _smsLogs.indexWhere((log) =>
                log['message'] == msgText.toString() &&
                ((log['scanId'] ?? log['backendId']) == null ||
                    (log['scanId'] ?? log['backendId']).toString().isEmpty));
            
            if (cachedMatchWithoutId >= 0 && backendScanId != null) {
              _smsLogs[cachedMatchWithoutId] = {
                ..._smsLogs[cachedMatchWithoutId],
                'scanId': backendScanId,
                'backendId': backendScanId,
              };
              await SmsStorageService.saveLogs(_smsLogs);
              hasNew = true;
              continue;
            }

            final isScam = item['is_scam'] ?? item['isScam'] ?? true;
            final verdict = item['verdict']?.toString();
            final conf = (item['confidence'] as num?)?.toDouble() ?? 0.95;
            final type = (isScam == true) ? 'Fraud' : ((verdict == 'spam') ? 'Spam' : 'Safe');
            final threatLevel = (type == 'Safe') ? (1.0 - conf).clamp(0.0, 1.0) : conf.clamp(0.0, 1.0);

            final logEntry = {
              'id': backendScanId ?? 'backend_fraud_${DateTime.now().millisecondsSinceEpoch}_${item.hashCode}',
              'scanId': backendScanId,
              'backendId': backendScanId,
              'sender': item['sender'] ?? 'Backend Shield Alert',
              'message': msgText.toString(),
              'type': type,
              'time': item['scannedAt'] ?? DateTime.now().toIso8601String(),
              'threat': threatLevel,
              'matchedReasons': [
                'Trained Model Label: ${verdict ?? (isScam == true ? 'scam' : 'safe')}',
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

  Future<void> _showTurnOffIngestionDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.25),
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
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
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
                    color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        width: 103,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(34),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 19),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        width: 103,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(34),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Turn Off',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
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
    await SmsStorageService.saveBoolSetting(SmsStorageService.keyNotificationsEnabled, val);
    setState(() {
      _isNotificationsEnabled = val;
    });
  }

  Future<void> _updateThreshold(double val) async {
    await SmsStorageService.saveDoubleSetting(SmsStorageService.keyNotificationThreshold, val);
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
              backgroundColor: AppTheme.red,
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

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      widget.onNavigate(AuthPage.login);
    }
  }

  int get _scannedCount => _smsLogs.length;
  int get _threatsCount => _smsLogs.where((l) => l['type'] == 'Fraud').length;

  double get _safetyIndex {
    if (_scannedCount == 0) return 100.0;
    final safeCount = _smsLogs.where((l) => l['type'] == 'Safe').length;
    return (safeCount / _scannedCount) * 100.0;
  }

  List<Map<String, dynamic>> get _filteredLogs {
    return _smsLogs.where((log) {
      final message = (log['message'] as String).toLowerCase();
      final sender = (log['sender'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty && !message.contains(query) && !sender.contains(query)) return false;

      final type = log['type'] as String;
      if (_filterThreat != 'All' && type != _filterThreat) return false;

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
        } catch (_) { return _filterTimeframe == 'All'; }
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
    } catch (_) { return timeStr; }
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
      result = SmsDetectionService.analyze(message: text, sender: 'Manual Scan');
    }

    final logEntry = {
      'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      'backendId': backendResponse['data'] is Map<String, dynamic> ? (backendResponse['data'] as Map<String, dynamic>)['scanId']?.toString() : null,
      'scanId': backendResponse['data'] is Map<String, dynamic> ? (backendResponse['data'] as Map<String, dynamic>)['scanId']?.toString() : null,
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

      if (result.classification == 'Fraud') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScamDetectedScreen(
              sender: 'Manual Scan',
              message: text,
              reasons: result.matchedReasons,
              onBlock: () {
                Navigator.pop(context);
                _blockNumberController.text = 'Scam Sender';
                _handleAddBlockedNumber(reason: 'Manual scan result');
              },
              onDismiss: () => Navigator.pop(context),
            ),
          ),
        );
      }
      _smsLogs.insert(0, logEntry);
    });
  }

  Future<void> _markAsSafe(Map<String, dynamic> log) async {
    final logId = log['id']?.toString() ?? '';
    final backendId = (log['scanId'] ?? log['backendId'])?.toString();

    if (backendId == null || backendId.isEmpty) {
      _showMessageActionSnackBar('Missing backend scan ID.', isError: true);
      return;
    }

    setState(() { _markingSafeLogId = logId; });
    final result = await AuthService.deleteFraudScan(id: backendId);
    if (!mounted) return;
    setState(() { _markingSafeLogId = null; });

    if (result['success'] != true) {
      _showMessageActionSnackBar(result['message'] ?? 'Failed to update server.', isError: true);
      return;
    }

    await SmsStorageService.removeLog(logId);
    final logs = await SmsStorageService.getLogs();
    if (mounted) {
      setState(() { _smsLogs = logs; });
      Navigator.pop(context);
      _showMessageActionSnackBar('Message marked safe and removed from fraud records.');
    }
  }

  Future<void> _markAsFraud(Map<String, dynamic> log) async {
    final logId = log['id']?.toString() ?? '';
    await SmsStorageService.submitFeedback(logId: logId, feedbackType: 'Fraud');
    final logs = await SmsStorageService.getLogs();
    if (!mounted) return;

    setState(() { _smsLogs = logs; });
    Navigator.pop(context);

    final result = await AuthService.addFraudScan(
      sender: log['sender']?.toString() ?? '',
      messageBody: log['message']?.toString() ?? '',
    );

    if (result['success'] == true) {
      _showMessageActionSnackBar(result['message']?.toString() ?? 'Response updated.');
    } else {
      _showMessageActionSnackBar('Saved locally. Server update failed.', isError: true);
    }
  }

  void _showLogDetail(Map<String, dynamic> log) {
    if (log['type'] == 'Fraud') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScamDetectedScreen(
            sender: log['sender'] ?? 'Unknown',
            message: log['message'] ?? '',
            reasons: List<String>.from(log['matchedReasons'] ?? []),
            onBlock: () {
              Navigator.pop(context);
              _blockNumberController.text = log['sender'] ?? 'Unknown';
              _handleAddBlockedNumber(reason: 'Scam detected');
            },
            onDismiss: () => Navigator.pop(context),
          ),
        ),
      );
      return;
    }

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
        final Color classificationColor = type == 'Safe' ? Colors.green : AppTheme.red;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('SMS Threat Analysis', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ]),
                const Divider(),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Sender: ${log['sender']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(_formatLogTime(log['time']), style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, fontSize: 12)),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(log['message'], style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, fontSize: 14)),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Classification: $type', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: classificationColor)),
                    const SizedBox(height: 4),
                    Text('Threat Index: ${(threatVal * 100).toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: classificationColor.withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: classificationColor.withOpacity(0.3))),
                    child: Icon(type == 'Safe' ? Icons.gpp_good : Icons.gpp_bad, color: classificationColor, size: 28),
                  ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: threatVal, minHeight: 8, backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation<Color>(classificationColor))),
                const SizedBox(height: 24),
                Text('ANALYSIS DETECTOR CHECKS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
                const SizedBox(height: 10),
                if (matchedReasons.isEmpty) Text('No threat triggers found.', style: theme.textTheme.bodyMedium)
                else ...matchedReasons.map((reason) => Padding(padding: const EdgeInsets.only(bottom: 6.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(type == 'Safe' ? Icons.check_circle : Icons.error, size: 16, color: classificationColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(reason, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.3))),
                ]))),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: classificationColor.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: classificationColor.withOpacity(0.1))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Is this classification incorrect?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('Help train the Argus ML Threat Engine by reporting misclassified messages in real-time.', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, fontSize: 11), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (_markingSafeLogId == log['id']?.toString()) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))))
                    else Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (type == 'Fraud') ...[
                        OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center), icon: const Icon(Icons.check, size: 16), label: const Text('Mark Safe (FP)', style: TextStyle(fontSize: 12)), onPressed: () => _confirmMarkAsSafe(log)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: AppTheme.red, side: const BorderSide(color: AppTheme.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center), icon: const Icon(Icons.flag_outlined, size: 16), label: const Text('Report', style: TextStyle(fontSize: 12)), onPressed: () => _reportToAuthorities(log)),
                      ],
                      if (type == 'Safe') OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: AppTheme.red, side: const BorderSide(color: AppTheme.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center), icon: const Icon(Icons.gpp_bad, size: 16), label: const Text('Mark Fraud', style: TextStyle(fontSize: 12)), onPressed: () => _confirmMarkAsFraud(log)),
                    ]),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleAddBlockedNumber({String? reason}) {
    final number = _blockNumberController.text.trim();
    if (number.isEmpty) return;
    setState(() {
      _blockedNumbers.insert(0, {'number': number, 'date': 'today', 'reason': reason ?? 'Manual block'});
      _blockNumberController.clear();
    });
    SmsStorageService.saveBlocklist(_blockedNumbers);
    _showMessageActionSnackBar('$number added to blocklist.');
  }

  void _handleRemoveBlockedNumber(int index) {
    final number = _blockedNumbers[index]['number'];
    setState(() { _blockedNumbers.removeAt(index); });
    SmsStorageService.saveBlocklist(_blockedNumbers);
    _showMessageActionSnackBar('$number removed from blocklist.');
  }

  void _showMessageActionSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade600, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Future<void> _reportToAuthorities(Map<String, dynamic> log) async {
    final fraudsterNumber = log['sender']?.toString().trim() ?? '';
    if (fraudsterNumber.isEmpty || fraudsterNumber == 'Unknown') {
      _showMessageActionSnackBar('Unable to find a phone number for this message.', isError: true);
      return;
    }
    try {
      final launched = await launchUrl(Uri(scheme: 'sms', path: '15040', queryParameters: {'body': 'Fraud $fraudsterNumber'}), mode: LaunchMode.externalApplication);
      if (!launched) _showMessageActionSnackBar('Unable to open messaging app.', isError: true);
    } catch (_) { _showMessageActionSnackBar('Unable to open messaging app.', isError: true); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? 'Demo User';

    return Scaffold(
      appBar: AppBar(
        leading: _currentIndex == 4 ? IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => setState(() => _currentIndex = 0)) : null,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset('assets/images/sms_fraud_inapp_icon.png', width: 28, height: 28, errorBuilder: (c, e, s) => Icon(Icons.shield, color: theme.colorScheme.primary, size: 28))),
          const SizedBox(width: 8),
          Text(_currentIndex == 0 ? 'Argus' : _currentIndex == 1 ? 'Scan Logs' : _currentIndex == 2 ? 'Blocklist' : _currentIndex == 3 ? 'Safety Tips' : 'Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.amber : theme.colorScheme.primary), onPressed: () => SecureSignalApp.of(context).toggleTheme()),
          Padding(padding: const EdgeInsets.only(right: 12.0), child: InkWell(onTap: () => setState(() => _currentIndex = 4), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _currentIndex == 4 ? theme.colorScheme.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: 2)), child: CircleAvatar(radius: 15, backgroundColor: theme.colorScheme.primary.withOpacity(0.15), child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: theme.colorScheme.primary)))))),
        ],
      ),
      body: switch (_currentIndex) {
        0 => _buildHomeTab(fullName, theme, isDark),
        1 => _buildLogsTab(theme, isDark),
        2 => _buildBlocklistTab(theme, isDark),
        3 => const SafetyTipsPage(),
        4 => _buildProfileTab(fullName, user, theme, isDark),
        _ => const SizedBox(),
      },
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))], border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildNavItem(index: 0, icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Home', theme: theme, isDark: isDark),
          _buildNavItem(index: 1, icon: Icons.shield_outlined, activeIcon: Icons.shield_rounded, label: 'Scan', badgeCount: _threatsCount, theme: theme, isDark: isDark),
          _buildNavItem(index: 2, icon: Icons.do_not_disturb_on_outlined, activeIcon: Icons.do_not_disturb_on_rounded, label: 'Blocked', theme: theme, isDark: isDark),
          _buildNavItem(index: 3, icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', theme: theme, isDark: isDark),
        ]),
      ),
    );
  }

  Widget _buildNavItem({required int index, required IconData icon, required IconData activeIcon, required String label, int badgeCount = 0, required ThemeData theme, required bool isDark}) {
    final isSelected = _currentIndex == index;
    final activeColor = theme.colorScheme.primary;
    return GestureDetector(onTap: () => setState(() => _currentIndex = index), behavior: HitTestBehavior.opaque, child: AnimatedContainer(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, padding: EdgeInsets.symmetric(horizontal: isSelected ? 14 : 10, vertical: 8), decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(isDark ? 0.2 : 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Icon(isSelected ? activeIcon : icon, color: isSelected ? activeColor : (isDark ? AppTheme.subtleDark : AppTheme.subtleLight), size: 22),
        if (badgeCount > 0 && index == 1) Positioned(top: -4, right: -6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppTheme.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 14, minHeight: 14), child: Text(badgeCount > 9 ? '9+' : '$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
      ]),
      if (isSelected) ...[const SizedBox(width: 6), Text(label, style: GoogleFonts.inter(color: activeColor, fontWeight: FontWeight.w700, fontSize: 12))],
    ])));
  }

  Widget _buildHomeTab(String name, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildTipOfTheDayBanner(theme, isDark),
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(gradient: isDark ? AppTheme.heroBgGradientDark : AppTheme.heroBgGradientLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome back,', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
              const SizedBox(height: 4),
              Text(name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _isIngestionEnabled && _hasSmsPermission ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _isIngestionEnabled && _hasSmsPermission ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isIngestionEnabled && _hasSmsPermission ? Icons.gpp_good : Icons.gpp_maybe, color: _isIngestionEnabled && _hasSmsPermission ? Colors.green : Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text(_isIngestionEnabled && _hasSmsPermission ? 'Active' : 'Inactive', style: GoogleFonts.inter(color: _isIngestionEnabled && _hasSmsPermission ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        InteractiveThreatChart(logs: _smsLogs),
        const SizedBox(height: 24),
        _buildMetricCard(title: 'System Safety Index', value: '${_safetyIndex.toStringAsFixed(1)}% Secure', icon: Icons.insights, iconColor: Colors.teal, theme: theme, isDark: isDark, subtitle: _safetyIndex > 90 ? 'Outstanding' : 'Warning'),
        const SizedBox(height: 24),
        Text('Analyze SMS Content', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20.0), decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), boxShadow: AppTheme.cardShadow(isDark)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CustomTextField(controller: _scanController, labelText: 'Suspicious SMS Text', hintText: 'e.g. You have won a parcel...', prefixIcon: Icons.sms_outlined, keyboardType: TextInputType.multiline, textInputAction: TextInputAction.done),
            const SizedBox(height: 16),
            CustomButton(text: 'Analyze SMS', isLoading: _isScanning, icon: Icons.security_outlined, onPressed: _handleManualScan),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLogsTab(ThemeData theme, bool isDark) {
    final filtered = _filteredLogs;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: [
        TextField(controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search), suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
        const SizedBox(height: 12),
        Expanded(child: RefreshIndicator(onRefresh: _loadStoredData, child: filtered.isEmpty ? Center(child: Text('No logs found.')) : ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) {
          final log = filtered[i];
          final type = log['type'];
          final statusColor = type == 'Safe' ? Colors.green : (type == 'Fraud' ? AppTheme.red : Colors.amber.shade700);
          return Card(margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () => _showLogDetail(log), borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Sender: ${log['sender']}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.2))), child: Text(type, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 10),
            Text(log['message'], maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(_formatLogTime(log['time']), style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, fontSize: 11)),
          ]))));
        }))),
      ]),
    );
  }

  Widget _buildBlocklistTab(ThemeData theme, bool isDark) {
    return BlockedNumbersScreen(blockedNumbers: _blockedNumbers, onUnblock: _handleRemoveBlockedNumber, onBack: () => setState(() => _currentIndex = 0));
  }

  Widget _buildProfileTab(String name, Map<String, dynamic> user, ThemeData theme, bool isDark) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CircleAvatar(radius: 50, backgroundColor: theme.colorScheme.primary.withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: theme.colorScheme.primary))),
      const SizedBox(height: 16),
      Center(child: Text(name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
      const SizedBox(height: 32),
      _buildInfoRow(Icons.phone_android, 'Phone Number', user['phone_number'] ?? 'N/A', theme, isDark),
      const SizedBox(height: 24),
      Text('SETTINGS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
      Card(child: SwitchListTile(title: Text('Auto Ingestion', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), value: _isIngestionEnabled, onChanged: (v) => v ? _updateIngestion(true) : _showTurnOffIngestionDialog())),
      Card(child: SwitchListTile(title: Text('Threat Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), value: _isNotificationsEnabled, onChanged: _updateNotifications)),
      const SizedBox(height: 30),
      CustomButton(text: 'Logout', type: ButtonType.ghost, icon: Icons.logout, onPressed: _confirmLogout),
    ]));
  }

  Widget _buildInfoRow(IconData icon, String title, String value, ThemeData theme, bool isDark) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0), child: Row(children: [
      Icon(icon, color: theme.colorScheme.primary, size: 22), const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    ])));
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color iconColor, required ThemeData theme, required bool isDark, String? subtitle}) {
    return Container(padding: const EdgeInsets.all(18.0), decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))), child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, fontSize: 12)),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
        if (subtitle != null) Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.teal.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
      ])),
    ]));
  }

  Widget _buildTipOfTheDayBanner(ThemeData theme, bool isDark) {
    final tip = SafetyTipsService.getTipOfTheDay();
    return Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? AppTheme.cardDark : AppTheme.cardLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.shade700.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Icon(Icons.lightbulb_rounded, color: Colors.amber.shade700, size: 20), const SizedBox(width: 8), Text('SAFETY TIP', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.amber.shade800))]),
        TextButton(onPressed: () => setState(() => _currentIndex = 3), child: Text('View All', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      Text(tip.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(tip.summary, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.3, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
    ]));
  }
}
