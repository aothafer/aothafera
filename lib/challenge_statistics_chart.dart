import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// رسم شموع يومية مستوحى من مخططات السوق؛ كل شمعة تقارن إنجاز يوم بالذي قبله.
class ChallengeStatisticsChart extends StatelessWidget {
  final List<Challenge> challenges;
  final int targetMax;
  final String unit;
  final Color accent;

  const ChallengeStatisticsChart({
    super.key,
    required this.challenges,
    required this.targetMax,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (challenges.isEmpty) return const SizedBox.shrink();
    final starts =
        challenges.map((c) => DateUtils.dateOnly(c.startDate)).toList()..sort();
    final ends = challenges.map((c) => DateUtils.dateOnly(c.endDate)).toList()
      ..sort();
    final start = starts.first;
    final latestEnd = ends.last;
    final end = today.isBefore(latestEnd) ? today : latestEnd;
    if (end.isBefore(start)) {
      return _chartFrame(context, 0, 'يظهر الرسم بعد بداية التحدي', []);
    }
    final count = math.min(30, end.difference(start).inDays + 1).toInt();
    final first = end.subtract(Duration(days: count - 1));
    final values = List<int>.filled(count, 0);
    final raw = List<List<int>>.generate(count, (_) => <int>[]);
    for (final c in challenges) {
      for (final log in c.logs) {
        final day = DateUtils.dateOnly(log.date);
        if (day.isBefore(first) || day.isAfter(end)) continue;
        final index = day.difference(first).inDays;
        values[index] += log.amount;
        raw[index].add(log.amount);
      }
    }
    final best = values.fold<int>(0, (a, b) => a > b ? a : b);
    final pct = targetMax <= 0 ? 0 : (best * 100 / targetMax).round();
    final subtitle = 'أعلى إنجاز يومي: $best $unit · $pct٪ من الحد الأقصى';
    return _chartFrame(context, count, subtitle, [
      _CandleData(
        day: first,
        open: 0,
        close: values.first,
        high: values.first > raw.first.fold<int>(0, (a, b) => a > b ? a : b)
            ? values.first
            : raw.first.fold<int>(0, (a, b) => a > b ? a : b),
        low: 0,
      ),
      for (var i = 1; i < count; i++)
        _CandleData(
          day: first.add(Duration(days: i)),
          open: values[i - 1],
          close: values[i],
          high: [
            values[i - 1],
            values[i],
            ...raw[i],
          ].fold<int>(0, (a, b) => a > b ? a : b),
          low: values[i - 1] < values[i] ? values[i - 1] : values[i],
        ),
    ]);
  }

  Widget _chartFrame(
    BuildContext context,
    int days,
    String subtitle,
    List<_CandleData> candles,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.candlestick_chart, color: accent),
              const SizedBox(width: 8),
              Text(
                'إنجازك اليومي',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            days == 0 ? subtitle : '$subtitle · آخر $days يوم',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: candles.isEmpty
                ? Center(
                    child: Text(
                      'سجّل إنجازك ليظهر الرسم هنا',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  )
                : CustomPaint(
                    painter: _CandlestickPainter(
                      candles: candles,
                      grid: AppColors.track,
                      positive: AppColors.tealLight,
                      negative: AppColors.rose,
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CandleData {
  final DateTime day;
  final int open, close, high, low;
  const _CandleData({
    required this.day,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
  });
}

class _CandlestickPainter extends CustomPainter {
  final List<_CandleData> candles;
  final Color grid, positive, negative;
  const _CandlestickPainter({
    required this.candles,
    required this.grid,
    required this.positive,
    required this.negative,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.isEmpty) return;
    const left = 38.0, right = 4.0, top = 8.0, bottom = 28.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = math
        .max(1, candles.fold<int>(0, (v, c) => v > c.high ? v : c.high))
        .toDouble();
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: .7)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: AppColors.muted, fontSize: 10);
    for (var line = 0; line < 4; line++) {
      final y = plot.top + plot.height * line / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = (maxValue * (3 - line) / 3).round().toString();
      _text(canvas, value, Offset(0, y - 6), labelStyle, 32);
    }
    final step = plot.width / candles.length;
    final bodyWidth = math.max(2.0, math.min(12.0, step * .55)).toDouble();
    double yFor(double value) =>
        (plot.bottom - (value / maxValue).clamp(0.0, 1.0) * plot.height)
            .toDouble();
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      // عرض الأيام من الأقدم يسارًا إلى الأحدث يمينًا.
      final x = plot.left + step * (i + .5);
      final color = c.close >= c.open ? positive : negative;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(x, yFor(c.high.toDouble())),
        Offset(x, yFor(c.low.toDouble())),
        paint,
      );
      final openY = yFor(c.open.toDouble()), closeY = yFor(c.close.toDouble());
      final rect = Rect.fromLTRB(
        x - bodyWidth / 2,
        math.min(openY, closeY),
        x + bodyWidth / 2,
        math.max(openY, closeY),
      );
      canvas.drawRect(
        rect.height < 2 ? rect.inflate(0).translate(0, -1) : rect,
        Paint()..color = color,
      );
    }
    final dates = <int>{0, candles.length ~/ 2, candles.length - 1};
    for (final i in dates) {
      final c = candles[i];
      final x = plot.left + step * (i + .5);
      _text(
        canvas,
        '${c.day.day}/${c.day.month}',
        Offset(x - 22, plot.bottom + 7),
        labelStyle,
        44,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style,
    double width,
  ) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: width);
    p.paint(canvas, Offset(at.dx + (width - p.width) / 2, at.dy));
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter old) =>
      old.candles != candles ||
      old.grid != grid ||
      old.positive != positive ||
      old.negative != negative;
}
