import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_challenge_screen.dart';
import 'challenge_provider.dart';
import 'models.dart';
import 'theme.dart';

/// شيت التفاصيل: يُفتح عند الضغط على بطاقة التحدي
void showChallengeDetail(BuildContext context, Challenge c, Color accent) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _DetailSheet(challenge: c, accent: accent),
  );
}

class _DetailSheet extends StatelessWidget {
  final Challenge challenge;
  final Color accent;

  const _DetailSheet({required this.challenge, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final textTheme = Theme.of(context).textTheme;
    final group = context.watch<ChallengeProvider>().groupById(c.groupId);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted)),
              Text(value, style: textTheme.titleMedium),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.track,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: textTheme.titleLarge),
                      if (group != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'ضمن مجموعة: ${group.title}',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'تعديل التحدي',
                  onPressed: () {
                    Navigator.pop(context); // إغلاق الشيت أولًا
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddChallengeScreen(editing: c),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${c.totalDone} / ${c.targetMin} ${c.unit}'
              '${c.targetMax > c.targetMin ? ' (أقصى ${c.targetMax})' : ''}',
              style: textTheme.titleMedium?.copyWith(color: accent),
            ),
            const Divider(height: 28),
            row('إجمالي مدة التحدي', '${c.totalDays} يوم'),
            row('المدة المنصرمة', '${c.daysElapsed} يوم'),
            row('ما تبقى من مدة الهدف', '${c.daysLeft} يوم'),
            row('الحد الأدنى المطلوب', '${c.targetMin} ${c.unit}'),
            if (c.targetMax > c.targetMin)
              row('الحد الأقصى', '${c.targetMax} ${c.unit}'),
            row('متوسطك يوميًا لإنجاز التحدي',
                '${c.averagePerDay.toStringAsFixed(1)} ${c.unit}'),
            if (c.remaining > 0)
              row('كل ما تحتاجه حتى تصل', '${c.neededPerDay} ${c.unit}'),
            const SizedBox(height: 8),
            if (c.reminder.enabled)
              Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    c.reminder.sameTimeEveryDay
                        ? 'تنبيه يومي الساعة ${c.reminder.defaultTime.format(context)}'
                        : 'تنبيه بأوقات مخصصة لكل يوم',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
