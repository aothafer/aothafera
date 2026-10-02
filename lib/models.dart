import 'dart:math';

import 'package:flutter/material.dart' show DateUtils, TimeOfDay;

/// تسجيل واحد للتقدم: عدد الوحدات المنجزة في يوم معين
class LogEntry {
  final DateTime date;
  final int amount;

  LogEntry({required this.date, required this.amount});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'amount': amount,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    date: DateTime.parse(json['date'] as String),
    amount: json['amount'] as int,
  );
}

/// إعدادات التنبيه لتحدي واحد
class ReminderSettings {
  final bool enabled;

  final TimeOfDay defaultTime;

  /// وقت مخصص لكل يوم من أيام التحدي (المفتاح: رقم اليوم بداية من 0)
  final Map<int, TimeOfDay> perDayTimes;

  const ReminderSettings({
    this.enabled = false,
    this.defaultTime = const TimeOfDay(hour: 20, minute: 0),
    this.perDayTimes = const {},
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'defaultHour': defaultTime.hour,
    'defaultMinute': defaultTime.minute,
    'perDayTimes': perDayTimes.map(
      (day, time) => MapEntry('$day', [time.hour, time.minute]),
    ),
  };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    final legacySameTime = json['sameTimeEveryDay'] as bool?;
    final times = (json['perDayTimes'] as Map<String, dynamic>? ?? {}).map((
      day,
      value,
    ) {
      final parts = value as List<dynamic>;
      return MapEntry(
        int.parse(day),
        TimeOfDay(hour: parts[0] as int, minute: parts[1] as int),
      );
    });
    return ReminderSettings(
      enabled: json['enabled'] as bool? ?? false,
      defaultTime: TimeOfDay(
        hour: json['defaultHour'] as int? ?? 20,
        minute: json['defaultMinute'] as int? ?? 0,
      ),
      // Old versions retained hidden overrides after "same time every day"
      // was enabled. Do not unexpectedly activate those stale exceptions.
      perDayTimes: legacySameTime == true ? const <int, TimeOfDay>{} : times,
    );
  }

  ReminderSettings copyWith({
    bool? enabled,
    TimeOfDay? defaultTime,
    Map<int, TimeOfDay>? perDayTimes,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      defaultTime: defaultTime ?? this.defaultTime,
      perDayTimes: perDayTimes ?? this.perDayTimes,
    );
  }

  /// وقت التنبيه ليوم معين (رقم اليوم بداية من 0)
  TimeOfDay timeForDay(int dayIndex) {
    // The default is used every day; a per-day entry is an explicit override.
    return perDayTimes[dayIndex] ?? defaultTime;
  }
}

/// حالة التحدي، تُحسب دائمًا من بياناته، ولا تُخزَّن بشكل منفصل.
enum ChallengeStatus { active, completed, failed }

/// التحدي نفسه. كل الأرقام (المتبقي، النسبة...) بتتحسب من السجلات،
/// مش متخزنة، عشان تفضل دايمًا مظبوطة.
class Challenge {
  final String id;
  String title;
  String unit; // صفحة، صلاة، دقيقة...
  int targetMin;
  int targetMax;
  int dailyTargetMin;
  int dailyTargetMax;
  DateTime startDate;
  DateTime endDate;
  final int colorIndex; // بيحدد لون التحدي من لوحة الألوان
  ReminderSettings reminder;
  bool manuallyCompleted;

  /// معرّف المجموعة اللي التحدي منضم لها، أو null لو تحدٍ منفرد
  String? groupId;

  final List<LogEntry> logs = [];

  Challenge({
    required this.id,
    required this.title,
    required this.unit,
    required this.targetMin,
    required this.targetMax,
    required this.dailyTargetMin,
    required this.dailyTargetMax,
    required this.startDate,
    required this.endDate,
    required this.colorIndex,
    this.reminder = const ReminderSettings(),
    this.manuallyCompleted = false,
    this.groupId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'unit': unit,
    'targetMin': targetMin,
    'targetMax': targetMax,
    'dailyTargetMin': dailyTargetMin,
    'dailyTargetMax': dailyTargetMax,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'colorIndex': colorIndex,
    'reminder': reminder.toJson(),
    'manuallyCompleted': manuallyCompleted,
    'groupId': groupId,
    'logs': logs.map((log) => log.toJson()).toList(),
  };

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.parse(json['startDate'] as String);
    final endDate = DateTime.parse(json['endDate'] as String);
    final days = max(
      1,
      DateTime(endDate.year, endDate.month, endDate.day)
              .difference(
                DateTime(startDate.year, startDate.month, startDate.day),
              )
              .inDays +
          1,
    );
    final targetMin = json['targetMin'] as int;
    final targetMax = json['targetMax'] as int;
    final oldUnit = (json['unit'] as String).trim().toLowerCase();
    final isLegacyReadingDailyGoal =
        !json.containsKey('dailyTargetMin') &&
        days >= 7 &&
        targetMax <= 100 &&
        const {'صفحة', 'صفحات', 'page', 'pages'}.contains(oldUnit);
    final challenge = Challenge(
      id: json['id'] as String,
      title: json['title'] as String,
      unit: json['unit'] as String,
      targetMin: targetMin,
      targetMax: targetMax,
      dailyTargetMin:
          json['dailyTargetMin'] as int? ?? (targetMin / days).ceil(),
      dailyTargetMax:
          json['dailyTargetMax'] as int? ?? (targetMax / days).ceil(),
      startDate: startDate,
      endDate: endDate,
      colorIndex: json['colorIndex'] as int,
      reminder: ReminderSettings.fromJson(
        json['reminder'] as Map<String, dynamic>,
      ),
      manuallyCompleted: json['manuallyCompleted'] as bool? ?? false,
      groupId: json['groupId'] as String?,
    );
    challenge.logs.addAll(
      (json['logs'] as List<dynamic>? ?? []).map(
        (entry) => LogEntry.fromJson(entry as Map<String, dynamic>),
      ),
    );
    if (isLegacyReadingDailyGoal) {
      // Earlier builds accepted numbers like 25–50 without clarifying that
      // users meant pages per day. Convert those old reading goals into totals
      // so a 50-page daily log cannot complete a month-long challenge.
      challenge
        ..dailyTargetMin = targetMin
        ..dailyTargetMax = targetMax
        ..targetMin = targetMin * days
        ..targetMax = targetMax * days
        ..manuallyCompleted = false;
    }
    return challenge;
  }

  int get totalDone => logs.fold(0, (sum, log) => sum + log.amount);

  int get remaining => max(0, targetMin - totalDone);

  double get progress =>
      targetMax == 0 ? 0.0 : (totalDone / targetMax).clamp(0.0, 1.0).toDouble();

  /// إجمالي أيام التحدي من أوله لآخره (شامل يوم البداية والنهاية)
  int get totalDays {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return max(1, e.difference(s).inDays + 1);
  }

  /// كام يوم عدّى من التحدي (النهاردة بيتحسب "عدّى")
  int get daysElapsed {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final passed = today.difference(s).inDays;
    return passed.clamp(0, totalDays);
  }

  /// الأيام المتبقية (بتحسب النهاردة كمان)
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return max(0, end.difference(today).inDays + 1);
  }

  int get planningDaysLeft {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(startDate);
    return today.isBefore(start) ? totalDays : daysLeft;
  }

  /// المطلوب يوميًا عشان توصلي للحد الأدنى
  int get neededPerDay =>
      planningDaysLeft == 0 ? remaining : (remaining / planningDaysLeft).ceil();

  /// المتوسط اليومي المتبقي للوصول إلى الحد الأقصى، ويتحدث مع كل يوم/إنجاز.
  int get neededMaxPerDay => planningDaysLeft == 0
      ? max(0, targetMax - totalDone)
      : (max(0, targetMax - totalDone) / planningDaysLeft).ceil();

  /// حد تسجيل إنجاز التنبيه: 20٪ من الحد الأدنى المطلوب حاليًا في اليوم.
  int get minimumDailyCheckIn => (neededPerDay * 20 + 99) ~/ 100;

  /// متوسط ما تسجله يوميًا من بداية التحدي حتى الآن
  double get averagePerDay => daysElapsed == 0 ? 0.0 : totalDone / daysElapsed;

  /// الحد الأقصى ينهي التحدي تلقائيًا. الحد الأدنى وحده يسمح بإنهائه يدويًا
  /// مبكرًا، أو يعتبر إنجازًا عند انتهاء المدة.
  ChallengeStatus get status {
    if (totalDone >= targetMax || manuallyCompleted) {
      return ChallengeStatus.completed;
    }
    final now = DateTime.now();
    final endExclusive = DateTime(endDate.year, endDate.month, endDate.day + 1);
    if (!now.isBefore(endExclusive)) {
      return totalDone >= targetMin
          ? ChallengeStatus.completed
          : ChallengeStatus.failed;
    }
    return ChallengeStatus.active;
  }
}

/// مجموعة تضم عدة تحديات تخدم هدفًا واحدًا (مثال: القراءة)، ولها
/// إحصائيات مجمّعة من كل التحديات المنضمة إليها.
class Group {
  final String id;
  String title;

  Group({required this.id, required this.title});

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  factory Group.fromJson(Map<String, dynamic> json) =>
      Group(id: json['id'] as String, title: json['title'] as String);
}
