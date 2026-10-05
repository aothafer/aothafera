import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'notification_service.dart';
import 'schedule_models.dart';

/// Keeps challenges locally on this device and notifies the UI about changes.
class ChallengeProvider extends ChangeNotifier {
  final List<Challenge> _challenges = [];
  final List<Group> _groups = [];
  final List<SchedulePlan> _schedules = [];
  Future<void> _writeQueue = Future<void>.value();
  Timer? _expirationTimer;
  int _nextColor = 0;
  int _nextGroupId = 0;

  List<Challenge> get challenges => List.unmodifiable(_challenges);
  List<Group> get groups => List.unmodifiable(_groups);
  List<SchedulePlan> get schedules => List.unmodifiable(_schedules);
  List<SchedulePlan> get homeSchedules =>
      _schedules.where((schedule) => schedule.showOnHome).toList();
  List<Challenge> get visibleChallenges =>
      _challenges.where((c) => c.status == ChallengeStatus.active).toList();
  List<Challenge> get completedChallenges =>
      _challenges.where((c) => c.status != ChallengeStatus.active).toList();

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
      _schedules
        ..clear()
        ..addAll(
          (data['schedules'] as List<dynamic>? ?? []).map(
            (item) => SchedulePlan.fromJson(item as Map<String, dynamic>),
          ),
        );
      _nextColor = _challenges.fold<int>(
        0,
        (max, c) => c.colorIndex >= max ? c.colorIndex + 1 : max,
      );
      _nextGroupId = _groups.length;
      for (final challenge in _challenges.where((c) => c.reminder.enabled)) {
        if (challenge.status == ChallengeStatus.active) {
          await NotificationService.instance.scheduleForChallenge(challenge);
        } else {
          await NotificationService.instance.cancelForChallenge(challenge);
        }
      }
      _scheduleExpirationCheck();
    } catch (error, stackTrace) {
      debugPrint('Could not load saved challenge data: $error\n$stackTrace');
    }
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'challenges': _challenges.map((c) => c.toJson()).toList(),
      'groups': _groups.map((g) => g.toJson()).toList(),
      'schedules': _schedules.map((schedule) => schedule.toJson()).toList(),
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

  Future<void> addSchedule(SchedulePlan schedule) async {
    _schedules.add(schedule);
    notifyListeners();
    await _persist();
  }

  Future<void> updateSchedule(SchedulePlan schedule) async {
    final index = _schedules.indexWhere((item) => item.id == schedule.id);
    if (index < 0) return;
    _schedules[index] = schedule;
    notifyListeners();
    await _persist();
  }

  Future<void> removeSchedule(String scheduleId) async {
    _schedules.removeWhere((schedule) => schedule.id == scheduleId);
    notifyListeners();
    await _persist();
  }

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
    required int dailyTargetMin,
    required int dailyTargetMax,
    required DateTime startDate,
    required DateTime endDate,
    ReminderSettings reminder = const ReminderSettings(),
    String? groupId,
  }) async {
    final days = _durationDays(startDate, endDate);
    final challenge = Challenge(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      unit: unit,
      targetMin: dailyTargetMin * days,
      targetMax: dailyTargetMax * days,
      dailyTargetMin: dailyTargetMin,
      dailyTargetMax: dailyTargetMax,
      startDate: startDate,
      endDate: endDate,
      colorIndex: _nextColor++,
      reminder: reminder,
      groupId: groupId,
    );
    _challenges.add(challenge);
    notifyListeners();
    _scheduleExpirationCheck();
    await _persist();
    return NotificationService.instance.scheduleForChallenge(challenge);
  }

  /// Keeps progress and color when updating, and persists before rescheduling.
  Future<ReminderScheduleResult> updateChallenge(
    String id, {
    required String title,
    required String unit,
    required int dailyTargetMin,
    required int dailyTargetMax,
    required DateTime startDate,
    required DateTime endDate,
    required ReminderSettings reminder,
    String? groupId,
  }) async {
    final challenge = _challenges.firstWhere((c) => c.id == id);
    final days = _durationDays(startDate, endDate);
    challenge
      ..title = title
      ..unit = unit
      ..targetMin = dailyTargetMin * days
      ..targetMax = dailyTargetMax * days
      ..dailyTargetMin = dailyTargetMin
      ..dailyTargetMax = dailyTargetMax
      ..startDate = startDate
      ..endDate = endDate
      ..reminder = reminder
      ..manuallyCompleted = false
      ..groupId = groupId;
    notifyListeners();
    _scheduleExpirationCheck();
    await _persist();
    return NotificationService.instance.scheduleForChallenge(challenge);
  }

  int _durationDays(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return (end.difference(start).inDays + 1).clamp(1, 1000000);
  }

  Future<void> addLog(String challengeId, int amount) async {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    challenge.logs.add(LogEntry(date: DateTime.now(), amount: amount));
    notifyListeners();
    _scheduleExpirationCheck();
    await _persist();
    if (challenge.status != ChallengeStatus.active) {
      await NotificationService.instance.cancelForChallenge(challenge);
    } else if (challenge.reminder.enabled) {
      // Recalculate the remaining daily range and replace future alarm/nudge
      // schedules using the newly logged progress.
      await NotificationService.instance.scheduleForChallenge(challenge);
    }
  }

  Future<bool> finishChallenge(String challengeId) async {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    if (challenge.status != ChallengeStatus.active ||
        challenge.totalDone < challenge.targetMin) {
      return false;
    }
    challenge.manuallyCompleted = true;
    notifyListeners();
    _scheduleExpirationCheck();
    await _persist();
    await NotificationService.instance.cancelForChallenge(challenge);
    return true;
  }

  void _scheduleExpirationCheck() {
    _expirationTimer?.cancel();
    final now = DateTime.now();
    final deadlines =
        _challenges
            .where((c) => c.status == ChallengeStatus.active)
            .map(
              (c) =>
                  DateTime(c.endDate.year, c.endDate.month, c.endDate.day + 1),
            )
            .where((deadline) => deadline.isAfter(now))
            .toList()
          ..sort();
    if (deadlines.isEmpty) return;

    final delay = deadlines.first.difference(now);
    _expirationTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      final justEnded = _challenges
          .where(
            (c) => c.status != ChallengeStatus.active && c.reminder.enabled,
          )
          .toList();
      notifyListeners();
      for (final challenge in justEnded) {
        unawaited(NotificationService.instance.cancelForChallenge(challenge));
      }
      _scheduleExpirationCheck();
    });
  }

  void removeChallenge(String challengeId) {
    final challenge = _challenges.firstWhere((c) => c.id == challengeId);
    unawaited(NotificationService.instance.cancelForChallenge(challenge));
    _challenges.removeWhere((c) => c.id == challengeId);
    notifyListeners();
    _scheduleExpirationCheck();
    unawaited(
      _persist().catchError((Object error) {
        debugPrint('Could not save challenge removal: $error');
      }),
    );
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }
}
