import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'notification_service.dart';

/// Keeps challenges locally on this device and notifies the UI about changes.
class ChallengeProvider extends ChangeNotifier {
  final List<Challenge> _challenges = [];
  final List<Group> _groups = [];
  Future<void> _writeQueue = Future<void>.value();
  int _nextColor = 0;
  int _nextGroupId = 0;

  List<Challenge> get challenges => List.unmodifiable(_challenges);
  List<Group> get groups => List.unmodifiable(_groups);
  List<Challenge> get visibleChallenges =>
      _challenges.where((c) => c.status != ChallengeStatus.completed).toList();
  List<Challenge> get completedChallenges =>
      _challenges.where((c) => c.status == ChallengeStatus.completed).toList();

  Future<File> get _dataFile async => File(
    '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}challenge_data.json',
  );

  /// Load saved state before showing the app, then restore its scheduled reminders.
  Future<void> load() async {
    try {
      final file = await _dataFile;
      if (!await file.exists()) return;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _challenges
        ..clear()
        ..addAll(
          (data['challenges'] as List<dynamic>? ?? []).map(
            (item) => Challenge.fromJson(item as Map<String, dynamic>),
          ),
        );
      _groups
        ..clear()
        ..addAll(
          (data['groups'] as List<dynamic>? ?? []).map(
            (item) => Group.fromJson(item as Map<String, dynamic>),
          ),
        );
      _nextColor = _challenges.fold<int>(
        0,
        (max, c) => c.colorIndex >= max ? c.colorIndex + 1 : max,
      );
      _nextGroupId = _groups.length;
      for (final challenge in _challenges.where((c) => c.reminder.enabled)) {
        await NotificationService.instance.scheduleForChallenge(challenge);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not load saved challenge data: $error\n$stackTrace');
    }
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'challenges': _challenges.map((c) => c.toJson()).toList(),
      'groups': _groups.map((g) => g.toJson()).toList(),
    });
    _writeQueue = _writeQueue.catchError((Object _) {}).then((_) async {
      final file = await _dataFile;
      await file.writeAsString(snapshot, flush: true);
    });
    return _writeQueue;
  }

  Group? groupById(String? id) {
    if (id == null) return null;
    for (final group in _groups) {
      if (group.id == id) return group;
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
    unawaited(
      _persist().catchError((Object error) {
        debugPrint('Could not save group: $error');
      }),
    );
    return group;
  }

  Future<ReminderScheduleResult> addChallenge({
    required String title,
    required String unit,
    required int targetMin,
    required int targetMax,
    required DateTime startDate,
    required DateTime endDate,
    ReminderSettings reminder = const ReminderSettings(),
    String? groupId,
  }) async {
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
    notifyListeners();
    await _persist();
    return NotificationService.instance.scheduleForChallenge(challenge);
  }

  /// Keeps progress and color when updating, and persists before rescheduling.
  Future<ReminderScheduleResult> updateChallenge(
    String id, {
    required String title,
    required String unit,
    required int targetMin,
    required int targetMax,
    required DateTime startDate,
    required DateTime endDate,
    required ReminderSettings reminder,
    String? groupId,
  }) async {
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
    notifyListeners();
    await _persist();
    return NotificationService.instance.scheduleForChallenge(challenge);
  }

  void addLog(String challengeId, int amount) {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    challenge.logs.add(LogEntry(date: DateTime.now(), amount: amount));
    notifyListeners();
    unawaited(
      _persist().catchError((Object error) {
        debugPrint('Could not save challenge progress: $error');
      }),
    );
  }

  void removeChallenge(String challengeId) {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    unawaited(NotificationService.instance.cancelForChallenge(challenge));
    _challenges.removeWhere((c) => c.id == challengeId);
    notifyListeners();
    unawaited(
      _persist().catchError((Object error) {
        debugPrint('Could not save challenge removal: $error');
      }),
    );
  }
}
