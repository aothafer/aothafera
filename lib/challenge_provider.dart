import 'package:flutter/foundation.dart';
import 'models.dart';

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
    _challenges.add(Challenge(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      unit: unit,
      targetMin: targetMin,
      targetMax: targetMax,
      startDate: startDate,
      endDate: endDate,
      colorIndex: _nextColor++,
      reminder: reminder,
    ));
    notifyListeners();
  }

  void addLog(String challengeId, int amount) {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    challenge.logs.add(LogEntry(date: DateTime.now(), amount: amount));
    notifyListeners();
  }

  void removeChallenge(String challengeId) {
    _challenges.removeWhere((c) => c.id == challengeId);
    notifyListeners();
  }
}
