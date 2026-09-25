import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_challenge_screen.dart';
import 'challenge_detail_sheet.dart';
import 'challenge_provider.dart';
import 'models.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logProgress(BuildContext context, Challenge c) async {
    String input = '';
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('سجّل تقدمك في "${c.title}"'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'كم غنمت ${c.unit} اليوم ؟'),
          onChanged: (value) => input = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(input)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0 && context.mounted) {
      context.read<ChallengeProvider>().addLog(c.id, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenges = context.watch<ChallengeProvider>().challenges;

    return Scaffold(
      drawer: const _AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddChallengeScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('تحدٍ جديد'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _HeaderBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: challenges.isEmpty
                ? const _EmptyState()
                : Column(
                    children: [
                      for (final c in challenges)
                        _ChallengeCard(
                          challenge: c,
                          onLog: () => _logProgress(context, c),
                          onDelete: () => context
                              .read<ChallengeProvider>()
                              .removeChallenge(c.id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// الهيدر: اللوحة مع تلاشي ناعم في أولها وآخرها عشان تذوب في الخلفية
class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/header.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(-0.2, 0),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bg,
                    AppColors.bg.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bg.withValues(alpha: 0),
                    AppColors.bg,
                  ],
                ),
              ),
            ),
          ),
          // زرار الرئيسية: بيرجعك لشاشة الترحيب
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 8,
            child: IconButton(
              tooltip: 'الصفحة الرئيسية',
              icon: const Icon(Icons.home_outlined, color: AppColors.cream),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
          // زرار التلات شرط: بيفتح القايمة الجانبية
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.menu, color: AppColors.cream),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرمى الهدف', style: textTheme.headlineMedium),
                Text(
                  'كل يوم خطوة',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onLog;
  final VoidCallback onDelete;

  const _ChallengeCard({
    required this.challenge,
    required this.onLog,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final textTheme = Theme.of(context).textTheme;
    final done = c.remaining == 0;
    final own = AppColors.challengeColors[
        c.colorIndex % AppColors.challengeColors.length];
    final accent = done ? AppColors.tealLight : own;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => showChallengeDetail(context, c, accent),
        child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ProgressRing(progress: c.progress, color: accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${c.totalDone} / ${c.targetMin} ${c.unit}',
                      style: textTheme.titleMedium?.copyWith(color: accent),
                    ),
                    if (c.targetMax > c.targetMin)
                      Text(
                        'الحد الأقصى ${c.targetMax}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: AppColors.muted, size: 18),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: done
                  ? [
                      _InfoChip(
                        icon: Icons.emoji_events_outlined,
                        text: 'أنهيت حدّك الأدنى!',
                        color: accent,
                      ),
                    ]
                  : [
                      _InfoChip(
                        icon: Icons.schedule,
                        text: 'يتبقى لديك ${c.daysLeft} يوم',
                        color: accent,
                      ),
                      _InfoChip(
                        icon: Icons.trending_up,
                        text: '${c.neededPerDay} ${c.unit} يوميًا',
                        color: accent,
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppColors.bg,
              ),
              onPressed: onLog,
              icon: const Icon(Icons.add),
              label: const Text('سجّل تقدمك'),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// دايرة التقدم، بتتحرك بشكل ناعم لما الرقم يتغير
class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color color;

  const _ProgressRing({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: value,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            Center(
              child: Text(
                '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text('ابدأ تحدّيك الأول!', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'فاقصد إلى قِمَمِ الأشياءِ تُدرِكُها\nتَجري الرياحُ كما رَادَتْ لها السفنُ',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// القايمة الجانبية. الخيارات لسه مش شغالة، هتتفعل في المراحل الجاية.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  void _comingSoon(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزةٌ ما في الطريق')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget item(IconData icon, String label, {Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? AppColors.cream),
          title: Text(label, style: TextStyle(color: color)),
          onTap: () => _comingSoon(context),
        );

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text('عُذافِرة', style: textTheme.headlineMedium),
            ),
            const Divider(),
            item(Icons.person_outline, 'حسابي'),
            item(Icons.bar_chart, 'إحصائياتي'),
            item(Icons.notifications_none, 'إعدادات الإشعارات'),
            const Spacer(),
            const Divider(),
            item(Icons.logout, 'تسجيل الخروج'),
            item(Icons.delete_forever_outlined, 'مسح الحساب',
                color: AppColors.terracotta),
          ],
        ),
      ),
    );
  }
}
