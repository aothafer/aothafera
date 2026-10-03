import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'challenge_detail_sheet.dart';
import 'challenge_provider.dart';
import 'models.dart';
import 'theme.dart';

/// قائمة موجزة للتحديات والمجموعات؛ فتح التفاصيل يتم بالضغط على العنصر.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  Color _accentOf(Challenge c) => c.status == ChallengeStatus.completed
      ? AppColors.tealLight
      : AppColors.challengeColors[c.colorIndex %
            AppColors.challengeColors.length];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final groups = provider.groups;
    final ungrouped = provider.challenges
        .where((c) => c.groupId == null)
        .toList();
    final previewChallenge = _buildPreviewChallenge();
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(
                Icons.candlestick_chart,
                color: AppColors.mustard,
              ),
              title: const Text('معاينة الرسم البياني'),
              subtitle: const Text('بيانات تجريبية لـ30 يومًا — لا تُحفظ'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => showChallengeDetail(
                context,
                previewChallenge,
                AppColors.mustard,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty && ungrouped.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Text(
                'لا توجد بيانات تحديات بعد. ابدأ بإنشاء تحدٍ لترى إحصائياتك.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
          if (groups.isNotEmpty) ...[
            Text('المجموعات', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final group in groups)
              _ProgressItem(
                title: group.title,
                percent: _groupPercent(provider.challengesInGroup(group.id)),
                accent: AppColors.mustard,
                onTap: () => showGroupStatistics(
                  context,
                  group,
                  provider.challengesInGroup(group.id),
                  AppColors.mustard,
                ),
              ),
            const SizedBox(height: 18),
          ],
          if (ungrouped.isNotEmpty) ...[
            Text(
              'تحديات منفردة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final c in ungrouped)
              _ProgressItem(
                title: c.title,
                percent: (c.progress * 100).round(),
                accent: _accentOf(c),
                onTap: () => showChallengeDetail(context, c, _accentOf(c)),
              ),
          ],
        ],
      ),
    );
  }

  int _groupPercent(List<Challenge> challenges) {
    final maxTarget = challenges.fold<int>(0, (sum, c) => sum + c.targetMax);
    if (maxTarget == 0) return 0;
    final done = challenges.fold<int>(0, (sum, c) => sum + c.totalDone);
    return (done * 100 / maxTarget).round();
  }

  Challenge _buildPreviewChallenge() {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 29));
    const amounts = <int>[
      12,
      24,
      31,
      18,
      42,
      0,
      27,
      35,
      48,
      22,
      0,
      39,
      44,
      29,
      51,
      33,
      17,
      0,
      46,
      38,
      55,
      26,
      41,
      19,
      0,
      49,
      36,
      58,
      32,
      45,
    ];
    final challenge = Challenge(
      id: 'chart-preview-only',
      title: 'معاينة الرسم البياني',
      unit: 'صفحة',
      targetMin: 750,
      targetMax: 1500,
      dailyTargetMin: 25,
      dailyTargetMax: 50,
      startDate: start,
      endDate: today,
      colorIndex: 0,
    );
    for (var i = 0; i < amounts.length; i++) {
      if (amounts[i] == 0) continue;
      challenge.logs.add(
        LogEntry(
          date: start.add(Duration(days: i, hours: 12)),
          amount: amounts[i],
        ),
      );
    }
    return challenge;
  }
}

class _ProgressItem extends StatelessWidget {
  final String title;
  final int percent;
  final Color accent;
  final VoidCallback onTap;
  const _ProgressItem({
    required this.title,
    required this.percent,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '$percent٪',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: AppColors.track,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
