import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'notification_service.dart';

/// بيشيل قايمة التحديات والمجموعات، وأي تغيير فيهم بيبلّغ الشاشات
/// تتحدث تلقائي. (في مرحلة الحساب هنبدّل الـ Lists دي بـ Firestore)
class ChallengeProvider extends ChangeNotifier {
  final List<Challenge> _challenges = [];
  final List<Group> _groups = [];
  int _nextColor = 0; // كل تحدي جديد ياخد اللون اللي بعده
  int _nextGroupId = 0;

  List<Challenge> get challenges => List.unmodifiable(_challenges);
  List<Group> get groups => List.unmodifiable(_groups);

  /// التحديات النشطة أو الفاشلة، أي كل شيء عدا المُنجَز، وهي التي
  /// تظهر في الشاشة الرئيسية.
  List<Challenge> get visibleChallenges => _challenges
      .where((c) => c.status != ChallengeStatus.completed)
      .toList();

  /// التحديات التي أُنجزت، وتظهر في قسم منفصل.
  List<Challenge> get completedChallenges => _challenges
      .where((c) => c.status == ChallengeStatus.completed)
      .toList();

  Group? groupById(String? id) {
    if (id == null) return null;
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<Challenge> challengesInGroup(String groupId) =>
      _challenges.where((c) => c.groupId == groupId).toList();

  Group addGroup(String title) {
    final group = Group(
      id: 'g${_nextGroupId++}_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
    );
    _groups.add(group);
    notifyListeners();
    return group;
  }

  void addChallenge({
    required String title,
    required String unit,
    required int targetMin,
    required int targetMax,
    required DateTime startDate,
    required DateTime endDate,
    ReminderSettings reminder = const ReminderSettings(),
    String? groupId,
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
      groupId: groupId,
    );
    _challenges.add(challenge);
    // جدولة الإشعارات بتحصل في الخلفية من غير ما نستنّاها عشان مش
    // محتاجين نأخّر إضافة التحدي على شاشة المستخدم.
    unawaited(NotificationService.instance.scheduleForChallenge(challenge));
    notifyListeners();
  }

  /// تعديل تحدٍ موجود. بيحافظ على نفس الكائن (فسجلّ تقدمه ولونه
  /// يفضلوا كما هم)، وبيعيد جدولة تنبيهاته من جديد.
  void updateChallenge(
    String id, {
    required String title,
    required String unit,
    required int targetMin,
    required int targetMax,
    required DateTime startDate,
    required DateTime endDate,
    required ReminderSettings reminder,
    String? groupId,
  }) {
    final challenge = _challenges.firstWhere((c) => c.id == id);
    challenge
      ..title = title
      ..unit = unit
      ..targetMin = targetMin
      ..targetMax = targetMax
      ..startDate = startDate
      ..endDate = endDate
      ..reminder = reminder
      ..groupId = groupId;

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
