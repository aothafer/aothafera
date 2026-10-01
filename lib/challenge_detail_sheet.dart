import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_challenge_screen.dart';
import 'challenge_provider.dart';
import 'challenge_statistics_chart.dart';
import 'models.dart';
import 'theme.dart';

/// صفحة الإحصائيات التفصيلية، تُفتح من قائمة الإحصائيات فقط.
void showChallengeDetail(BuildContext context, Challenge c, Color accent) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ChallengeDetailScreen(challenge: c, accent: accent),
    ),
  );
}

/// تفاصيل سريعة كما كانت في بطاقات مرمى الهدف.
void showChallengeSummarySheet(
  BuildContext context,
  Challenge c,
  Color accent,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ChallengeSummarySheet(
      challenge: c,
      accent: accent,
      parentContext: context,
    ),
  );
}

void showGroupStatistics(
  BuildContext context,
  Group group,
  List<Challenge> challenges,
  Color accent,
) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => GroupStatisticsScreen(
        group: group,
        challenges: challenges,
        accent: accent,
      ),
    ),
  );
}

class ChallengeDetailScreen extends StatelessWidget {
  final Challenge challenge;
  final Color accent;

  const ChallengeDetailScreen({
    super.key,
    required this.challenge,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final c = provider.challenges.firstWhere(
      (x) => x.id == challenge.id,
      orElse: () => challenge,
    );
    final group = provider.groupById(c.groupId);
    final remainingMax = math.max(0, c.targetMax - c.totalDone);
    final status = switch (c.status) {
      ChallengeStatus.active => 'مستمر',
      ChallengeStatus.completed => 'مكتمل',
      ChallengeStatus.failed => 'انتهت المدة',
    };
    final details = <(String, String)>[
      ('الحالة', status),
      if (group != null) ('المجموعة', group.title),
      ('الحد الأدنى الكلي', '${c.targetMin} ${c.unit}'),
      ('الحد الأقصى الكلي', '${c.targetMax} ${c.unit}'),
      ('الحد الأدنى اليومي', '${c.dailyTargetMin} ${c.unit}'),
      ('الحد الأقصى اليومي', '${c.dailyTargetMax} ${c.unit}'),
      ('أنجزت حتى الآن', '${c.totalDone} ${c.unit}'),
      ('المتبقي للحد الأدنى', '${c.remaining} ${c.unit}'),
      ('المتبقي للحد الأقصى', '$remainingMax ${c.unit}'),
      ('مدة التحدي', '${c.totalDays} يوم'),
      ('الأيام المتبقية', '${c.daysLeft} يوم'),
      (
        'حد تسجيل إنجاز اليوم (20٪ من الحد الأدنى اليومي)',
        '${c.minimumDailyCheckIn} ${c.unit}',
      ),
      ('متوسط بلوغ الحد الأدنى الكلي يوميًا', '${c.neededPerDay} ${c.unit}'),
      ('نسبة الإنجاز من الحد الأقصى', '${(c.progress * 100).round()}٪'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(c.title),
        actions: [
          IconButton(
            tooltip: 'تعديل التحدي',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AddChallengeScreen(editing: c),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          ChallengeStatisticsChart(
            challenges: [c],
            targetMax: c.targetMax,
            unit: c.unit,
            accent: accent,
          ),
          const SizedBox(height: 20),
          Text('تفاصيل التحدي', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _DetailsCard(rows: details, accent: accent),
        ],
      ),
    );
  }
}

class GroupStatisticsScreen extends StatelessWidget {
  final Group group;
  final List<Challenge> challenges;
  final Color accent;
  const GroupStatisticsScreen({
    super.key,
    required this.group,
    required this.challenges,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final items = provider.challengesInGroup(group.id);
    final current = items.isEmpty ? challenges : items;
    final min = current.fold<int>(0, (sum, c) => sum + c.targetMin);
    final max = current.fold<int>(0, (sum, c) => sum + c.targetMax);
    final done = current.fold<int>(0, (sum, c) => sum + c.totalDone);
    final unit = current.map((c) => c.unit).toSet().length == 1
        ? current.first.unit
        : 'وحدة';
    final rows = <(String, String)>[
      ('عدد التحديات', '${current.length}'),
      ('الحد الأدنى الكلي', '$min $unit'),
      ('الحد الأقصى الكلي', '$max $unit'),
      ('أنجزت حتى الآن', '$done $unit'),
      ('المتبقي للحد الأدنى', '${math.max(0, min - done)} $unit'),
      ('المتبقي للحد الأقصى', '${math.max(0, max - done)} $unit'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(group.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ChallengeStatisticsChart(
            challenges: current,
            targetMax: max,
            unit: unit,
            accent: accent,
          ),
          const SizedBox(height: 20),
          Text(
            'تفاصيل المجموعة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _DetailsCard(rows: rows, accent: accent),
          const SizedBox(height: 18),
          for (final c in current)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(c.title),
              subtitle: Text(
                '${c.totalDone} من ${c.targetMin}–${c.targetMax} ${c.unit}',
              ),
              trailing: Text('${(c.progress * 100).round()}٪'),
              onTap: () => showChallengeDetail(context, c, accent),
            ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<(String, String)> rows;
  final Color accent;
  const _DetailsCard({required this.rows, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: AppColors.cream),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ChallengeSummarySheet extends StatelessWidget {
  final Challenge challenge;
  final Color accent;
  final BuildContext parentContext;
  const _ChallengeSummarySheet({
    required this.challenge,
    required this.accent,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final c = provider.challenges.firstWhere(
      (x) => x.id == challenge.id,
      orElse: () => challenge,
    );
    final group = provider.groupById(c.groupId);
    final status = switch (c.status) {
      ChallengeStatus.active => 'مستمر',
      ChallengeStatus.completed => 'مكتمل',
      ChallengeStatus.failed => 'انتهت المدة',
    };
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push<void>(
                        parentContext,
                        MaterialPageRoute<void>(
                          builder: (_) => AddChallengeScreen(editing: c),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (group != null)
                Text(
                  group.title,
                  style: const TextStyle(color: AppColors.muted),
                ),
              const SizedBox(height: 10),
              Text(
                '${c.totalDone} / ${c.targetMax} ${c.unit}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: accent),
              ),
              Text(
                'الهدف اليومي: ${c.dailyTargetMin}–${c.dailyTargetMax} ${c.unit}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const Divider(height: 26),
              row('الحالة', status),
              row('إجمالي مدة التحدي', '${c.totalDays} يوم'),
              row('المدة المنقضية', '${c.daysElapsed} يوم'),
              row('المتبقي من المدة', '${c.daysLeft} يوم'),
              row('الحد الأدنى المطلوب', '${c.targetMin} ${c.unit}'),
              row('الحد الأقصى المطلوب', '${c.targetMax} ${c.unit}'),
              row(
                'متوسط بلوغ الحد الأدنى الكلي يوميًا',
                '${c.neededPerDay} ${c.unit}',
              ),
              row(
                'كل ما تحتاجه لتسجيل إنجاز اليوم (20٪)',
                '${c.minimumDailyCheckIn} ${c.unit}',
              ),
              if (c.reminder.enabled)
                row(
                  'موعد التنبيه اليومي',
                  c.reminder.defaultTime.format(context),
                ),
              if (c.reminder.enabled && c.reminder.perDayTimes.isNotEmpty)
                row(
                  'مواعيد الأيام المخصصة',
                  '${c.reminder.perDayTimes.length} يوم',
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
