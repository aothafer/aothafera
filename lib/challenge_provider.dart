import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'notification_service.dart';

/// بيشيل قايمة التحديات، وأي تغيير فيها بيبلّغ الشاشات تتحدث تلقائي.
/// (في مرحلة الحساب هنبدّل الـ List دي بـ Firestore)
class ChallengeProvider extends ChangeNotifier {
  final List<Challenge> _challenges = [];
  int _nextColor = 0; // كل تحدي جديد ياخد اللون اللي بعده

  List<Challenge> get challenges => List.unmodifiable(_challenges);

  void addChallenge({
    required String title,
    required String unit,
    required int targetMin,
    required int targetMax,
    required DateTime startDate,
    required DateTime endDate,
    ReminderSettings reminder = const ReminderSettings(),
  }) {
    final challenge = Challenge(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      unit: unit,
      targetMin: targetMin,
      targetMax: targetMax,
      startDate: startDate,
      endDate: endDate,
      colorIndex: _nextColor++,
      reminder: reminder,
    );
    _challenges.add(challenge);
    // جدولة الإشعارات بتحصل في الخلفية من غير ما نستنّاها عشان مش
    // محتاجين نأخّر إضافة التحدي على شاشة المستخدم.
    unawaited(NotificationService.instance.scheduleForChallenge(challenge));
    notifyListeners();
  }

  void addLog(String challengeId, int amount) {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    challenge.logs.add(LogEntry(date: DateTime.now(), amount: amount));
    notifyListeners();
  }

  void removeChallenge(String challengeId) {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    unawaited(NotificationService.instance.cancelForChallenge(challenge));
    _challenges.removeWhere((c) => c.id == challengeId);
    notifyListeners();
  }
}
