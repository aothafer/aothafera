import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'challenge_detail_sheet.dart';
import 'challenge_provider.dart';
import 'models.dart';
import 'theme.dart';

/// شاشة الإحصائيات: إحصائية مجمّعة لكل مجموعة، وإحصائية منفردة لكل
/// تحدٍ لا ينتمي إلى مجموعة.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  Color _accentOf(Challenge c) {
    final own = AppColors
        .challengeColors[c.colorIndex % AppColors.challengeColors.length];
    return c.status == ChallengeStatus.completed ? AppColors.tealLight : own;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final groups = provider.groups;
    final ungrouped = provider.challenges
        .where((c) => c.groupId == null)
        .toList();

    final hasContent = groups.isNotEmpty || ungrouped.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: !hasContent
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'لا توجد بيانات كافية بعد، ابدأ بإنشاء تحدٍ لترى إحصائياتك',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (groups.isNotEmpty) ...[
                  Text(
                    'المجموعات',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final g in groups)
                    _GroupStatCard(
                      group: g,
                      challenges: provider.challengesInGroup(g.id),
                      accentOf: _accentOf,
                    ),
                  const SizedBox(height: 20),
                ],
                if (ungrouped.isNotEmpty) ...[
                  Text(
                    'تحديات منفردة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final c in ungrouped)
                    _ChallengeStatTile(challenge: c, accent: _accentOf(c)),
                ],
              ],
            ),
    );
  }
}

class _GroupStatCard extends StatelessWidget {
  final Group group;
  final List<Challenge> challenges;
  final Color Function(Challenge) accentOf;

  const _GroupStatCard({
    required this.group,
    required this.challenges,
    required this.accentOf,
  });

  @override
  Widget build(BuildContext context) {
    final totalTarget = challenges.fold<int>(0, (s, c) => s + c.targetMin);
    final totalDone = challenges.fold<int>(0, (s, c) => s + c.totalDone);
    final progress = totalTarget == 0
        ? 0.0
        : (totalDone / totalTarget).clamp(0.0, 1.0);
    final completedCount = challenges
        .where((c) => c.status == ChallengeStatus.completed)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mustard.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(group.title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                '$completedCount / ${challenges.length} مُنجَز',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.track,
              valueColor: const AlwaysStoppedAnimation(AppColors.mustard),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalDone من $totalTarget إجمالًا',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          for (final c in challenges)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MiniChallengeRow(challenge: c, accent: accentOf(c)),
            ),
        ],
      ),
    );
  }
}

class _MiniChallengeRow extends StatelessWidget {
  final Challenge challenge;
  final Color accent;

  const _MiniChallengeRow({required this.challenge, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    return InkWell(
      onTap: () => showChallengeDetail(context, c, accent),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${(c.progress * 100).round()}٪',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DailyActivityChart(challenge: c, color: accent),
          ],
        ),
      ),
    );
  }
}

class _ChallengeStatTile extends StatelessWidget {
  final Challenge challenge;
  final Color accent;

  const _ChallengeStatTile({required this.challenge, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    return InkWell(
      onTap: () => showChallengeDetail(context, c, accent),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: c.progress,
                        strokeWidth: 5,
                        backgroundColor: AppColors.track,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                      Center(
                        child: Text(
                          '${(c.progress * 100).round()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${c.totalDone} من ${c.targetMin}–${c.targetMax} ${c.unit}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: accent),
                      ),
                      Text(
                        'المعدل اليومي ${c.dailyTargetMin}–${c.dailyTargetMax} ${c.unit}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DailyActivityChart(challenge: c, color: accent),
          ],
        ),
      ),
    );
  }
}

/// Stock-style line plot of the amount completed each day. Each challenge
/// keeps its own accent color; the dashed lines mark its daily target range.
class DailyActivityChart extends StatelessWidget {
  final Challenge challenge;
  final Color color;

  const DailyActivityChart({
    super.key,
    required this.challenge,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(challenge.startDate);
    final end = DateUtils.dateOnly(challenge.endDate);
    final lastDay = today.isBefore(end) ? today : end;
    if (lastDay.isBefore(start)) {
      return Container(
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'يظهر الرسم بعد بداية التحدي',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
      );
    }

    final visibleDays = math
        .min(30, lastDay.difference(start).inDays + 1)
        .toInt();
    final firstDay = lastDay.subtract(Duration(days: visibleDays - 1));
    final dailyAmounts = List<int>.filled(visibleDays, 0);
    for (final log in challenge.logs) {
      final date = DateUtils.dateOnly(log.date);
      if (date.isBefore(firstDay) || date.isAfter(lastDay)) continue;
      dailyAmounts[date.difference(firstDay).inDays] += log.amount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إنجازك اليومي · آخر $visibleDays يوم',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Container(
          height: 92,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bg.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: _DailyActivityPainter(
              values: dailyAmounts,
              minTarget: challenge.dailyTargetMin.toDouble(),
              maxTarget: challenge.dailyTargetMax.toDouble(),
              color: color,
              gridColor: AppColors.track,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _DailyActivityPainter extends CustomPainter {
  final List<int> values;
  final double minTarget;
  final double maxTarget;
  final Color color;
  final Color gridColor;

  const _DailyActivityPainter({
    required this.values,
    required this.minTarget,
    required this.maxTarget,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    final bounds = Rect.fromLTWH(1, 2, size.width - 2, size.height - 4);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    for (var line = 0; line < 4; line++) {
      final y = bounds.top + bounds.height * line / 3;
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        gridPaint,
      );
    }

    final scale = math
        .max(
          1.0,
          math.max(
            values.reduce((a, b) => a > b ? a : b).toDouble(),
            maxTarget,
          ),
        )
        .toDouble();
    double yFor(double value) =>
        bounds.bottom - (value / scale).clamp(0.0, 1.0) * bounds.height;
    final targetPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
      canvas,
      bounds.left,
      bounds.right,
      yFor(minTarget),
      targetPaint,
    );
    _drawDashedLine(
      canvas,
      bounds.left,
      bounds.right,
      yFor(maxTarget),
      targetPaint,
    );

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? bounds.center.dx
          : bounds.left + bounds.width * i / (values.length - 1);
      points.add(Offset(x, yFor(values[i].toDouble())));
    }
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, bounds.bottom)
      ..lineTo(points.first.dx, bounds.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    if (points.length <= 12) {
      final pointPaint = Paint()..color = color;
      for (final point in points) {
        canvas.drawCircle(point, 2.4, pointPaint);
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    double left,
    double right,
    double y,
    Paint paint,
  ) {
    const dashWidth = 5.0;
    const gap = 4.0;
    for (var x = left; x < right; x += dashWidth + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, right).toDouble(), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DailyActivityPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.minTarget != minTarget ||
      oldDelegate.maxTarget != maxTarget ||
      oldDelegate.color != color;
}
