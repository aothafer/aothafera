import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_challenge_screen.dart';
import 'challenge_provider.dart';
import 'models.dart';
import 'theme.dart';

/// Opens a dedicated details page for the selected challenge.
void showChallengeDetail(BuildContext context, Challenge c, Color accent) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ChallengeDetailScreen(challenge: c, accent: accent),
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
      (item) => item.id == challenge.id,
      orElse: () => challenge,
    );
    final group = provider.groupById(c.groupId);
    final textTheme = Theme.of(context).textTheme;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.titleSmall?.copyWith(color: AppColors.cream),
            ),
          ),
        ],
      ),
    );

    final remainingToMax = math.max(0, c.targetMax - c.totalDone);
    final statusLabel = switch (c.status) {
      ChallengeStatus.active => 'مستمر',
      ChallengeStatus.completed => 'مكتمل',
      ChallengeStatus.failed => 'انتهت المدة',
    };

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
          _DailyAchievementChart(challenge: c, accent: accent),
          const SizedBox(height: 20),
          Text('تفاصيل التحدي', style: textTheme.titleLarge),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                row('الحالة', statusLabel),
                if (group != null) row('المجموعة', group.title),
                row('الحد الأدنى الكلي', '${c.targetMin} ${c.unit}'),
                row('الحد الأقصى الكلي', '${c.targetMax} ${c.unit}'),
                row('الحد الأدنى اليومي', '${c.dailyTargetMin} ${c.unit}'),
                row('الحد الأقصى اليومي', '${c.dailyTargetMax} ${c.unit}'),
                row('أنجزت حتى الآن', '${c.totalDone} ${c.unit}'),
                row(
                  'المتبقي للوصول إلى الحد الأدنى',
                  '${c.remaining} ${c.unit}',
                ),
                row(
                  'المتبقي للوصول إلى الحد الأقصى',
                  '$remainingToMax ${c.unit}',
                ),
                row('مدة التحدي', '${c.totalDays} يوم'),
                row('الأيام المتبقية', '${c.daysLeft} يوم'),
                row(
                  'المطلوب يوميًا للوصول إلى الحد الأدنى',
                  '${c.neededPerDay} ${c.unit}',
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'الحساب: المتبقي للوصول إلى الحد الأدنى ÷ الأيام المتبقية.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 28),
                row(
                  'نسبة الإنجاز من الحد الأقصى',
                  '${(c.progress * 100).round()}٪',
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyAchievementChart extends StatelessWidget {
  final Challenge challenge;
  final Color accent;

  const _DailyAchievementChart({required this.challenge, required this.accent});

  String _formatDate(DateTime date) => '${date.day}/${date.month}';

  @override
  Widget build(BuildContext context) {
    final dailyTotals = <DateTime, int>{};
    for (final log in challenge.logs) {
      final date = DateUtils.dateOnly(log.date);
      if (date.isBefore(DateUtils.dateOnly(challenge.startDate)) ||
          date.isAfter(DateUtils.dateOnly(challenge.endDate))) {
        continue;
      }
      dailyTotals.update(
        date,
        (value) => value + log.amount,
        ifAbsent: () => log.amount,
      );
    }

    final ranked = dailyTotals.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : b.key.compareTo(a.key);
      });
    final displayed = ranked.take(8).toList();
    final best = ranked.isEmpty ? 0 : ranked.first.value;
    final bestPercent = challenge.targetMax == 0
        ? 0
        : (best * 100 / challenge.targetMax).round();
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('إنجازك اليومي', style: textTheme.titleMedium),
              ),
              if (ranked.isNotEmpty)
                Icon(Icons.arrow_upward, color: AppColors.tealLight, size: 21),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ranked.isEmpty
                ? 'سجّل إنجازك ليظهر هنا مرتّبًا من الأكبر إلى الأصغر.'
                : 'أعلى إنجاز: $best ${challenge.unit} · $bestPercent٪ من الحد الأقصى الكلي',
            style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          if (ranked.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < displayed.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RankedDayRow(
                  rank: index + 1,
                  date: displayed[index].key,
                  amount: displayed[index].value,
                  best: best,
                  targetMax: challenge.targetMax,
                  unit: challenge.unit,
                  accent: accent,
                  formatDate: _formatDate,
                ),
              ),
            if (ranked.length > displayed.length)
              Text(
                'يعرض الرسم أعلى ${displayed.length} أيام من ${ranked.length} أيام مسجّلة.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
          ],
        ],
      ),
    );
  }
}

class _RankedDayRow extends StatelessWidget {
  final int rank;
  final DateTime date;
  final int amount;
  final int best;
  final int targetMax;
  final String unit;
  final Color accent;
  final String Function(DateTime) formatDate;

  const _RankedDayRow({
    required this.rank,
    required this.date,
    required this.amount,
    required this.best,
    required this.targetMax,
    required this.unit,
    required this.accent,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final isBest = rank == 1;
    final fraction = best == 0 ? 0.0 : amount / best;
    final percent = targetMax == 0 ? 0 : (amount * 100 / targetMax).round();
    final color = isBest ? AppColors.tealLight : accent;

    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            '#$rank',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isBest ? color : AppColors.muted,
              fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.track,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amount $unit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isBest ? color : AppColors.cream,
                  fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '$percent٪ من الحد الأقصى',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
