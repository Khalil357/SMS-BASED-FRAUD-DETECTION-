import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/sms_history_scan_service.dart';
import '../services/sms_ingestion_service.dart';
import '../services/sms_storage_service.dart';
import '../widgets/scam_detected_card.dart';

class HistoryScanScreen extends StatefulWidget {
  const HistoryScanScreen({super.key});

  @override
  State<HistoryScanScreen> createState() => _HistoryScanScreenState();
}

class _HistoryScanScreenState extends State<HistoryScanScreen> {
  bool _isScanning = true;
  bool _permissionDenied = false;
  int _scanned = 0;
  int _fraudFound = 0;
  String _errorMessage = '';
  HistoryScanSummary? _summary;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _permissionDenied = false;
      _errorMessage = '';
      _scanned = 0;
      _fraudFound = 0;
      _summary = null;
    });

    final hasPerm = await SmsIngestionService.hasSmsPermission();
    if (!hasPerm) {
      final granted = await SmsIngestionService.requestSmsPermission();
      if (!granted) {
        if (mounted) {
          setState(() { _isScanning = false; _permissionDenied = true; });
        }
        return;
      }
    }
    if (!mounted) return;

    final summary = await SmsHistoryScanService.scanInbox(onProgress: (scanned, fraud) {
      if (mounted) setState(() { _scanned = scanned; _fraudFound = fraud; });
    });

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _summary = summary;
      _scanned = summary.newScanned;
      _fraudFound = summary.fraudCount;
      _errorMessage = summary.error ?? '';
    });
  }

  Future<void> _openResultDetails(Map<String, dynamic> log) async {
    if (log['type'] == 'Fraud') {
      final sender = log['sender'] ?? 'Unknown';
      Navigator.push(context, MaterialPageRoute(builder: (c) => ScamDetectedScreen(
        sender: sender,
        message: log['message'] ?? '',
        reasons: List<String>.from(log['matchedReasons'] ?? []),
        onBlock: () {
          Navigator.pop(context);
          _addToBlocklist(sender);
        },
        onDismiss: () => Navigator.pop(context),
      )));
      return;
    }
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
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Message Analysis', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const Divider(),
              Text('Sender: ${log['sender']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: Text(log['message'] ?? '', style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Classification: ${log['type']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green)),
                  Text('Threat Index: ${((log['threat'] as num).toDouble() * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13)),
                ]),
                const Icon(Icons.gpp_good, color: Colors.green, size: 28),
              ]),
              const SizedBox(height: 28),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _addToBlocklist(String number) async {
    final list = await SmsStorageService.getBlockedNumbers();
    final exists = list.any((item) => item['number'] == number);
    if (!exists) {
      list.insert(0, {'number': number, 'date': 'today', 'reason': 'Previous messages scan'});
      await SmsStorageService.saveBlocklist(list);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(exists ? '$number is already blocked.' : '$number added to blocklist.'),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text('Scan Previous Messages', style: GoogleFonts.inter(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: _isScanning
            ? _buildScanningView(theme, isDark)
            : _permissionDenied
                ? _buildPermissionDeniedView(theme, isDark)
                : (_errorMessage.isNotEmpty && _summary == null)
                    ? _buildErrorView(theme, isDark)
                    : _buildResultsView(theme, isDark),
      ),
    );
  }

  Widget _buildScanningView(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 96, height: 96, decoration: BoxDecoration(color: AppTheme.red.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.sms_outlined, color: AppTheme.red, size: 44)),
        const SizedBox(height: 28),
        Text('Scanning your messages', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Analyzing your SMS inbox for phishing, bank impersonation and mobile money scams.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, height: 1.5)),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: AppTheme.red),
        const SizedBox(height: 20),
        Text('${_scanned} messages analyzed', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
        if (_fraudFound > 0) ...[
          const SizedBox(height: 6),
          Text('$_fraudFound potential threats found', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.red, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  Widget _buildPermissionDeniedView(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 96, height: 96, decoration: BoxDecoration(color: AppTheme.amber.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.sms_failed_outlined, color: AppTheme.amber, size: 44)),
        const SizedBox(height: 28),
        Text('SMS permission required', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Argus needs access to your messages to scan them for scams. Grant the permission and try again.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, height: 1.5)),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Grant Permission', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () async {
            final granted = await SmsIngestionService.requestSmsPermission();
            if (granted && mounted) _startScan();
          },
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
      ]),
    );
  }

  Widget _buildErrorView(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 96, height: 96, decoration: BoxDecoration(color: AppTheme.red.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: AppTheme.red, size: 44)),
        const SizedBox(height: 28),
        Text('Scan failed', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(_errorMessage, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, height: 1.5)),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _startScan,
        ),
      ]),
    );
  }

  Widget _buildResultsView(ThemeData theme, bool isDark) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();
    final results = summary.logs;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scan complete', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(summary.error ?? 'Argus analyzed ${summary.totalInbox} message(s) from your inbox. ${summary.skipped} already known.', style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight, height: 1.4)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildSummaryCell(label: 'Scanned', value: '${summary.newScanned}', color: theme.colorScheme.primary, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCell(label: 'Fraud', value: '${summary.fraudCount}', color: AppTheme.red, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCell(label: 'Safe', value: '${summary.safeCount}', color: AppTheme.emerald, isDark: isDark)),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(results.isEmpty
            ? 'No new messages to analyze. All matched messages are already in your scan history.'
            : 'Tap a message to inspect the analysis.', style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: results.isEmpty
            ? const Center(child: Text('No new messages found.'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final log = results[index];
                  final type = log['type'];
                  final statusColor = type == 'Safe' ? Colors.green : AppTheme.red;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _openResultDetails(log),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(type == 'Safe' ? Icons.gpp_good : Icons.gpp_bad, color: statusColor, size: 20),
                      ),
                      title: Text('${log['sender']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(log['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(type ?? '', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _buildSummaryCell({required String label, required String value, required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight)),
      ]),
    );
  }
}