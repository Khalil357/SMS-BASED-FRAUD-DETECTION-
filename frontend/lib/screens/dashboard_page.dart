import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/sms_detection_service.dart';
import '../services/sms_storage_service.dart';
import '../services/sms_ingestion_service.dart';
import '../services/scan_service.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../main.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class DashboardPage extends StatefulWidget {
  final Navigate onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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

  // Logs list
  List<Map<String, dynamic>> _smsLogs = [];

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
    _scanController.dispose();
    _blockNumberController.dispose();
    _searchController.dispose();
    _smsStreamSubscription?.cancel();
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
    if (log['type'] == 'Fraud' || log['type'] == 'Spam') {
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
          backgroundColor: log['type'] == 'Fraud' ? AppTheme.red : Colors.amber.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
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

    final remoteResult = await ScanService.queryMessage(
      messageBody: text,
      source: 'MANUAL_QUERY',
    );
    final remoteData = remoteResult['success'] == true
        ? remoteResult['data'] as Map<String, dynamic>?
        : null;
    final localResult = SmsDetectionService.analyze(
      message: text,
      sender: 'Manual Scan',
    );
    final verdict = remoteData?['verdict']?.toString();
    final classification = verdict == 'FRAUD'
        ? 'Fraud'
        : verdict == 'SAFE'
            ? 'Safe'
            : localResult.classification;
    final threatLevel =
        (remoteData?['confidence'] as num?)?.toDouble() ?? localResult.threatLevel;
    final feedback = remoteData == null
        ? localResult.feedback
        : classification == 'Fraud'
            ? 'The ML service classified this message as fraud.'
            : 'The ML service classified this message as safe.';

    final logEntry = {
      'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'Manual Scan',
      'message': text,
      'type': classification,
      'time': DateTime.now().toIso8601String(),
      'threat': threatLevel,
      'matchedReasons': localResult.matchedReasons,
      'hasFeedback': false,
      'userFeedback': null,
    };

    await SmsStorageService.addLog(logEntry);

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _scanIsSafe = classification == 'Safe';
      _threatLevel = threatLevel;
      if (classification == 'Fraud') {
        _scanResult = '🚨 High Risk Alert: Potential Phishing/Fraud detected!\n\n$feedback';
      } else if (classification == 'Spam') {
        _scanResult = '⚠️ Moderate Risk: Spam content detected.\n\n$feedback';
      } else {
        _scanResult = '✅ Secure: This message is safe.\n\n$feedback';
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
        final threatVal = (log['threat'] as num).toDouble();
        final matchedReasons = List<String>.from(log['matchedReasons'] ?? []);
        
        final Color classificationColor = type == 'Safe'
            ? Colors.green
            : (type == 'Fraud' ? AppTheme.red : Colors.amber.shade700);

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
                        color: classificationColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: classificationColor.withOpacity(0.3)),
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
                        'Your feedback feeds into our system to improve the ML algorithms for Sprint 3.',
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
                                  foregroundColor: AppTheme.red,
                                  side: const BorderSide(color: AppTheme.red),
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

  void _handleLogout() {
    AuthService.currentUser = null;
    AuthService.token = null;
    widget.onNavigate(AuthPage.login);
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
            Icon(Icons.shield, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              _currentIndex == 0
                  ? 'Argus'
                  : _currentIndex == 1
                      ? 'Scan Logs'
                      : _currentIndex == 2
                          ? 'Spam Blocklist'
                          : 'Profile & Settings',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (_currentIndex == 3)
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: _handleLogout,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.block_outlined),
            activeIcon: Icon(Icons.block),
            label: 'Blocklist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
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
                            ? Colors.green.withOpacity(0.12)
                            : Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isIngestionEnabled && _hasSmsPermission
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
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
                  title: 'Threats Blocked',
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
                          ? Colors.green.withOpacity(0.08)
                          : (_threatLevel > 0.8
                              ? Colors.red.withOpacity(0.08)
                              : Colors.amber.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _scanIsSafe == true
                            ? Colors.green.withOpacity(0.2)
                            : (_threatLevel > 0.8
                                ? Colors.red.withOpacity(0.2)
                                : Colors.amber.withOpacity(0.2)),
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
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
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
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
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
                          : (type == 'Fraud' ? AppTheme.red : Colors.amber.shade700);

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
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor.withOpacity(0.2)),
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
                                      children: [
                                        Text(
                                          'Threat: ${(log['threat'] * 100).toStringAsFixed(0)}%',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right, size: 14, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
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
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'SMS messages from numbers on this blocklist will be automatically rejected and reported.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
            ),
          ),
          const SizedBox(height: 16),

          // Input Card
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

          // Numbers List
          Expanded(
            child: _blockedNumbers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
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
                            child: Icon(Icons.block, color: Colors.white, size: 16),
                          ),
                          title: Text(
                            item['number']!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('Blocked on ${item['date']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
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

  Widget _buildProfileTab(String name, Map<String, dynamic> user, ThemeData theme, bool isDark) {
    final email = user['email'] ?? 'demo@securesignal.com';
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
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
                        activeColor: theme.colorScheme.primary,
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
              child: Row(
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
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) => _updateNotifications(val),
                  ),
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
                    activeColor: theme.colorScheme.primary,
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
