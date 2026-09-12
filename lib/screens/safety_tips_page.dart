import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/safety_tips_service.dart';
import '../widgets/security_illustrations.dart';

class SafetyTipsPage extends StatefulWidget {
  const SafetyTipsPage({super.key});

  @override
  State<SafetyTipsPage> createState() => _SafetyTipsPageState();
}

class _SafetyTipsPageState extends State<SafetyTipsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<String> _bookmarkedIds = [];

  // Quiz state
  int _currentQuizIndex = 0;
  int _quizScore = 0;
  bool _quizAnswered = false;
  bool? _userAnswerIsScam;
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final bookmarks = await SafetyTipsService.getBookmarkedTipIds();
    final high = await SafetyTipsService.getHighQuizScore();
    setState(() {
      _bookmarkedIds = bookmarks;
      _highScore = high;
    });
  }

  void _toggleBookmark(String tipId) async {
    final isBookmarked = await SafetyTipsService.toggleBookmark(tipId);
    setState(() {
      if (isBookmarked) {
        _bookmarkedIds.add(tipId);
      } else {
        _bookmarkedIds.remove(tipId);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isBookmarked ? 'Tip saved to bookmarks!' : 'Tip removed from bookmarks.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Tab Header: Advice vs Spot-the-Scam Quiz
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            labelPadding: EdgeInsets.zero,
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16),
                    SizedBox(width: 6),
                    Text('Safety Advice'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Spot-the-Scam Quiz'),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCatalogTab(theme, isDark),
              _buildQuizTab(theme, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // --- CATALOG TAB ---
  Widget _buildCatalogTab(ThemeData theme, bool isDark) {
    final filteredTips = SafetyTipsService.tips.where((tip) {
      if (_selectedCategory != 'All' && tip.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = tip.title.toLowerCase().contains(query);
        final matchSummary = tip.summary.toLowerCase().contains(query);
        final matchExample = tip.realExample.toLowerCase().contains(query);
        if (!matchTitle && !matchSummary && !matchExample) return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const SafetyBrainIllustration(size: 70),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fraud Protection Knowledge',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Empower yourself against SMS phishing, bank impersonation, and voucher traps.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search safety advice or scam keywords...',
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
              filled: true,
              fillColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Banking', 'Delivery', 'Impersonation', 'Rewards', 'General']
                  .map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = cat);
                            }
                          },
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _selectedCategory == cat
                                ? Colors.white
                                : (isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Tips List
          if (filteredTips.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No tips match your search.',
                  style: GoogleFonts.inter(
                    color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                  ),
                ),
              ),
            )
          else
            ...filteredTips.map((tip) => _buildTipCard(tip, theme, isDark)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTipCard(SafetyTip tip, ThemeData theme, bool isDark) {
    final isBookmarked = _bookmarkedIds.contains(tip.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey(tip.id),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getCategoryIcon(tip.category), color: theme.colorScheme.primary),
        ),
        title: Text(
          tip.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tip.category,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: isBookmarked ? theme.colorScheme.primary : (isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
          ),
          onPressed: () => _toggleBookmark(tip.id),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  tip.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Red Flags Block
                Text(
                  '🚩 RED FLAGS TO WATCH',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.red,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                ...tip.redFlags.map((flag) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              flag,
                              style: GoogleFonts.inter(fontSize: 12, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 14),

                // What to Do Block
                Text(
                  '🛡️ WHAT YOU SHOULD DO',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.green,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                ...tip.actionSteps.map((action) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              action,
                              style: GoogleFonts.inter(fontSize: 12, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 14),

                // Real Scam Example Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REAL SCAM SMS EXAMPLE:',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.realExample,
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- QUIZ TAB ---
  Widget _buildQuizTab(ThemeData theme, bool isDark) {
    final questions = SafetyTipsService.quizQuestions;

    // Completed State
    if (_currentQuizIndex >= questions.length) {
      final isHigh = _quizScore > _highScore;
      if (isHigh) {
        SafetyTipsService.saveQuizScore(_quizScore);
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const QuizVictoryIllustration(size: 120),
              const SizedBox(height: 20),
              Text(
                'Quiz Completed!',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored $_quizScore out of ${questions.length}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isHigh ? '🎉 NEW HIGH SCORE!' : 'High Score: $_highScore / ${questions.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.replay),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _currentQuizIndex = 0;
                    _quizScore = 0;
                    _quizAnswered = false;
                    _userAnswerIsScam = null;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    final question = questions[_currentQuizIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Progress & Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuizIndex + 1} of ${questions.length}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 4),
                    Text(
                      'Score: $_quizScore',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentQuizIndex + 1) / questions.length,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),

          // Simulated Phone SMS Message Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                      child: Icon(Icons.person, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.sender,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Incoming Text Message',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    question.message,
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Answer Buttons
          if (!_quizAnswered) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'REAL SMS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () => _handleAnswer(false),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.gpp_bad),
                    label: const Text(
                      'SCAM SMS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () => _handleAnswer(true),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Result Feedback Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _userAnswerIsScam == question.isScam
                    ? Colors.green.withOpacity(0.12)
                    : AppTheme.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _userAnswerIsScam == question.isScam ? Colors.green : AppTheme.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _userAnswerIsScam == question.isScam ? Icons.check_circle : Icons.cancel,
                        color: _userAnswerIsScam == question.isScam ? Colors.green : AppTheme.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _userAnswerIsScam == question.isScam ? 'Correct Answer!' : 'Incorrect!',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _userAnswerIsScam == question.isScam ? Colors.green : AppTheme.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    question.explanation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _currentQuizIndex++;
                          _quizAnswered = false;
                          _userAnswerIsScam = null;
                        });
                      },
                      child: const Text('Next Question', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _handleAnswer(bool userSaidScam) {
    final question = SafetyTipsService.quizQuestions[_currentQuizIndex];
    final isCorrect = userSaidScam == question.isScam;

    setState(() {
      _quizAnswered = true;
      _userAnswerIsScam = userSaidScam;
      if (isCorrect) {
        _quizScore++;
      }
    });
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Banking':
        return Icons.account_balance_outlined;
      case 'Delivery':
        return Icons.local_shipping_outlined;
      case 'Impersonation':
        return Icons.person_off_outlined;
      case 'Rewards':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.shield_outlined;
    }
  }
}
