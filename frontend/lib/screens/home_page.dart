import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/scan_service.dart';
import '../services/token_storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  final _historyKey = GlobalKey<_ScanHistoryPageState>();

  Future<void> _logout() async {
    await TokenStorage.clear();
    widget.onLogout();
  }

  void _onTabSelected(int i) {
    setState(() => _tab = i);
    if (i == 1) {
      _historyKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Check message' : 'Scan history'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const _QueryTab(),
          ScanHistoryPage(key: _historyKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Check',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class _QueryTab extends StatefulWidget {
  const _QueryTab();

  @override
  State<_QueryTab> createState() => _QueryTabState();
}

class _QueryTabState extends State<_QueryTab> {
  final _senderController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _lastResult;
  String? _error;

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Enter a message to check');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _lastResult = null;
    });

    final result = await ScanService.queryMessage(
      messageBody: body,
      sender: _senderController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _lastResult = result['data'] as Map<String, dynamic>?;
      } else {
        _error = result['message']?.toString() ?? 'Scan failed';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _senderController,
            decoration: const InputDecoration(
              labelText: 'Sender (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Message text',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppTheme.red)),
            ),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Checking...' : 'Check message'),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 20),
            _VerdictCard(scan: _lastResult!),
          ],
        ],
      ),
    );
  }
}

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ScanService.fetchScans();
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      setState(() {
        _items = (data?['content'] as List<dynamic>?) ?? [];
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No scans yet. Check a message first.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = _items[i] as Map<String, dynamic>;
          final sender = (s['sender']?.toString().isNotEmpty == true)
              ? s['sender'].toString()
              : 'Unknown sender';
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            title: Text(sender),
            subtitle: Text(
              s['messageBody']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _VerdictBadge(verdict: s['verdict']?.toString() ?? ''),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(sender),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['messageBody']?.toString() ?? ''),
                      const SizedBox(height: 12),
                      Text('Verdict: ${s['verdict']}'),
                      Text('Confidence: ${s['confidence']}'),
                      Text('Source: ${s['source']}'),
                      Text('When: ${s['scannedAt']}'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.scan});

  final Map<String, dynamic> scan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Result',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              _VerdictBadge(verdict: scan['verdict']?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 8),
          Text('Confidence: ${scan['confidence']}'),
          Text('Saved at: ${scan['scannedAt']}'),
        ],
      ),
    );
  }
}

class _VerdictBadge extends StatelessWidget {
  const _VerdictBadge({required this.verdict});

  final String verdict;

  @override
  Widget build(BuildContext context) {
    final color = switch (verdict.toUpperCase()) {
      'FRAUD' => AppTheme.red,
      'SUSPICIOUS' => Colors.orange.shade800,
      _ => Colors.green.shade700,
    };
    return Text(
      verdict,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
