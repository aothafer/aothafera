import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'challenge_detail_sheet.dart';
import 'challenge_provider.dart';
import 'models.dart';
import 'theme.dart';

/// قائمة التحديات التي أُنجزت، ويُفتح تفصيلها بالضغط عليها كما في
/// الشاشة الرئيسية.
class CompletedChallengesScreen extends StatelessWidget {
  const CompletedChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final completed = context.watch<ChallengeProvider>().completedChallenges;

    return Scaffold(
      appBar: AppBar(title: const Text('التحديات المنتهية')),
      body: completed.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'لا توجد تحديات منتهية بعد',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: completed.length,
              itemBuilder: (context, index) {
                final c = completed[index];
                return _CompletedTile(challenge: c);
              },
            ),
    );
  }
}

class _CompletedTile extends StatelessWidget {
  final Challenge challenge;

  const _CompletedTile({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    return InkWell(
      onTap: () => showChallengeDetail(context, c, AppColors.tealLight),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.tealLight.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              c.status == ChallengeStatus.completed
                  ? Icons.emoji_events_outlined
                  : Icons.flag_outlined,
              color: c.status == ChallengeStatus.completed
                  ? AppColors.tealLight
                  : AppColors.rose,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    c.status == ChallengeStatus.completed
                        ? '${c.totalDone} / ${c.targetMax} ${c.unit} — منجز'
                        : 'انتهت المدة قبل بلوغ الحد الأدنى (${c.targetMin} ${c.unit})',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.tealLight),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
