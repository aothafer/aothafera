import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_challenge_screen.dart';
import 'challenge_detail_sheet.dart';
import 'challenge_provider.dart';
import 'completed_challenges_screen.dart';
import 'models.dart';
import 'schedule_models.dart';
import 'schedule_screen.dart';
import 'statistics_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  final String? initialChallengeId;

  const HomeScreen({super.key, this.initialChallengeId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _itemsPerPage = 3;
  late final PageController _challengePageController;
  int _challengePage = 0;
  bool _pageClampQueued = false;

  @override
  void initState() {
    super.initState();
    _challengePageController = PageController();
    final challengeId = widget.initialChallengeId;
    if (challengeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logProgress(context, challengeId, fromReminder: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _challengePageController.dispose();
    super.dispose();
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
        final projectedMin = _projectedDailyRequirement(
          c,
          progressAfterToday: c.totalDone + amount,
          maximum: false,
        );
        final projectedMax = _projectedDailyRequirement(
          c,
          progressAfterToday: c.totalDone + amount,
          maximum: true,
        );
        final choice = await showDialog<int>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('إنجاز اليوم أقل من 20٪'),
            content: Text(
              'إجمالي إنجازك اليوم أقل من $minimumToday ${c.unit}، وهو 20٪ من الحد الأدنى المطلوب اليوم. '
              'لو اعتمدنا هذا التقدم، سيصبح متوسط ما تحتاج لإنجازه في الأيام المتبقية '
              '$projectedMin–$projectedMax ${c.unit} يوميًا. '
              'التسويف قد يراكم المطلوب ويصعّب الوصول لهدفك.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 1),
                child: const Text('أكمل ثم اضبط تنبيهًا آخر'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 2),
                child: const Text('سجّل التقدم كما هو'),
              ),
            ],
          ),
        );
        if (choice == 1 && context.mounted) {
          await _rescheduleTodaysReminder(context, c);
          return;
        }
        if (choice != 2) return;
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

  int _projectedDailyRequirement(
    Challenge challenge, {
    required int progressAfterToday,
    required bool maximum,
  }) {
    final target = maximum ? challenge.targetMax : challenge.targetMin;
    final remaining = (target - progressAfterToday).clamp(0, target);
    final daysAfterToday = (challenge.daysLeft - 1).clamp(
      0,
      challenge.totalDays,
    );
    if (daysAfterToday == 0) return remaining;
    return (remaining / daysAfterToday).ceil();
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
    final provider = context.watch<ChallengeProvider>();
    final items = <_HomeDashboardItem>[];
    for (final group in provider.groups) {
      final members = provider.visibleChallenges
          .where((challenge) => challenge.groupId == group.id)
          .toList();
      if (members.isNotEmpty) items.add(_HomeDashboardItem.group(group, members));
    }
    for (final challenge in provider.visibleChallenges.where((c) => c.groupId == null)) {
      items.add(_HomeDashboardItem.challenge(challenge));
    }
    final pageCount = (items.length / _itemsPerPage).ceil();
    if (pageCount > 0 && _challengePage >= pageCount && !_pageClampQueued) {
      _pageClampQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageClampQueued = false;
        if (!mounted || pageCount == 0) return;
        final lastPage = pageCount - 1;
        if (_challengePage > lastPage) {
          _challengePageController.jumpToPage(lastPage);
          setState(() => _challengePage = lastPage);
        }
      });
    }

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
      body: Column(
        children: [
          _HeaderBanner(schedules: provider.homeSchedules),
          Expanded(
            child: items.isEmpty
                ? const _EmptyState()
                : Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _challengePageController,
                          itemCount: pageCount,
                          onPageChanged: (page) => setState(() => _challengePage = page),
                          itemBuilder: (context, page) {
                            final start = page * _itemsPerPage;
                            final end = (start + _itemsPerPage).clamp(0, items.length).toInt();
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                              itemCount: end - start,
                              itemBuilder: (context, offset) {
                                final item = items[start + offset];
                                if (item.group != null) {
                                  return _GroupDashboardCard(
                                    group: item.group!,
                                    challenges: item.challenges,
                                    onTap: () => Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChallengeGroupScreen(
                                          groupId: item.group!.id,
                                          onLog: (id) => _logProgress(context, id),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final challenge = item.challenge!;
                                return _ChallengeCard(
                                  key: ValueKey(challenge.id),
                                  challenge: challenge,
                                  onLog: () => _logProgress(context, challenge.id),
                                  onFinish: () => context.read<ChallengeProvider>().finishChallenge(challenge.id),
                                  onDelete: () => context.read<ChallengeProvider>().removeChallenge(challenge.id),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (pageCount > 1)
                        _ChallengePageControls(
                          currentPage: _challengePage,
                          pageCount: pageCount,
                          onPrevious: () => _challengePageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                          onNext: () => _challengePageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HomeDashboardItem {
  final Group? group;
  final Challenge? challenge;
  final List<Challenge> challenges;

  const _HomeDashboardItem._({this.group, this.challenge, this.challenges = const []});

  factory _HomeDashboardItem.group(Group group, List<Challenge> challenges) =>
      _HomeDashboardItem._(group: group, challenges: challenges);

  factory _HomeDashboardItem.challenge(Challenge challenge) =>
      _HomeDashboardItem._(challenge: challenge);
}

class _ChallengePageControls extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ChallengePageControls({
    required this.currentPage,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        IconButton(
          tooltip: 'الصفحة السابقة',
          onPressed: currentPage == 0 ? null : onPrevious,
          icon: const Icon(Icons.chevron_right),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('صفحة ${currentPage + 1} من $pageCount', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var page = 0; page < pageCount; page++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: page == currentPage ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: page == currentPage ? AppColors.mustard : AppColors.track,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'الصفحة التالية',
          onPressed: currentPage == pageCount - 1 ? null : onNext,
          icon: const Icon(Icons.chevron_left),
        ),
      ],
    ),
  );
}

class _GroupDashboardCard extends StatelessWidget {
  final Group group;
  final List<Challenge> challenges;
  final VoidCallback? onTap;

  const _GroupDashboardCard({required this.group, required this.challenges, this.onTap});

  @override
  Widget build(BuildContext context) {
    final target = challenges.fold<int>(0, (sum, challenge) => sum + challenge.targetMax);
    final done = challenges.fold<int>(0, (sum, challenge) => sum + challenge.totalDone);
    final progress = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const CircleAvatar(
                  backgroundColor: AppColors.track,
                  child: Icon(Icons.folder_copy_outlined, color: AppColors.mustard),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                  Text('${challenges.length} تحديات نشطة', style: const TextStyle(color: AppColors.muted)),
                ])),
                Text('$percent%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.mustard)),
                if (onTap != null) const Icon(Icons.chevron_left, color: AppColors.muted),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.track,
                  valueColor: const AlwaysStoppedAnimation(AppColors.mustard),
                ),
              ),
              const SizedBox(height: 8),
              Text('$done / $target إنجازًا ضمن المجموعة', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class ChallengeGroupScreen extends StatelessWidget {
  final String groupId;
  final Future<void> Function(String id) onLog;

  const ChallengeGroupScreen({super.key, required this.groupId, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final group = provider.groupById(groupId);
    final challenges = provider.visibleChallenges.where((challenge) => challenge.groupId == groupId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(group?.title ?? 'تحديات المجموعة')),
      body: challenges.isEmpty
          ? const Center(child: Text('لا توجد تحديات نشطة في هذه المجموعة.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                if (group != null)
                  _GroupDashboardCard(group: group, challenges: challenges),
                for (final challenge in challenges)
                  _ChallengeCard(
                    key: ValueKey(challenge.id),
                    challenge: challenge,
                    onLog: () => onLog(challenge.id),
                    onFinish: () => provider.finishChallenge(challenge.id),
                    onDelete: () => provider.removeChallenge(challenge.id),
                  ),
              ],
            ),
    );
  }
}

/// The illustrated header and selected schedule cards share a swipeable carousel.
class _HeaderBanner extends StatefulWidget {
  final List<SchedulePlan> schedules;
  const _HeaderBanner({required this.schedules});

  @override
  State<_HeaderBanner> createState() => _HeaderBannerState();
}

class _HeaderBannerState extends State<_HeaderBanner> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.schedules.length + 1;
    return SizedBox(
      height: 290,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) => index == 0
                ? const _PaintingBannerPage()
                : _ScheduleBannerPage(schedule: widget.schedules[index - 1]),
          ),
          if (count > 1)
            Positioned(
              bottom: 7,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < count; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _page == index ? 17 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _page == index ? AppColors.mustard : AppColors.muted.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 8,
            child: IconButton(
              tooltip: 'الصفحة الرئيسية',
              icon: const Icon(Icons.home_outlined, color: AppColors.cream),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: Builder(
              builder: (context) => IconButton(
                tooltip: 'القائمة',
                icon: const Icon(Icons.menu, color: AppColors.cream),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaintingBannerPage extends StatelessWidget {
  const _PaintingBannerPage();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/header.jpg', fit: BoxFit.cover, alignment: const Alignment(-0.2, 0)),
      Positioned(top: 0, left: 0, right: 0, height: 100, child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.bg, AppColors.bg.withValues(alpha: 0)])),
      )),
      Positioned(bottom: 0, left: 0, right: 0, height: 140, child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.bg.withValues(alpha: 0), AppColors.bg])),
      )),
      Positioned(right: 20, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تحدياتي', style: Theme.of(context).textTheme.headlineMedium),
        Text('كل يوم خطوة', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
      ])),
    ],
  );
}

class _ScheduleBannerPage extends StatelessWidget {
  final SchedulePlan schedule;
  const _ScheduleBannerPage({required this.schedule});

  String _time(int minute, BuildContext context) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = schedule.containsDate(today) ? today : schedule.rangeStart;
    final entries = schedule.onDate(date);
    return Material(
      color: AppColors.bg,
      child: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => ScheduleDetailScreen(scheduleId: schedule.id)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/header.jpg', fit: BoxFit.cover, alignment: const Alignment(-0.2, 0)),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC221C19), Color(0xB3221C19), Color(0xF5221C19)]))),
            Positioned(
              right: 20,
              left: 20,
              top: MediaQuery.of(context).padding.top + 50,
              bottom: 26,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.calendar_month, color: AppColors.mustard),
                  const SizedBox(width: 8),
                  Expanded(child: Text(schedule.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge)),
                  Text(schedule.period.label, style: const TextStyle(color: AppColors.tealLight, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(_arabicBannerDate(date), style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Expanded(child: Center(child: Text('اليوم ده فاضي في جدولك\nاضغط عشان تشوف جدولك كامل', textAlign: TextAlign.center, style: TextStyle(color: AppColors.cream, height: 1.8))))
                else ...[
                  Text('${entries.length} ${entries.length == 1 ? 'موعد' : 'مواعيد'} اليوم', style: const TextStyle(color: AppColors.cream)),
                  const SizedBox(height: 8),
                  for (final entry in entries.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(children: [
                        const Icon(Icons.circle, size: 7, color: AppColors.terracotta),
                        const SizedBox(width: 8),
                        Text('${_time(entry.startMinute, context)}  ', style: const TextStyle(color: AppColors.mustard, fontWeight: FontWeight.w700)),
                        Expanded(child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  if (entries.length > 2)
                    Text('+${entries.length - 2} مواعيد أخرى · اضغط لعرض اليوم كاملًا', style: const TextStyle(color: AppColors.tealLight)),
                  const Spacer(),
                  const Align(alignment: Alignment.centerLeft, child: Icon(Icons.open_in_full, size: 18, color: AppColors.mustard)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

String _arabicBannerDate(DateTime date) {
  const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback onLog;
  final VoidCallback onFinish;
  final VoidCallback onDelete;

  const _ChallengeCard({
    super.key,
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
                          '${c.neededPerDay}–${c.neededMaxPerDay} يوميًا حاليًا',
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
                                'المتوسط اليومي الجديد: ${c.neededPerDay}–${c.neededMaxPerDay} ${c.unit}',
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
            item(
              Icons.calendar_month_outlined,
              'جداولي',
              onTap: () => _openScreen(context, const ScheduleManagerScreen()),
            ),
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
          ],
        ),
      ),
    );
  }
}
