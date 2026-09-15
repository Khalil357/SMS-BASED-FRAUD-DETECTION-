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
  final _scanController = TextEditingController();
  final _blockNumberController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isScanning = false;
  String? _scanResult;
  bool? _scanIsSafe;
  double _threatLevel = 0.0;
  String _searchQuery = '';
  String _filterThreat = 'All';
  String _filterTimeframe = 'All';

  bool _isIngestionEnabled = true;
  bool _isNotificationsEnabled = true;
  double _notificationThreshold = 0.80;
  bool _hasSmsPermission = false;

  List<Map<String, dynamic>> _smsLogs = [];
  String? _markingSafeLogId;
  List<Map<String, String>> _blockedNumbers = [];

  StreamSubscription? _smsStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDataAndPermissions();
    _smsStreamSubscription = SmsIngestionService.smsStream.listen((newLog) {
      if (mounted) {
        setState(() { _smsLogs.insert(0, newLog); });
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
    if (state == AppLifecycleState.resumed) { _loadStoredData(); }
  }

  Future<void> _loadDataAndPermissions() async {
    await _loadStoredData();
    await _checkPermissions();
    _checkFirstTimeIngestionPrompt();
  }

  void _checkFirstTimeIngestionPrompt() async {
    final hasSeenPrompt = await SmsStorageService.getBoolSetting('has_seen_ingestion_onboarding', false);
    if (!hasSeenPrompt && (!_hasSmsPermission || !_isIngestionEnabled)) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _showIngestionOnboardingBottomSheet(); });
    }
  }

  void _showIngestionOnboardingBottomSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(color: isDark ? AppTheme.cardDark : AppTheme.cardLight, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 48, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            Center(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.red.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.shield_outlined, color: AppTheme.red, size: 44))),
            const SizedBox(height: 16),
            Text('Activate Real-Time SMS Protection', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Argus protects you from SMS phishing, bank scams, and fake lottery rewards by automatically analyzing incoming texts in real-time.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, height: 1.4)),
            const SizedBox(height: 20),
            _buildOnboardingFeatureItem(icon: Icons.flash_on_rounded, title: 'Instant Background Ingestion', subtitle: 'Automatically scans SMS as soon as they land on your phone.', theme: theme, isDark: isDark),
            const SizedBox(height: 12),
            _buildOnboardingFeatureItem(icon: Icons.lock_outline_rounded, title: 'On-Device Privacy First', subtitle: 'Messages are analyzed locally on your device using rule-based AI.', theme: theme, isDark: isDark),
            const SizedBox(height: 12),
            _buildOnboardingFeatureItem(icon: Icons.notifications_active_outlined, title: 'Live Threat Alerts', subtitle: 'Get notified immediately if a message is identified as fraud.', theme: theme, isDark: isDark),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.security), label: const Text('Enable Auto Protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () async {
                await SmsStorageService.saveBoolSetting('has_seen_ingestion_onboarding', true);
                if (mounted) Navigator.pop(context);
                await _requestPermissions();
                await _updateIngestion(true);
              },
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () async { await SmsStorageService.saveBoolSetting('has_seen_ingestion_onboarding', true); if (mounted) Navigator.pop(context); }, child: Text('Skip for Now', style: TextStyle(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight))),
          ]),
        );
      },
    );
  }

  Widget _buildOnboardingFeatureItem({required IconData icon, required String title, required String subtitle, required ThemeData theme, required bool isDark}) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: theme.colorScheme.primary, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
      ])),
    ]);
  }

  Future<void> _loadStoredData() async {
    final logs = await SmsStorageService.getLogs();
    final blocklist = await SmsStorageService.getBlockedNumbers();
    final ingestion = await SmsStorageService.getBoolSetting(SmsStorageService.keyIngestionEnabled, true);
    final notifications = await SmsStorageService.getBoolSetting(SmsStorageService.keyNotificationsEnabled, true);
    final threshold = await SmsStorageService.getDoubleSetting(SmsStorageService.keyNotificationThreshold, 0.80);

    if (mounted) {
      setState(() {
        _smsLogs = logs;
        _blockedNumbers = blocklist;
        _isIngestionEnabled = ingestion;
        _isNotificationsEnabled = notifications;
        _notificationThreshold = threshold;
      });
    }
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
            final exactBackendMatch = backendScanId == null ? -1 : _smsLogs.indexWhere((log) => (log['scanId'] ?? log['backendId'])?.toString() == backendScanId);
            if (exactBackendMatch >= 0) continue;

            final cachedMatchWithoutId = _smsLogs.indexWhere((log) => log['message'] == msgText.toString() && ((log['scanId'] ?? log['backendId']) == null || (log['scanId'] ?? log['backendId']).toString().isEmpty));
            if (cachedMatchWithoutId >= 0 && backendScanId != null) {
              _smsLogs[cachedMatchWithoutId] = { ..._smsLogs[cachedMatchWithoutId], 'scanId': backendScanId, 'backendId': backendScanId };
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
              'scanId': backendScanId, 'backendId': backendScanId, 'sender': item['sender'] ?? 'Backend Shield Alert', 'message': msgText.toString(), 'type': type, 'time': item['scannedAt'] ?? DateTime.now().toIso8601String(), 'threat': threatLevel,
              'matchedReasons': ['Trained Model Label: ${verdict ?? (isScam == true ? 'scam' : 'safe')}', 'Threat Index: ${(threatLevel * 100).toStringAsFixed(1)}%'],
              'hasFeedback': false, 'userFeedback': null,
            };
            _smsLogs.insert(0, logEntry);
            await SmsStorageService.addLog(logEntry);
            hasNew = true;
          }
        }
        if (hasNew && mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _checkPermissions() async {
    final hasPerm = await SmsIngestionService.hasSmsPermission();
    if (mounted) setState(() { _hasSmsPermission = hasPerm; });
  }

  Future<void> _requestPermissions() async {
    final granted = await SmsIngestionService.requestSmsPermission();
    if (mounted) setState(() { _hasSmsPermission = granted; });
    if (granted) {
      await SmsIngestionService.startListening();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('SMS permissions granted!'), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS permissions denied.'), behavior: SnackBarBehavior.floating));
    }
  }

  void _showForegroundThreatSnackBar(Map<String, dynamic> log) {
    if (log['type'] == 'Fraud') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.gpp_bad, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text('Alert: Threat detected from ${log['sender']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)))]),
        backgroundColor: AppTheme.red, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () { ScaffoldMessenger.of(context).hideCurrentSnackBar(); setState(() { _currentIndex = 1; }); _showLogDetail(log); }),
      ));
    }
  }

  Future<void> _updateIngestion(bool val) async {
    await SmsStorageService.saveBoolSetting(SmsStorageService.keyIngestionEnabled, val);
    if (mounted) setState(() { _isIngestionEnabled = val; });
    if (val && _hasSmsPermission) await SmsIngestionService.startListening();
  }

  Future<void> _showTurnOffIngestionDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context, barrierColor: Colors.black.withOpacity(0.25),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent, elevation: 0, insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 28, 24, 22), decoration: BoxDecoration(color: isDark ? AppTheme.cardDark : Colors.white, borderRadius: BorderRadius.circular(42)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Turn Off Automatic\nIngestion', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B), height: 1.3)),
            const SizedBox(height: 10),
            Text('Are you sure you want\nto turn off automatic ingestion', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w400, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, height: 1.5)),
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(onTap: () => Navigator.of(ctx).pop(false), child: Container(width: 103, height: 34, decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(34)), alignment: Alignment.center, child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
              const SizedBox(width: 19),
              GestureDetector(onTap: () => Navigator.of(ctx).pop(true), child: Container(width: 103, height: 34, decoration: BoxDecoration(color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight, borderRadius: BorderRadius.circular(34)), alignment: Alignment.center, child: Text('Turn Off', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)))),
            ]),
          ]),
        ),
      ),
    );
    if (confirmed == true) await _updateIngestion(false);
  }

  Future<void> _updateNotifications(bool val) async {
    await SmsStorageService.saveBoolSetting(SmsStorageService.keyNotificationsEnabled, val);
    if (mounted) setState(() { _isNotificationsEnabled = val; });
  }

  void _confirmLogout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const Icon(Icons.logout_rounded, color: AppTheme.red), const SizedBox(width: 10), Text('Confirm Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18))]),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, fontWeight: FontWeight.w600))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () { Navigator.pop(context); _handleLogout(); }, child: const Text('Yes, Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) widget.onNavigate(AuthPage.login);
  }

  int get _scannedCount => _smsLogs.length;
  int get _threatsCount => _smsLogs.where((l) => l['type'] == 'Fraud').length;
  double get _safetyIndex => _scannedCount == 0 ? 100.0 : (_smsLogs.where((l) => l['type'] == 'Safe').length / _scannedCount) * 100.0;

  List<Map<String, dynamic>> get _filteredLogs {
    return _smsLogs.where((log) {
      final message = (log['message'] as String).toLowerCase();
      final sender = (log['sender'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty && !message.contains(query) && !sender.contains(query)) return false;
      if (_filterThreat != 'All' && log['type'] != _filterThreat) return false;
      return true;
    }).toList();
  }

  String _formatLogTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}';
    } catch (_) { return timeStr; }
  }

  void _handleManualScan() async {
    final text = _scanController.text.trim();
    if (text.isEmpty) return;
    setState(() { _isScanning = true; _scanResult = null; });
    final backendResponse = await AuthService.submitScan(sender: 'Manual Scan', messageBody: text, source: 'MANUAL_QUERY');
    SmsAnalysisResult result;
    if (backendResponse['success'] == true && backendResponse['data'] != null) {
      result = SmsDetectionService.parseBackendResult(backendData: backendResponse['data'] as Map<String, dynamic>, originalMessage: text, sender: 'Manual Scan');
    } else {
      result = SmsDetectionService.analyze(message: text, sender: 'Manual Scan');
    }
    final logEntry = {
      'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      'scanId': backendResponse['data']?['scanId']?.toString(),
      'sender': 'Manual Scan', 'message': text, 'type': result.classification, 'time': DateTime.now().toIso8601String(), 'threat': result.threatLevel, 'matchedReasons': result.matchedReasons,
    };
    await SmsStorageService.addLog(logEntry);
    if (mounted) {
      setState(() { _isScanning = false; _scanIsSafe = result.classification == 'Safe'; _threatLevel = result.threatLevel;
        if (result.classification == 'Fraud') {
          Navigator.push(context, MaterialPageRoute(builder: (c) => ScamDetectedScreen(sender: 'Manual Scan', message: text, reasons: result.matchedReasons, onBlock: () { Navigator.pop(context); _blockNumberController.text = 'Scam Sender'; _handleAddBlockedNumber(reason: 'Manual scan result'); }, onDismiss: () => Navigator.pop(context))));
        }
        _smsLogs.insert(0, logEntry);
      });
    }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade600, behavior: SnackBarBehavior.floating));
  }

  void _showLogDetail(Map<String, dynamic> log) {
    if (log['type'] == 'Fraud') {
      Navigator.push(context, MaterialPageRoute(builder: (c) => ScamDetectedScreen(sender: log['sender'] ?? 'Unknown', message: log['message'] ?? '', reasons: List<String>.from(log['matchedReasons'] ?? []), onBlock: () { Navigator.pop(context); _blockNumberController.text = log['sender'] ?? 'Unknown'; _handleAddBlockedNumber(reason: 'Scam detected'); }, onDismiss: () => Navigator.pop(context))));
      return;
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final type = log['type'] as String;
        final rawThreat = (log['threat'] as num).toDouble();
        final threatVal = (type == 'Safe' && rawThreat > 0.50) ? (1.0 - rawThreat) : rawThreat;
        final Color classificationColor = type == 'Safe' ? Colors.green : AppTheme.red;
        return Container(
          decoration: BoxDecoration(color: isDark ? AppTheme.cardDark : AppTheme.cardLight, borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Analysis Detail', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
              const Divider(),
              Text('Sender: ${log['sender']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)), child: Text(log['message'], style: const TextStyle(fontSize: 14))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Classification: $type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: classificationColor)), Text('Threat Index: ${(threatVal * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13))]),
                Icon(type == 'Safe' ? Icons.gpp_good : Icons.gpp_bad, color: classificationColor, size: 28),
              ]),
              const SizedBox(height: 28),
              CustomButton(text: 'Dismiss', onPressed: () => Navigator.pop(context)),
            ]),
          ),
        );
      },
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
        leading: _currentIndex == 4 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentIndex = 0)) : null,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset('assets/images/sms_fraud_inapp_icon.png', width: 28, height: 28, errorBuilder: (c, e, s) => Icon(Icons.shield, color: theme.colorScheme.primary, size: 28))),
          const SizedBox(width: 8),
          Text(_currentIndex == 0 ? 'Argus' : _currentIndex == 1 ? 'Scan Logs' : _currentIndex == 2 ? 'Blocklist' : _currentIndex == 3 ? 'Safety Tips' : 'Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.amber : theme.colorScheme.primary), onPressed: () => SecureSignalApp.of(context).toggleTheme()),
          Padding(padding: const EdgeInsets.only(right: 12.0), child: InkWell(onTap: () => setState(() => _currentIndex = 4), child: CircleAvatar(radius: 15, backgroundColor: theme.colorScheme.primary.withOpacity(0.15), child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))))),
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
        if (badgeCount > 0 && index == 1) Positioned(top: -4, right: -6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppTheme.red, shape: BoxShape.circle), child: Text(badgeCount > 9 ? '9+' : '$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
      ]),
      if (isSelected) ...[const SizedBox(width: 6), Text(label, style: GoogleFonts.inter(color: activeColor, fontWeight: FontWeight.w700, fontSize: 12))],
    ])));
  }

  Widget _buildHomeTab(String name, ThemeData theme, bool isDark) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildTipOfTheDayBanner(theme, isDark),
      Container(padding: const EdgeInsets.all(20.0), decoration: BoxDecoration(gradient: isDark ? AppTheme.heroBgGradientDark : AppTheme.heroBgGradientLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome,', style: theme.textTheme.bodyMedium), Text(name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))])),
        Icon(_isIngestionEnabled ? Icons.gpp_good : Icons.gpp_maybe, color: _isIngestionEnabled ? Colors.green : Colors.orange),
      ])),
      const SizedBox(height: 20),
      InteractiveThreatChart(logs: _smsLogs),
      const SizedBox(height: 24),
      _buildMetricCard(title: 'Safety Index', value: '${_safetyIndex.toStringAsFixed(1)}%', icon: Icons.insights, iconColor: Colors.teal, theme: theme, isDark: isDark),
      const SizedBox(height: 24),
      CustomTextField(controller: _scanController, labelText: 'Paste SMS Text', hintText: 'Check for scams...', prefixIcon: Icons.sms_outlined),
      const SizedBox(height: 16),
      CustomButton(text: 'Analyze SMS', isLoading: _isScanning, onPressed: _handleManualScan),
    ]));
  }

  Widget _buildLogsTab(ThemeData theme, bool isDark) {
    final filtered = _filteredLogs;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))))),
      Expanded(child: RefreshIndicator(onRefresh: _loadStoredData, child: filtered.isEmpty ? const Center(child: Text('No logs found.')) : ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) {
        final log = filtered[i];
        final type = log['type'];
        final statusColor = type == 'Safe' ? Colors.green : (type == 'Fraud' ? AppTheme.red : Colors.amber.shade700);
        return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: ListTile(onTap: () => _showLogDetail(log), title: Text('From: ${log['sender']}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(log['message'], maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Text(type, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))));
      }))),
    ]);
  }

  Widget _buildBlocklistTab(ThemeData theme, bool isDark) {
    return BlockedNumbersScreen(blockedNumbers: _blockedNumbers, onUnblock: _handleRemoveBlockedNumber, onBack: () => setState(() => _currentIndex = 0));
  }

  Widget _buildProfileTab(String name, Map<String, dynamic> user, ThemeData theme, bool isDark) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildInfoRow(Icons.phone_android, 'Phone', user['phone_number'] ?? 'N/A', theme, isDark),
      const SizedBox(height: 12),
      Card(child: SwitchListTile(title: const Text('Auto Ingestion'), value: _isIngestionEnabled, onChanged: (v) => v ? _updateIngestion(true) : _showTurnOffIngestionDialog())),
      const SizedBox(height: 30),
      CustomButton(text: 'Logout', type: ButtonType.ghost, icon: Icons.logout, onPressed: _confirmLogout),
    ]));
  }

  Widget _buildInfoRow(IconData icon, String title, String value, ThemeData theme, bool isDark) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [Icon(icon, color: theme.colorScheme.primary), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))])])));
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color iconColor, required ThemeData theme, required bool isDark, String? subtitle}) {
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]))]));
  }

  Widget _buildTipOfTheDayBanner(ThemeData theme, bool isDark) {
    final tip = SafetyTipsService.getTipOfTheDay();
    return Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? AppTheme.cardDark : AppTheme.cardLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.shade700.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.lightbulb_rounded, color: Colors.amber.shade700, size: 20), const SizedBox(width: 8), const Text('SAFETY TIP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]), TextButton(onPressed: () => setState(() => _currentIndex = 3), child: const Text('View All'))]),
      Text(tip.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(tip.summary, style: const TextStyle(fontSize: 12)),
    ]));
  }
}
