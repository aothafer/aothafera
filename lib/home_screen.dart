import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_challenge_screen.dart';
import 'challenge_detail_sheet.dart';
import 'challenge_provider.dart';
import 'completed_challenges_screen.dart';
import 'models.dart';
import 'statistics_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  final String? initialChallengeId;

  const HomeScreen({super.key, this.initialChallengeId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final challengeId = widget.initialChallengeId;
    if (challengeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logProgress(context, challengeId, fromReminder: true);
        }
      });
    }
  }

  Future<void> _logProgress(
    BuildContext context,
    String challengeId, {
    bool fromReminder = false,
  }) async {
    final provider = context.read<ChallengeProvider>();
    final matching = provider.challenges.where((c) => c.id == challengeId);
    if (matching.isEmpty) return;
    final c = matching.first;
    String input = '';
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('سجّل تقدمك في "${c.title}"'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'كم أنجزت من ${c.unit} اليوم؟',
          ),
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

    if (amount == null || !context.mounted) return;

    if (fromReminder) {
      final today = DateUtils.dateOnly(DateTime.now());
      final loggedToday = c.logs
          .where((log) => DateUtils.isSameDay(log.date, today))
          .fold<int>(0, (total, log) => total + log.amount);
      final minimumToday = c.minimumDailyCheckIn;
      if (loggedToday + amount < minimumToday) {
        final scheduleAgain = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('الإنجاز أقل من المطلوب'),
            content: Text(
              'إجمالي ما أنجزته اليوم أقل من 20٪ من الحد الأدنى اليومي. '
              'أنجز $minimumToday ${c.unit} على الأقل اليوم. '
              'لم يُحفظ هذا الإدخال. اضبط تنبيهًا آخر لوقت قادم، ثم أكمل وسجّل إنجازك.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ضبط تنبيه آخر'),
              ),
            ],
          ),
        );
        if (scheduleAgain == true && context.mounted) {
          await _rescheduleTodaysReminder(context, c);
        }
        return;
      }
    }

    if (amount > 0 && context.mounted) {
      await provider.addLog(c.id, amount);
      final updated = provider.challenges.firstWhere((item) => item.id == c.id);
      if (updated.status == ChallengeStatus.active &&
          updated.totalDone >= updated.targetMin &&
          updated.totalDone < updated.targetMax &&
          context.mounted) {
        final finishNow = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('وصلت إلى الحد الأدنى'),
            content: const Text(
              'يمكنك إكمال التحدي حتى موعده، أو إنهاؤه الآن ونقله إلى التحديات المنتهية. هل تريد إنهاءه؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('أكمل التحدي'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إنهاء الآن'),
              ),
            ],
          ),
        );
        if (finishNow == true && context.mounted) {
          await provider.finishChallenge(c.id);
        }
      }
    }
  }

  Future<void> _rescheduleTodaysReminder(
    BuildContext context,
    Challenge challenge,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(challenge.startDate);
    final end = DateUtils.dateOnly(challenge.endDate);
    if (today.isBefore(start) || today.isAfter(end)) return;

    final dayIndex = today.difference(start).inDays;
    final picked = await showTimePicker(
      context: context,
      initialTime: challenge.reminder.timeForDay(dayIndex),
    );
    if (picked == null || !context.mounted) return;

    final scheduledAt = DateTime(
      today.year,
      today.month,
      today.day,
      picked.hour,
      picked.minute,
    );
    if (!scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر وقتًا قادمًا اليوم للتنبيه الجديد.'),
        ),
      );
      return;
    }

    final perDayTimes = Map<int, TimeOfDay>.of(challenge.reminder.perDayTimes)
      ..[dayIndex] = picked;
    final result = await context.read<ChallengeProvider>().updateChallenge(
      challenge.id,
      title: challenge.title,
      unit: challenge.unit,
      dailyTargetMin: challenge.dailyTargetMin,
      dailyTargetMax: challenge.dailyTargetMax,
      startDate: challenge.startDate,
      endDate: challenge.endDate,
      reminder: challenge.reminder.copyWith(perDayTimes: perDayTimes),
      groupId: challenge.groupId,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error == null
              ? 'تم ضبط تنبيه جديد لليوم الساعة ${picked.format(context)}.'
              : 'تعذر ضبط التنبيه الجديد: ${result.error}',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenges = context.watch<ChallengeProvider>().visibleChallenges;

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
                          onLog: () => _logProgress(context, c.id),
                          onFinish: () => context
                              .read<ChallengeProvider>()
                              .finishChallenge(c.id),
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

/// الهيدر: اللوحة مع تلاشٍ ناعم في أولها وآخرها لتذوب في الخلفية
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
                  colors: [AppColors.bg, AppColors.bg.withValues(alpha: 0)],
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
                  colors: [AppColors.bg.withValues(alpha: 0), AppColors.bg],
                ),
              ),
            ),
          ),
          // زر الرئيسية: يعيدك إلى شاشة الترحيب
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
          // زر القائمة الجانبية
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
                Text('تحدياتي', style: textTheme.headlineMedium),
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
  final VoidCallback onFinish;
  final VoidCallback onDelete;

  const _ChallengeCard({
    required this.challenge,
    required this.onLog,
    required this.onFinish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final textTheme = Theme.of(context).textTheme;
    final failed = c.status == ChallengeStatus.failed;
    final own = AppColors
        .challengeColors[c.colorIndex % AppColors.challengeColors.length];
    final accent = failed ? AppColors.rose : own;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => showChallengeSummarySheet(context, c, accent),
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
                          '${c.totalDone} / ${c.targetMax} ${c.unit}',
                          style: textTheme.titleMedium?.copyWith(color: accent),
                        ),
                        Text(
                          'الحد الأدنى الكلي ${c.targetMin} ${c.unit} · '
                          '${c.dailyTargetMin}–${c.dailyTargetMax} يوميًا',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_left,
                    color: AppColors.muted,
                    size: 18,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.muted,
                    ),
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
                  children: failed
                      ? [
                          _InfoChip(
                            icon: Icons.flag_outlined,
                            text: 'انتهت المدة دون بلوغ الحد الأدنى',
                            color: accent,
                          ),
                        ]
                      : [
                          _InfoChip(
                            icon: Icons.schedule,
                            text: 'المتبقي ${c.daysLeft} يوم',
                            color: accent,
                          ),
                          _InfoChip(
                            icon: Icons.trending_up,
                            text:
                                'متوسط بلوغ الحد الأدنى: ${c.neededPerDay} ${c.unit} يوميًا',
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
              if (c.totalDone >= c.targetMin && c.totalDone < c.targetMax) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('إنهاء التحدي الآن'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// حلقة التقدم، تتحرك بسلاسة عند تغيّر القيمة
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
          Text('ابدأ تحدّيك الأول', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'حدّد هدفًا وسجّل تقدمك يوميًا،\nوسترى الطريق أمامك يتّسع.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// القائمة الجانبية
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  void _comingSoon(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('سيُتاح هذا في مرحلة قادمة')));
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget item(
      IconData icon,
      String label, {
      Color? color,
      VoidCallback? onTap,
    }) => ListTile(
      leading: Icon(icon, color: color ?? AppColors.cream),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap ?? () => _comingSoon(context),
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
            item(
              Icons.bar_chart,
              'إحصائياتي',
              onTap: () => _openScreen(context, const StatisticsScreen()),
            ),
            item(
              Icons.emoji_events_outlined,
              'التحديات المنتهية',
              onTap: () =>
                  _openScreen(context, const CompletedChallengesScreen()),
            ),
            const Spacer(),
            const Divider(),
            item(Icons.logout, 'تسجيل الخروج'),
            item(
              Icons.delete_forever_outlined,
              'مسح الحساب',
              color: AppColors.terracotta,
            ),
          ],
        ),
      ),
    );
  }
}
