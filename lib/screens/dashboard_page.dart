import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../main.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  // Controllers
  final _scanController = TextEditingController();
  final _blockNumberController = TextEditingController();

  // Scan state
  bool _isScanning = false;
  String? _scanResult;
  bool? _scanIsSafe;
  double _threatLevel = 0.0;

  // Blocklist state
  final List<Map<String, String>> _blockedNumbers = [
    {'number': '+27829876543', 'date': '2026-08-20'},
    {'number': '+27831112222', 'date': '2026-08-21'},
    {'number': '+14155552671', 'date': '2026-08-22'},
  ];

  // Mock Logs state
  final List<Map<String, dynamic>> _smsLogs = [
    {
      'sender': '+27821110000',
      'message': 'Congratulations! You have won a R5000 voucher from Woolworths. Click http://bit.ly/woolies-win to claim now!',
      'type': 'Fraud',
      'time': '10 mins ago',
      'threat': 0.95
    },
    {
      'sender': '+27832223333',
      'message': 'FNB Alert: A login attempt was made on your profile. If this was not you, please verify your details here: https://fnb-secure-login.info',
      'type': 'Fraud',
      'time': '1 hour ago',
      'threat': 0.98
    },
    {
      'sender': 'Absa Bank',
      'message': 'Your OTP is 492010. Do not share this code with anyone.',
      'type': 'Safe',
      'time': '2 hours ago',
      'threat': 0.02
    },
    {
      'sender': '+14150009999',
      'message': 'URGENT: Your parcel delivery is pending. Pay outstanding customs fee of \$1.50 immediately to avoid return: http://usps-tracking-fees.com',
      'type': 'Spam',
      'time': '1 day ago',
      'threat': 0.72
    },
    {
      'sender': '+27829998888',
      'message': 'Hey, are we still meeting for coffee at 3pm today? Let me know.',
      'type': 'Safe',
      'time': '1 day ago',
      'threat': 0.00
    },
  ];

  @override
  void dispose() {
    _scanController.dispose();
    _blockNumberController.dispose();
    super.dispose();
  }

  void _handleManualScan() async {
    final text = _scanController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isScanning = true;
      _scanResult = null;
    });

    // Simulate AI model scan processing delay
    await Future.delayed(const Duration(seconds: 2));

    final lowerText = text.toLowerCase();
    bool isFraud = false;
    bool isSpam = false;
    double calculatedThreat = 0.0;
    String feedback = '';

    if (lowerText.contains('win') ||
        lowerText.contains('won') ||
        lowerText.contains('prize') ||
        lowerText.contains('voucher') ||
        lowerText.contains('gift card') ||
        lowerText.contains('click') ||
        lowerText.contains('link') ||
        lowerText.contains('http') ||
        lowerText.contains('https')) {
      isFraud = true;
      calculatedThreat = 0.85 + (0.14 * (text.length % 10) / 10);
      feedback = 'This message contains high-risk external link and financial reward patterns.';
    } else if (lowerText.contains('urgent') ||
        lowerText.contains('verify') ||
        lowerText.contains('account') ||
        lowerText.contains('unauthorized') ||
        lowerText.contains('bank') ||
        lowerText.contains('login') ||
        lowerText.contains('update')) {
      isFraud = true;
      calculatedThreat = 0.90 + (0.09 * (text.length % 10) / 10);
      feedback = 'Impersonation detected. Genuine institutions do not request credential verification via SMS.';
    } else if (lowerText.contains('promo') ||
        lowerText.contains('offer') ||
        lowerText.contains('subscribe') ||
        lowerText.contains('free') ||
        lowerText.contains('buy') ||
        lowerText.contains('sale')) {
      isSpam = true;
      calculatedThreat = 0.50 + (0.25 * (text.length % 10) / 10);
      feedback = 'Unsolicited promotional content patterns detected.';
    } else {
      calculatedThreat = 0.01 + (0.09 * (text.length % 10) / 10);
      feedback = 'No suspicious characteristics detected. This message appears normal.';
    }

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _scanIsSafe = !isFraud && !isSpam;
      _threatLevel = calculatedThreat;
      if (isFraud) {
        _scanResult = '🚨 High Risk Alert: Potential Phishing/Fraud detected!\n\n$feedback';
      } else if (isSpam) {
        _scanResult = '⚠️ Moderate Risk: Spam content detected.\n\n$feedback';
      } else {
        _scanResult = '✅ Secure: This message is safe.\n\n$feedback';
      }

      // Add to logs
      _smsLogs.insert(0, {
        'sender': 'Manual Scan',
        'message': text.length > 60 ? '${text.substring(0, 57)}...' : text,
        'type': isFraud ? 'Fraud' : (isSpam ? 'Spam' : 'Safe'),
        'time': 'Just now',
        'threat': calculatedThreat,
      });
    });
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MyApp()), // Will reload App with Login
      (route) => false,
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
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gpp_good, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: GoogleFonts.inter(
                              color: Colors.green,
                              fontSize: 12,
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
                  value: '1,245',
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
                  value: '42',
                  icon: Icons.gpp_bad_outlined,
                  iconColor: Colors.amber.shade700,
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMetricCard(
            title: 'System Safety Index',
            value: '97.4% Secure',
            icon: Icons.insights,
            iconColor: Colors.teal,
            theme: theme,
            isDark: isDark,
            subtitle: 'Outstanding security score',
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
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _smsLogs.length,
      itemBuilder: (context, index) {
        final log = _smsLogs[index];
        final type = log['type'];
        final Color statusColor = type == 'Safe'
            ? Colors.green
            : (type == 'Fraud' ? Colors.red : Colors.amber.shade700);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log['time'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Threat Index: ${(log['threat'] * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                            backgroundColor: AppTheme.primaryLight,
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

          // Theme Switch Card
          Card(
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
                      MyApp.of(context).toggleTheme();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

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
