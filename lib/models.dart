import 'dart:math';

import 'package:flutter/material.dart' show TimeOfDay;

/// تسجيل واحد للتقدم: كام وحدة عملتي في يوم معين
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

  /// لو true: كل أيام التحدي بتاخد وقت واحد (defaultTime).
  /// لو false: كل يوم له وقته الخاص في perDayTimes.
  final bool sameTimeEveryDay;
  final TimeOfDay defaultTime;

  /// وقت مخصص لكل يوم من أيام التحدي (المفتاح: رقم اليوم بداية من 0)
  final Map<int, TimeOfDay> perDayTimes;

  const ReminderSettings({
    this.enabled = false,
    this.sameTimeEveryDay = true,
    this.defaultTime = const TimeOfDay(hour: 20, minute: 0),
    this.perDayTimes = const {},
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'sameTimeEveryDay': sameTimeEveryDay,
    'defaultHour': defaultTime.hour,
    'defaultMinute': defaultTime.minute,
    'perDayTimes': perDayTimes.map(
      (day, time) => MapEntry('$day', [time.hour, time.minute]),
    ),
  };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
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
      sameTimeEveryDay: json['sameTimeEveryDay'] as bool? ?? true,
      defaultTime: TimeOfDay(
        hour: json['defaultHour'] as int? ?? 20,
        minute: json['defaultMinute'] as int? ?? 0,
      ),
      perDayTimes: times,
    );
  }

  ReminderSettings copyWith({
    bool? enabled,
    bool? sameTimeEveryDay,
    TimeOfDay? defaultTime,
    Map<int, TimeOfDay>? perDayTimes,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      sameTimeEveryDay: sameTimeEveryDay ?? this.sameTimeEveryDay,
      defaultTime: defaultTime ?? this.defaultTime,
      perDayTimes: perDayTimes ?? this.perDayTimes,
    );
  }

  /// وقت التنبيه ليوم معين (رقم اليوم بداية من 0)
  TimeOfDay timeForDay(int dayIndex) {
    if (sameTimeEveryDay) return defaultTime;
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
  DateTime startDate;
  DateTime endDate;
  final int colorIndex; // بيحدد لون التحدي من لوحة الألوان
  ReminderSettings reminder;

  /// معرّف المجموعة اللي التحدي منضم لها، أو null لو تحدٍ منفرد
  String? groupId;

  final List<LogEntry> logs = [];

  Challenge({
    required this.id,
    required this.title,
    required this.unit,
    required this.targetMin,
    required this.targetMax,
    required this.startDate,
    required this.endDate,
    required this.colorIndex,
    this.reminder = const ReminderSettings(),
    this.groupId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'unit': unit,
    'targetMin': targetMin,
    'targetMax': targetMax,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'colorIndex': colorIndex,
    'reminder': reminder.toJson(),
    'groupId': groupId,
    'logs': logs.map((log) => log.toJson()).toList(),
  };

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final challenge = Challenge(
      id: json['id'] as String,
      title: json['title'] as String,
      unit: json['unit'] as String,
      targetMin: json['targetMin'] as int,
      targetMax: json['targetMax'] as int,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      colorIndex: json['colorIndex'] as int,
      reminder: ReminderSettings.fromJson(
        json['reminder'] as Map<String, dynamic>,
      ),
      groupId: json['groupId'] as String?,
    );
    challenge.logs.addAll(
      (json['logs'] as List<dynamic>? ?? []).map(
        (entry) => LogEntry.fromJson(entry as Map<String, dynamic>),
      ),
    );
    return challenge;
  }

  int get totalDone => logs.fold(0, (sum, log) => sum + log.amount);

  int get remaining => max(0, targetMin - totalDone);

  double get progress =>
      targetMin == 0 ? 0.0 : (totalDone / targetMin).clamp(0.0, 1.0).toDouble();

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

  /// المطلوب يوميًا عشان توصلي للحد الأدنى
  int get neededPerDay =>
      daysLeft == 0 ? remaining : (remaining / daysLeft).ceil();

  /// متوسط اللي بتسجليه يوميًا من بداية التحدي لحد دلوقتي
  double get averagePerDay => daysElapsed == 0 ? 0.0 : totalDone / daysElapsed;

  /// الحالة: مكتمل لو وصل للحد الأدنى، فشل لو خلصت مدته من غير ما يوصل،
  /// وإلا فهو لا يزال نشطًا.
  ChallengeStatus get status {
    if (remaining == 0) return ChallengeStatus.completed;
    if (daysLeft == 0) return ChallengeStatus.failed;
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
