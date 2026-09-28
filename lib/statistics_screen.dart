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
    final own =
        AppColors.challengeColors[c.colorIndex % AppColors.challengeColors.length];
    return c.status == ChallengeStatus.completed ? AppColors.tealLight : own;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final groups = provider.groups;
    final ungrouped =
        provider.challenges.where((c) => c.groupId == null).toList();

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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (groups.isNotEmpty) ...[
                  Text('المجموعات', style: Theme.of(context).textTheme.titleMedium),
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
                  Text('تحديات منفردة',
                      style: Theme.of(context).textTheme.titleMedium),
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
    final progress =
        totalTarget == 0 ? 0.0 : (totalDone / totalTarget).clamp(0.0, 1.0);
    final completedCount =
        challenges.where((c) => c.status == ChallengeStatus.completed).length;

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
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
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
            style: Theme.of(context)
                .textTheme
                .bodySmall
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.title, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              '${(c.progress * 100).round()}٪',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
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
        child: Row(
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
                  Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${c.totalDone} / ${c.targetMin} ${c.unit}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
