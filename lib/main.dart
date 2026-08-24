import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await StorageService.init();
  runApp(const MathTrainerApp());
}

// -------------------------------------------------------------
// OFFLINE STORAGE & RECORD MANAGER
// -------------------------------------------------------------
class HighScoreRecord {
  final int correct;
  final int total;
  final double accuracy;
  final double qpm;
  final double spq;

  HighScoreRecord({
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.qpm,
    required this.spq,
  });
}

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _updateStreak();
  }

  static void _updateStreak() {
    final today = _formatDate(DateTime.now());
    final lastActive = _prefs.getString('last_active_date') ?? '';
    int currentStreak = _prefs.getInt('daily_streak') ?? 0;

    if (lastActive.isEmpty) {
      currentStreak = 1;
      _prefs.setString('last_active_date', today);
      _prefs.setInt('daily_streak', currentStreak);
    } else if (lastActive != today) {
      final lastDate = DateTime.tryParse(lastActive) ?? DateTime.now();
      final diff = DateTime.now().difference(lastDate).inDays;
      if (diff == 1) {
        currentStreak++;
      } else if (diff > 1) {
        currentStreak = 1;
      }
      _prefs.setString('last_active_date', today);
      _prefs.setInt('daily_streak', currentStreak);
    }
  }

  static String _formatDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static int getDailyStreak() => _prefs.getInt('daily_streak') ?? 1;

  static HighScoreRecord? getRecord(String key) {
    final acc = _prefs.getDouble('${key}_acc');
    final qpm = _prefs.getDouble('${key}_qpm');
    final spq = _prefs.getDouble('${key}_spq');
    final correct = _prefs.getInt('${key}_corr');
    final total = _prefs.getInt('${key}_tot');

    if (acc == null || qpm == null || spq == null) return null;
    return HighScoreRecord(
      correct: correct ?? 0,
      total: total ?? 0,
      accuracy: acc,
      qpm: qpm,
      spq: spq,
    );
  }

  static Future<bool> saveRecord(String key, HighScoreRecord newRecord) async {
    final old = getRecord(key);
    bool isNewBest = false;

    if (old == null ||
        (newRecord.qpm > old.qpm && newRecord.accuracy >= old.accuracy) ||
        (newRecord.accuracy > old.accuracy)) {
      isNewBest = true;
      await _prefs.setDouble('${key}_acc', newRecord.accuracy);
      await _prefs.setDouble('${key}_qpm', newRecord.qpm);
      await _prefs.setDouble('${key}_spq', newRecord.spq);
      await _prefs.setInt('${key}_corr', newRecord.correct);
      await _prefs.setInt('${key}_tot', newRecord.total);
    }
    return isNewBest;
  }
}

// -------------------------------------------------------------
// APP THEME & TITLE (SPA MATHS MATRIX)
// -------------------------------------------------------------
class MathTrainerApp extends StatelessWidget {
  const MathTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPA MATHS MATRIX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF161922),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// -------------------------------------------------------------
// 1. HOME SCREEN - CATEGORIES
// -------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final streak = StorageService.getDailyStreak();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SPA MATHS MATRIX',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Select an operation to begin',
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$streak Days',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCategoryCard(
                      context,
                      title: 'Addition',
                      subtitle: '2D+2D, 3D+2D, 3D+3D, 4x Chain',
                      icon: Icons.add_rounded,
                      color: const Color(0xFF6366F1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubCategoryScreen(category: OperationCategory.addition)),
                      ),
                    ),
                    _buildCategoryCard(
                      context,
                      title: 'Subtraction',
                      subtitle: '2D-2D, 3D-2D, 3D-3D, Complex',
                      icon: Icons.remove_rounded,
                      color: const Color(0xFFEC4899),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubCategoryScreen(category: OperationCategory.subtraction)),
                      ),
                    ),
                    _buildCategoryCard(
                      context,
                      title: 'Multiplication',
                      subtitle: '2D × 1D, 2D × 2D (RTL Typing)',
                      icon: Icons.close_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubCategoryScreen(category: OperationCategory.multiplication)),
                      ),
                    ),
                    _buildCategoryCard(
                      context,
                      title: 'Division',
                      subtitle: '3D ÷ 1D, 3D ÷ 2D, 4D ÷ 2D (Exact Integer)',
                      icon: Icons.safety_divider_rounded,
                      color: const Color(0xFF06B6D4),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubCategoryScreen(category: OperationCategory.division)),
                      ),
                    ),
                    _buildCategoryCard(
                      context,
                      title: 'Blind Flash Math',
                      subtitle: 'Visual Memory Flash & Multi-Step Anzan',
                      icon: Icons.flash_on_rounded,
                      color: const Color(0xFFF43F5E),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubCategoryScreen(category: OperationCategory.flashMath)),
                      ),
                    ),
                    _buildCategoryCard(
                      context,
                      title: 'Audio Math',
                      subtitle: 'Listening Calculation (TTS Engine)',
                      icon: Icons.headphones_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubCategoryScreen(category: OperationCategory.audioMath)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum OperationCategory {
  addition,
  subtraction,
  multiplication,
  division,
  flashMath,
  audioMath,
}

// -------------------------------------------------------------
// 2. SUB-CATEGORY SCREEN
// -------------------------------------------------------------
class SubCategoryScreen extends StatelessWidget {
  final OperationCategory category;
  const SubCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final data = _getCategoryData();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(data.desc, style: const TextStyle(fontSize: 13, color: Colors.white54)),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: data.modes.length,
                  itemBuilder: (context, idx) {
                    final item = data.modes[idx];
                    return _buildModeTile(context, item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTile(BuildContext context, ModeItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSpecial ? item.color.withOpacity(0.5) : Colors.white.withOpacity(0.06),
          width: item.isSpecial ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF161922),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              builder: (ctx) => QuotaSelectionSheet(mode: item.mode, modeName: item.title),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(item.subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  CategoryConfig _getCategoryData() {
    switch (category) {
      case OperationCategory.addition:
        return CategoryConfig(
          title: 'Addition Training',
          desc: 'Select digits format to practice',
          modes: [
            ModeItem(mode: MathMode.add2D2D, title: '2-Digit + 2-Digit', subtitle: 'DD + DD', icon: Icons.add, color: const Color(0xFF6366F1)),
            ModeItem(mode: MathMode.add3D2D, title: '3-Digit + 2-Digit', subtitle: 'DDD + DD', icon: Icons.add, color: const Color(0xFF818CF8)),
            ModeItem(mode: MathMode.add3D3D, title: '3-Digit + 3-Digit', subtitle: 'DDD + DDD', icon: Icons.add, color: const Color(0xFFA78BFA)),
            ModeItem(mode: MathMode.add4x2D, title: '4x 2-Digit Addition', subtitle: 'DD + DD + DD + DD', icon: Icons.playlist_add, color: const Color(0xFFC084FC)),
          ],
        );

      case OperationCategory.subtraction:
        return CategoryConfig(
          title: 'Subtraction Training',
          desc: 'Master positive difference calculations',
          modes: [
            ModeItem(mode: MathMode.sub2D2D, title: '2-Digit - 2-Digit', subtitle: 'DD - DD (Positive)', icon: Icons.remove, color: const Color(0xFFEC4899)),
            ModeItem(mode: MathMode.sub3D2D, title: '3-Digit - 2-Digit', subtitle: 'DDD - DD', icon: Icons.remove, color: const Color(0xFFF43F5E)),
            ModeItem(mode: MathMode.sub3D3D, title: '3-Digit - 3-Digit', subtitle: 'DDD - DDD (Positive)', icon: Icons.remove, color: const Color(0xFFFB7185)),
            ModeItem(mode: MathMode.subComplex, title: 'Complex Subtraction', subtitle: 'DDD - DD - D - D', icon: Icons.linear_scale, color: const Color(0xFFF59E0B)),
          ],
        );

      case OperationCategory.multiplication:
        return CategoryConfig(
          title: 'Multiplication Training',
          desc: 'Standard & Right-to-Left mental methods',
          modes: [
            ModeItem(mode: MathMode.mul2D1D, title: '2-Digit × 1-Digit', subtitle: 'DD × D', icon: Icons.close, color: const Color(0xFF06B6D4)),
            ModeItem(mode: MathMode.mul2D2D, title: '2-Digit × 2-Digit (RTL)', subtitle: 'DD × DD (Unit ➔ Tens)', icon: Icons.apps, color: const Color(0xFF10B981), isSpecial: true),
          ],
        );

      case OperationCategory.division:
        return CategoryConfig(
          title: 'Division Training',
          desc: 'Exact integer division for maximum speed',
          modes: [
            ModeItem(mode: MathMode.div3D1D, title: '3-Digit ÷ 1-Digit', subtitle: 'DDD ÷ D (2-Digit Quotient)', icon: Icons.safety_divider, color: const Color(0xFF06B6D4)),
            ModeItem(mode: MathMode.div3D2D, title: '3-Digit ÷ 2-Digit', subtitle: 'DDD ÷ DD (Single Digit Quotient)', icon: Icons.safety_divider, color: const Color(0xFF0EA5E9)),
            ModeItem(mode: MathMode.div4D2D, title: '4-Digit ÷ 2-Digit', subtitle: 'DDDD ÷ DD (2-Digit Quotient)', icon: Icons.safety_divider, color: const Color(0xFF38BDF8), isSpecial: true),
          ],
        );

      case OperationCategory.flashMath:
        return CategoryConfig(
          title: 'Blind Flash Memory',
          desc: 'Anzan visual flash speed calculations',
          modes: [
            ModeItem(mode: MathMode.flashAdd, title: 'Flash Addition', subtitle: '0.8s ➔ 0.3s (+) ➔ 0.6s ➔ Blank', icon: Icons.flash_on, color: const Color(0xFFF43F5E), isSpecial: true),
            ModeItem(mode: MathMode.flashSub, title: 'Flash Subtraction', subtitle: '0.8s ➔ 0.3s (-) ➔ 0.6s ➔ Blank', icon: Icons.flash_auto, color: const Color(0xFFFB923C), isSpecial: true),
            ModeItem(mode: MathMode.multiFlash, title: 'Multi-Step Chain Flash', subtitle: 'Continuous chain of 3 to 10 numbers', icon: Icons.all_inclusive, color: const Color(0xFFE11D48), isSpecial: true),
          ],
        );

      case OperationCategory.audioMath:
        return CategoryConfig(
          title: 'Auditory Math Training',
          desc: 'Train auditory processing and mental retention',
          modes: [
            ModeItem(mode: MathMode.audioAdd, title: 'Audio Addition', subtitle: 'Listen and calculate spoken numbers', icon: Icons.volume_up, color: const Color(0xFF0284C7), isSpecial: true),
            ModeItem(mode: MathMode.audioSub, title: 'Audio Subtraction', subtitle: 'Spoken auditory subtraction practice', icon: Icons.hearing, color: const Color(0xFF2563EB), isSpecial: true),
          ],
        );
    }
  }
}

class CategoryConfig {
  final String title;
  final String desc;
  final List<ModeItem> modes;
  CategoryConfig({required this.title, required this.desc, required this.modes});
}

class ModeItem {
  final MathMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSpecial;
  ModeItem({required this.mode, required this.title, required this.subtitle, required this.icon, required this.color, this.isSpecial = false});
}

enum MathMode {
  add2D2D,
  add3D2D,
  add3D3D,
  add4x2D,
  sub2D2D,
  sub3D2D,
  sub3D3D,
  subComplex,
  mul2D1D,
  mul2D2D,
  div3D1D,
  div3D2D,
  div4D2D,
  flashAdd,
  flashSub,
  multiFlash,
  audioAdd,
  audioSub,
}

// -------------------------------------------------------------
// 3. QUOTA MODAL
// -------------------------------------------------------------
class QuotaSelectionSheet extends StatefulWidget {
  final MathMode mode;
  final String modeName;
  const QuotaSelectionSheet({super.key, required this.mode, required this.modeName});

  @override
  State<QuotaSelectionSheet> createState() => _QuotaSelectionSheetState();
}

class _QuotaSelectionSheetState extends State<QuotaSelectionSheet> {
  final List<int> _quotaOptions = [20, 40, 60, 80, 100];
  int _selectedQuota = 40;
  int _chainLength = 4;

  @override
  Widget build(BuildContext context) {
    final recordKey = '${widget.mode.name}_$_selectedQuota';
    final best = StorageService.getRecord(recordKey);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.modeName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            const Text('Select question quota to practice:', style: TextStyle(fontSize: 13, color: Colors.white54)),
            const SizedBox(height: 16),

            Row(
              children: _quotaOptions.map((q) {
                final isSelected = q == _selectedQuota;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedQuota = q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF222634),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF818CF8) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$q',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            if (widget.mode == MathMode.multiFlash) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chain Length (Numbers):', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  DropdownButton<int>(
                    value: _chainLength,
                    dropdownColor: const Color(0xFF222634),
                    underline: const SizedBox(),
                    items: [3, 4, 5, 6, 8, 10].map((int val) {
                      return DropdownMenuItem<int>(
                        value: val,
                        child: Text('$val Steps', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _chainLength = v ?? 4),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0E14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: Colors.amberAccent, size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stored Personal Best ($_selectedQuota Questions)',
                        style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        best != null
                            ? '${best.accuracy.toStringAsFixed(1)}% Acc  •  ${best.qpm.toStringAsFixed(1)} QPM'
                            : 'No records yet',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _startTraining(context);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'START PRACTICE',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTraining(BuildContext context) {
    if (widget.mode == MathMode.flashAdd || widget.mode == MathMode.flashSub) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashMathScreen(
            isAddition: widget.mode == MathMode.flashAdd,
            totalQuota: _selectedQuota,
            modeName: widget.modeName,
            modeKey: widget.mode.name,
          ),
        ),
      );
    } else if (widget.mode == MathMode.multiFlash) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiStepFlashScreen(
            chainLength: _chainLength,
            totalQuota: _selectedQuota,
            modeName: widget.modeName,
            modeKey: widget.mode.name,
          ),
        ),
      );
    } else if (widget.mode == MathMode.audioAdd || widget.mode == MathMode.audioSub) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioMathScreen(
            isAddition: widget.mode == MathMode.audioAdd,
            totalQuota: _selectedQuota,
            modeName: widget.modeName,
            modeKey: widget.mode.name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StandardPracticeScreen(
            mode: widget.mode,
            totalQuota: _selectedQuota,
            modeName: widget.modeName,
          ),
        ),
      );
    }
  }
}

// -------------------------------------------------------------
// 4. STANDARD PRACTICE SCREEN
// -------------------------------------------------------------
class StandardPracticeScreen extends StatefulWidget {
  final MathMode mode;
  final int totalQuota;
  final String modeName;

  const StandardPracticeScreen({
    super.key,
    required this.mode,
    required this.totalQuota,
    required this.modeName,
  });

  @override
  State<StandardPracticeScreen> createState() => _StandardPracticeScreenState();
}

class _StandardPracticeScreenState extends State<StandardPracticeScreen> {
  final Random _rng = Random();

  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;

  String _questionText = '';
  int _correctAnswer = 0;
  String _userAnswer = '';

  late Stopwatch _stopwatch;
  Timer? _ticker;
  String _timeString = '00:00';

  HighScoreRecord? _personalBest;
  double _ghostProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _personalBest = StorageService.getRecord('${widget.mode.name}_${widget.totalQuota}');
    _stopwatch = Stopwatch()..start();

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) return;
      final totalSec = _stopwatch.elapsedMilliseconds / 1000.0;
      final m = (_stopwatch.elapsed.inMinutes).toString().padLeft(2, '0');
      final s = (_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0');

      double ghostP = 0.0;
      if (_personalBest != null && _personalBest!.spq > 0) {
        final ghostSolved = totalSec / _personalBest!.spq;
        ghostP = (ghostSolved / widget.totalQuota).clamp(0.0, 1.0);
      }

      setState(() {
        _timeString = '$m:$s';
        _ghostProgress = ghostP;
      });
    });

    _generateNextQuestion();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _generateNextQuestion() {
    setState(() => _userAnswer = '');

    switch (widget.mode) {
      case MathMode.add2D2D:
        int a = _rng.nextInt(90) + 10;
        int b = _rng.nextInt(90) + 10;
        _correctAnswer = a + b;
        _questionText = '$a + $b';
        break;

      case MathMode.add3D2D:
        int a = _rng.nextInt(900) + 100;
        int b = _rng.nextInt(90) + 10;
        _correctAnswer = a + b;
        _questionText = '$a + $b';
        break;

      case MathMode.add3D3D:
        int a = _rng.nextInt(900) + 100;
        int b = _rng.nextInt(900) + 100;
        _correctAnswer = a + b;
        _questionText = '$a + $b';
        break;

      case MathMode.add4x2D:
        int a = _rng.nextInt(90) + 10;
        int b = _rng.nextInt(90) + 10;
        int c = _rng.nextInt(90) + 10;
        int d = _rng.nextInt(90) + 10;
        _correctAnswer = a + b + c + d;
        _questionText = '$a + $b + $c + $d';
        break;

      case MathMode.sub2D2D:
        int a = _rng.nextInt(90) + 10;
        int b = _rng.nextInt(90) + 10;
        if (a < b) {
          int t = a;
          a = b;
          b = t;
        }
        _correctAnswer = a - b;
        _questionText = '$a - $b';
        break;

      case MathMode.sub3D2D:
        int a = _rng.nextInt(900) + 100;
        int b = _rng.nextInt(90) + 10;
        _correctAnswer = a - b;
        _questionText = '$a - $b';
        break;

      case MathMode.sub3D3D:
        int a = _rng.nextInt(900) + 100;
        int b = _rng.nextInt(900) + 100;
        if (a < b) {
          int t = a;
          a = b;
          b = t;
        }
        _correctAnswer = a - b;
        _questionText = '$a - $b';
        break;

      case MathMode.subComplex:
        int a = _rng.nextInt(900) + 100;
        int b = _rng.nextInt(90) + 10;
        int c = _rng.nextInt(9) + 1;
        int d = _rng.nextInt(9) + 1;
        _correctAnswer = a - b - c - d;
        _questionText = '$a - $b - $c - $d';
        break;

      case MathMode.mul2D1D:
        int a = _rng.nextInt(90) + 10;
        int b = _rng.nextInt(8) + 2;
        _correctAnswer = a * b;
        _questionText = '$a × $b';
        break;

      case MathMode.mul2D2D:
        int a = _rng.nextInt(90) + 10;
        int b = _rng.nextInt(90) + 10;
        _correctAnswer = a * b;
        _questionText = '$a × $b';
        break;

      case MathMode.div3D1D:
        int divisor = _rng.nextInt(8) + 2;
        int quotient = _rng.nextInt(89) + 11;
        int dividend = divisor * quotient;
        _correctAnswer = quotient;
        _questionText = '$dividend ÷ $divisor';
        break;

      case MathMode.div3D2D:
        int divisor2 = _rng.nextInt(80) + 12;
        int quotient2 = _rng.nextInt(8) + 2;
        int dividend2 = divisor2 * quotient2;
        _correctAnswer = quotient2;
        _questionText = '$dividend2 ÷ $divisor2';
        break;

      case MathMode.div4D2D:
        int divisor3 = _rng.nextInt(80) + 15;
        int quotient3 = _rng.nextInt(80) + 12;
        int dividend3 = divisor3 * quotient3;
        _correctAnswer = quotient3;
        _questionText = '$dividend3 ÷ $divisor3';
        break;

      default:
        break;
    }
  }

  void _onKeyPress(String val) {
    final bool isRtl = widget.mode == MathMode.mul2D2D;

    if (val == 'CLEAR') {
      setState(() => _userAnswer = '');
      return;
    }

    if (val == 'BACK') {
      if (_userAnswer.isNotEmpty) {
        setState(() {
          _userAnswer = isRtl ? _userAnswer.substring(1) : _userAnswer.substring(0, _userAnswer.length - 1);
        });
      }
      return;
    }

    if (val == 'SUBMIT') {
      _submitCurrentAnswer();
      return;
    }

    if (_userAnswer.length >= 7) return;

    setState(() {
      _userAnswer = isRtl ? (val + _userAnswer) : (_userAnswer + val);
    });
  }

  void _submitCurrentAnswer() {
    if (_userAnswer.isEmpty) return;

    final entered = int.tryParse(_userAnswer) ?? -999999;
    final isCorrect = entered == _correctAnswer;

    HapticFeedback.lightImpact();

    if (isCorrect) {
      _correctCount++;
    } else {
      _wrongCount++;
    }

    _currentIndex++;

    if (_currentIndex >= widget.totalQuota) {
      _finishTest();
    } else {
      _generateNextQuestion();
    }
  }

  void _finishTest() {
    _stopwatch.stop();
    _ticker?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultSummaryScreen(
          modeName: widget.modeName,
          modeKey: widget.mode.name,
          totalQuota: widget.totalQuota,
          correct: _correctCount,
          wrong: _wrongCount,
          totalSeconds: _stopwatch.elapsed.inSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRtl = widget.mode == MathMode.mul2D2D;
    final double userProgress = (_currentIndex / widget.totalQuota).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2230),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.totalQuota}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2230),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 15, color: Colors.cyanAccent),
                        const SizedBox(width: 5),
                        Text(
                          _timeString,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_personalBest != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text('You (${(_currentIndex)})', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Row(
                          children: [
                            Text('👻 Best Record', style: TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(height: 8, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4))),
                        FractionallySizedBox(
                          widthFactor: _ghostProgress,
                          child: Container(height: 8, decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.4), borderRadius: BorderRadius.circular(4))),
                        ),
                        FractionallySizedBox(
                          widthFactor: userProgress,
                          child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (isRtl)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '⇄ RTL Active (Unit ➔ Tens)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _questionText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C0E14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5), width: 1.5),
                          ),
                          child: Text(
                            _userAnswer.isEmpty ? '?' : _userAnswer,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _userAnswer.isEmpty ? Colors.white24 : const Color(0xFF818CF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            NumpadWithSubmit(onKeyPress: _onKeyPress),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. MULTI-STEP CHAIN FLASH SCREEN
// -------------------------------------------------------------
class MultiStepFlashScreen extends StatefulWidget {
  final int chainLength;
  final int totalQuota;
  final String modeName;
  final String modeKey;

  const MultiStepFlashScreen({
    super.key,
    required this.chainLength,
    required this.totalQuota,
    required this.modeName,
    required this.modeKey,
  });

  @override
  State<MultiStepFlashScreen> createState() => _MultiStepFlashScreenState();
}

class _MultiStepFlashScreenState extends State<MultiStepFlashScreen> {
  final Random _rng = Random();

  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;

  List<String> _chainSteps = [];
  int _correctAnswer = 0;
  String _userAnswer = '';

  int _currentStepIndex = 0;
  bool _isFlashing = true;
  double _speedFactor = 1.0;

  Timer? _stepTimer;
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _generateNextChain();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _generateNextChain() {
    _stepTimer?.cancel();
    _chainSteps.clear();

    int runningTotal = _rng.nextInt(80) + 15;
    _chainSteps.add('$runningTotal');

    for (int i = 1; i < widget.chainLength; i++) {
      bool add = _rng.nextBool();
      int val = _rng.nextInt(60) + 10;
      if (!add && runningTotal - val < 0) {
        add = true;
      }
      if (add) {
        runningTotal += val;
        _chainSteps.add('+$val');
      } else {
        runningTotal -= val;
        _chainSteps.add('-$val');
      }
    }

    _correctAnswer = runningTotal;
    _userAnswer = '';
    _playChain();
  }

  void _playChain() {
    _currentStepIndex = 0;
    setState(() => _isFlashing = true);

    final stepDuration = (850 / _speedFactor).round();

    _stepTimer = Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
      if (!mounted) return;
      if (_currentStepIndex < _chainSteps.length - 1) {
        setState(() => _currentStepIndex++);
      } else {
        timer.cancel();
        setState(() => _isFlashing = false);
      }
    });
  }

  void _onKeyPress(String val) {
    if (_isFlashing) return;

    if (val == 'CLEAR') {
      setState(() => _userAnswer = '');
      return;
    }
    if (val == 'BACK') {
      if (_userAnswer.isNotEmpty) {
        setState(() => _userAnswer = _userAnswer.substring(0, _userAnswer.length - 1));
      }
      return;
    }
    if (val == 'SUBMIT') {
      if (_userAnswer.isEmpty) return;
      final entered = int.tryParse(_userAnswer) ?? -99999;
      if (entered == _correctAnswer) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
      _currentIndex++;
      if (_currentIndex >= widget.totalQuota) {
        _finish();
      } else {
        _generateNextChain();
      }
      return;
    }

    if (_userAnswer.length >= 5) return;
    setState(() => _userAnswer += val);
  }

  void _finish() {
    _stopwatch.stop();
    _stepTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultSummaryScreen(
          modeName: '${widget.modeName} (${widget.chainLength} Steps)',
          modeKey: '${widget.modeKey}_chain${widget.chainLength}',
          totalQuota: widget.totalQuota,
          correct: _correctCount,
          wrong: _wrongCount,
          totalSeconds: _stopwatch.elapsed.inSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _isFlashing ? _chainSteps[_currentStepIndex] : (_userAnswer.isEmpty ? '?' : _userAnswer);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    '${_currentIndex + 1} / ${widget.totalQuota}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, color: Colors.cyanAccent),
                    onPressed: () {
                      _stepTimer?.cancel();
                      setState(() => _userAnswer = '');
                      _playChain();
                    },
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF161922), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 16, color: Colors.white60),
                  const SizedBox(width: 8),
                  Text('Speed: ${_speedFactor.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _speedFactor,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      activeColor: const Color(0xFF6366F1),
                      inactiveColor: Colors.white12,
                      onChanged: (v) => setState(() => _speedFactor = v),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: !_isFlashing ? const Color(0xFF10B981).withOpacity(0.4) : Colors.white.withOpacity(0.06),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 90),
                    child: Text(
                      currentText,
                      key: ValueKey<String>('$currentText$_isFlashing'),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: _isFlashing ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            NumpadWithSubmit(onKeyPress: _onKeyPress, enabled: !_isFlashing),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 6. AUDIO MATH (TTS) SCREEN
// -------------------------------------------------------------
class AudioMathScreen extends StatefulWidget {
  final bool isAddition;
  final int totalQuota;
  final String modeName;
  final String modeKey;

  const AudioMathScreen({
    super.key,
    required this.isAddition,
    required this.totalQuota,
    required this.modeName,
    required this.modeKey,
  });

  @override
  State<AudioMathScreen> createState() => _AudioMathScreenState();
}

class _AudioMathScreenState extends State<AudioMathScreen> {
  final FlutterTts _tts = FlutterTts();
  final Random _rng = Random();

  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;

  int _num1 = 0;
  int _num2 = 0;
  int _correctAnswer = 0;
  String _userAnswer = '';

  bool _isSpeaking = false;
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _generateNextAudioQuestion();
  }

  @override
  void dispose() {
    _tts.stop();
    _stopwatch.stop();
    super.dispose();
  }

  void _generateNextAudioQuestion() async {
    _num1 = _rng.nextInt(90) + 10;
    _num2 = _rng.nextInt(90) + 10;

    if (!widget.isAddition && _num1 < _num2) {
      int t = _num1;
      _num1 = _num2;
      _num2 = t;
    }

    _correctAnswer = widget.isAddition ? (_num1 + _num2) : (_num1 - _num2);
    _userAnswer = '';
    _playAudioSequence();
  }

  void _playAudioSequence() async {
    setState(() => _isSpeaking = true);
    final opWord = widget.isAddition ? "plus" : "minus";
    await _tts.speak("$_num1 ... $opWord ... $_num2");
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _onKeyPress(String val) {
    if (_isSpeaking) return;

    if (val == 'CLEAR') {
      setState(() => _userAnswer = '');
      return;
    }
    if (val == 'BACK') {
      if (_userAnswer.isNotEmpty) {
        setState(() => _userAnswer = _userAnswer.substring(0, _userAnswer.length - 1));
      }
      return;
    }
    if (val == 'SUBMIT') {
      if (_userAnswer.isEmpty) return;
      final entered = int.tryParse(_userAnswer) ?? -99999;
      if (entered == _correctAnswer) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
      _currentIndex++;
      if (_currentIndex >= widget.totalQuota) {
        _finish();
      } else {
        _generateNextAudioQuestion();
      }
      return;
    }

    if (_userAnswer.length >= 4) return;
    setState(() => _userAnswer += val);
  }

  void _finish() {
    _stopwatch.stop();
    _tts.stop();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultSummaryScreen(
          modeName: widget.modeName,
          modeKey: widget.modeKey,
          totalQuota: widget.totalQuota,
          correct: _correctCount,
          wrong: _wrongCount,
          totalSeconds: _stopwatch.elapsed.inSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    '${_currentIndex + 1} / ${widget.totalQuota}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: Colors.cyanAccent),
                    onPressed: _playAudioSequence,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSpeaking ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                        size: 70,
                        color: _isSpeaking ? Colors.cyanAccent : Colors.white30,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSpeaking ? 'Listening...' : 'Type your answer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isSpeaking ? Colors.cyanAccent : Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0E14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5), width: 1.5),
                        ),
                        child: Text(
                          _userAnswer.isEmpty ? '?' : _userAnswer,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _userAnswer.isEmpty ? Colors.white24 : const Color(0xFF818CF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            NumpadWithSubmit(onKeyPress: _onKeyPress, enabled: !_isSpeaking),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 7. BLIND 2-NUMBER FLASH SCREEN
// -------------------------------------------------------------
enum FlashStage { showNum1, showOp, showNum2, inputReady }

class FlashMathScreen extends StatefulWidget {
  final bool isAddition;
  final int totalQuota;
  final String modeName;
  final String modeKey;

  const FlashMathScreen({
    super.key,
    required this.isAddition,
    required this.totalQuota,
    required this.modeName,
    required this.modeKey,
  });

  @override
  State<FlashMathScreen> createState() => _FlashMathScreenState();
}

class _FlashMathScreenState extends State<FlashMathScreen> {
  final Random _rng = Random();

  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;

  int _num1 = 0;
  int _num2 = 0;
  int _correctAnswer = 0;
  String _userAnswer = '';

  FlashStage _stage = FlashStage.showNum1;
  double _speedFactor = 1.0;

  final int _baseT1 = 800;
  final int _baseT2 = 300;
  final int _baseT3 = 600;

  Timer? _animTimer;
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _generateNextFlashQuestion();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _generateNextFlashQuestion() {
    _animTimer?.cancel();
    _num1 = _rng.nextInt(90) + 10;
    _num2 = _rng.nextInt(90) + 10;

    if (!widget.isAddition && _num1 < _num2) {
      int t = _num1;
      _num1 = _num2;
      _num2 = t;
    }

    _correctAnswer = widget.isAddition ? (_num1 + _num2) : (_num1 - _num2);
    _userAnswer = '';
    _playFlashSequence();
  }

  void _playFlashSequence() {
    int t1 = (_baseT1 / _speedFactor).round();
    int t2 = (_baseT2 / _speedFactor).round();
    int t3 = (_baseT3 / _speedFactor).round();

    setState(() => _stage = FlashStage.showNum1);

    _animTimer = Timer(Duration(milliseconds: t1), () {
      if (!mounted) return;
      setState(() => _stage = FlashStage.showOp);

      _animTimer = Timer(Duration(milliseconds: t2), () {
        if (!mounted) return;
        setState(() => _stage = FlashStage.showNum2);

        _animTimer = Timer(Duration(milliseconds: t3), () {
          if (!mounted) return;
          setState(() => _stage = FlashStage.inputReady);
        });
      });
    });
  }

  void _onKeyPress(String val) {
    if (_stage != FlashStage.inputReady) return;

    if (val == 'CLEAR') {
      setState(() => _userAnswer = '');
      return;
    }
    if (val == 'BACK') {
      if (_userAnswer.isNotEmpty) {
        setState(() => _userAnswer = _userAnswer.substring(0, _userAnswer.length - 1));
      }
      return;
    }
    if (val == 'SUBMIT') {
      if (_userAnswer.isEmpty) return;
      final entered = int.tryParse(_userAnswer) ?? -99999;
      if (entered == _correctAnswer) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
      _currentIndex++;
      if (_currentIndex >= widget.totalQuota) {
        _finish();
      } else {
        _generateNextFlashQuestion();
      }
      return;
    }

    if (_userAnswer.length >= 4) return;
    setState(() => _userAnswer += val);
  }

  void _finish() {
    _stopwatch.stop();
    _animTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultSummaryScreen(
          modeName: widget.modeName,
          modeKey: widget.modeKey,
          totalQuota: widget.totalQuota,
          correct: _correctCount,
          wrong: _wrongCount,
          totalSeconds: _stopwatch.elapsed.inSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String centerDisplay = '';
    Color displayColor = Colors.white;

    switch (_stage) {
      case FlashStage.showNum1:
        centerDisplay = '$_num1';
        displayColor = const Color(0xFF38BDF8);
        break;
      case FlashStage.showOp:
        centerDisplay = widget.isAddition ? '+' : '−';
        displayColor = const Color(0xFFF59E0B);
        break;
      case FlashStage.showNum2:
        centerDisplay = '$_num2';
        displayColor = const Color(0xFFA855F7);
        break;
      case FlashStage.inputReady:
        centerDisplay = _userAnswer.isEmpty ? '?' : _userAnswer;
        displayColor = const Color(0xFF10B981);
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    '${_currentIndex + 1} / ${widget.totalQuota}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, color: Colors.cyanAccent),
                    onPressed: () {
                      _animTimer?.cancel();
                      setState(() => _userAnswer = '');
                      _playFlashSequence();
                    },
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF161922), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 16, color: Colors.white60),
                  const SizedBox(width: 8),
                  Text('Speed: ${_speedFactor.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _speedFactor,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      activeColor: const Color(0xFF6366F1),
                      inactiveColor: Colors.white12,
                      onChanged: (val) => setState(() => _speedFactor = val),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _stage == FlashStage.inputReady ? const Color(0xFF10B981).withOpacity(0.4) : Colors.white.withOpacity(0.06),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 90),
                    child: Text(
                      centerDisplay,
                      key: ValueKey<String>('$_stage$centerDisplay'),
                      style: TextStyle(
                        fontSize: 68,
                        fontWeight: FontWeight.w900,
                        color: displayColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            NumpadWithSubmit(onKeyPress: _onKeyPress, enabled: _stage == FlashStage.inputReady),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 8. ERGONOMIC NUMPAD WITH SUBMIT KEY
// -------------------------------------------------------------
class NumpadWithSubmit extends StatelessWidget {
  final Function(String) onKeyPress;
  final bool enabled;

  const NumpadWithSubmit({
    super.key,
    required this.onKeyPress,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(children: [_key('1'), _key('2'), _key('3')]),
                Row(children: [_key('4'), _key('5'), _key('6')]),
                Row(children: [_key('7'), _key('8'), _key('9')]),
                Row(
                  children: [
                    _actionKey('C', 'CLEAR', color: Colors.redAccent.withOpacity(0.15), textColor: Colors.redAccent),
                    _key('0'),
                    _actionKey('⌫', 'BACK', color: Colors.white.withOpacity(0.08), textColor: Colors.white70),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Material(
                color: enabled ? const Color(0xFF10B981) : const Color(0xFF151821),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: enabled ? () => onKeyPress('SUBMIT') : null,
                  child: Container(
                    height: (54 * 4) + 12,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward_rounded, size: 28, color: enabled ? Colors.white : Colors.white24),
                        const SizedBox(height: 4),
                        Text(
                          'ENTER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: enabled ? Colors.white : Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(String val) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Material(
          color: enabled ? const Color(0xFF1E2230) : const Color(0xFF151821),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => onKeyPress(val) : null,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Text(
                val,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: enabled ? Colors.white : Colors.white24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionKey(String label, String actionVal, {required Color color, required Color textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Material(
          color: enabled ? color : const Color(0xFF151821),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => onKeyPress(actionVal) : null,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: enabled ? textColor : Colors.white24)),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 9. RESULT SUMMARY SCREEN
// -------------------------------------------------------------
class ResultSummaryScreen extends StatefulWidget {
  final String modeName;
  final String modeKey;
  final int totalQuota;
  final int correct;
  final int wrong;
  final int totalSeconds;

  const ResultSummaryScreen({
    super.key,
    required this.modeName,
    required this.modeKey,
    required this.totalQuota,
    required this.correct,
    required this.wrong,
    required this.totalSeconds,
  });

  @override
  State<ResultSummaryScreen> createState() => _ResultSummaryScreenState();
}

class _ResultSummaryScreenState extends State<ResultSummaryScreen> {
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _saveResults();
  }

  void _saveResults() async {
    final int safeSeconds = max(1, widget.totalSeconds);
    final double accuracy = (widget.correct / widget.totalQuota) * 100.0;
    final double qpm = (widget.totalQuota / safeSeconds) * 60.0;
    final double spq = safeSeconds / widget.totalQuota;

    final String sessionKey = '${widget.modeKey}_${widget.totalQuota}';
    final currentRecord = HighScoreRecord(
      correct: widget.correct,
      total: widget.totalQuota,
      accuracy: accuracy,
      qpm: qpm,
      spq: spq,
    );

    final isBest = await StorageService.saveRecord(sessionKey, currentRecord);
    if (mounted) setState(() => _isNewBest = isBest);
  }

  @override
  Widget build(BuildContext context) {
    final int safeSeconds = max(1, widget.totalSeconds);
    final double accuracy = (widget.correct / widget.totalQuota) * 100.0;
    final double qpm = (widget.totalQuota / safeSeconds) * 60.0;
    final double spq = safeSeconds / widget.totalQuota;

    final sessionKey = '${widget.modeKey}_${widget.totalQuota}';
    final best = StorageService.getRecord(sessionKey);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Performance Report', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  if (_isNewBest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, color: Colors.amberAccent, size: 14),
                          SizedBox(width: 4),
                          Text('NEW BEST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                        ],
                      ),
                    ),
                ],
              ),
              Text('${widget.modeName} (${widget.totalQuota} Questions)', style: const TextStyle(fontSize: 13, color: Colors.white54)),
              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: CircularProgressIndicator(
                            value: accuracy / 100,
                            strokeWidth: 7,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accuracy >= 80 ? const Color(0xFF10B981) : Colors.orangeAccent,
                            ),
                          ),
                        ),
                        Text('${accuracy.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.correct} / ${widget.totalQuota} Correct', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text('Wrong Answers: ${widget.wrong}', style: TextStyle(fontSize: 13, color: widget.wrong > 0 ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('Total Time: ${safeSeconds ~/ 60}m ${safeSeconds % 60}s', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _metricCard('SPEED (QPM)', qpm.toStringAsFixed(1), 'questions / min', Icons.bolt, const Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricCard('PACE (SPQ)', spq.toStringAsFixed(2), 'seconds / question', Icons.timelapse, const Color(0xFF06B6D4)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 26),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Offline Record Stored', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          best != null ? '${best.accuracy.toStringAsFixed(1)}% Acc  •  ${best.qpm.toStringAsFixed(1)} QPM' : '${accuracy.toStringAsFixed(1)}% Acc  •  ${qpm.toStringAsFixed(1)} QPM',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('HOME', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CHANGE QUOTA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 1),
          Text(unit, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        ],
      ),
    );
  }
}
