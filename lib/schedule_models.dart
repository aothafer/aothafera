import 'package:flutter/material.dart';

enum SchedulePeriod { day, week, month, year }

extension SchedulePeriodLabel on SchedulePeriod {
  String get label => switch (this) {
    SchedulePeriod.day => 'يومي',
    SchedulePeriod.week => 'أسبوعي',
    SchedulePeriod.month => 'شهري',
    SchedulePeriod.year => 'سنوي',
  };
}

/// A user-defined time block on a specific date.
class ScheduleEntry {
  final String id;
  final String title;
  final DateTime date;
  final int startMinute;
  final int endMinute;

  const ScheduleEntry({
    required this.id,
    required this.title,
    required this.date,
    required this.startMinute,
    required this.endMinute,
  });

  TimeOfDay get startTime =>
      TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60);
  TimeOfDay get endTime =>
      TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': DateUtils.dateOnly(date).toIso8601String(),
    'startMinute': startMinute,
    'endMinute': endMinute,
  };

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    date: DateTime.parse(json['date'] as String),
    startMinute: json['startMinute'] as int,
    endMinute: json['endMinute'] as int,
  );
}

/// A flexible user-owned plan covering a day, week, month, or year.
class SchedulePlan {
  final String id;
  String title;
  final SchedulePeriod period;
  final DateTime anchorDate;
  bool showOnHome;
  final List<ScheduleEntry> entries;

  SchedulePlan({
    required this.id,
    required this.title,
    required this.period,
    required this.anchorDate,
    this.showOnHome = false,
    List<ScheduleEntry> entries = const [],
  }) : entries = List.of(entries);

  DateTime get rangeStart {
    final date = DateUtils.dateOnly(anchorDate);
    return switch (period) {
      SchedulePeriod.day => date,
      SchedulePeriod.week => DateUtils.dateOnly(
        date.subtract(Duration(days: date.weekday - DateTime.monday)),
      ),
      SchedulePeriod.month => DateTime(date.year, date.month),
      SchedulePeriod.year => DateTime(date.year),
    };
  }

  DateTime get rangeEnd => switch (period) {
    SchedulePeriod.day => rangeStart,
    SchedulePeriod.week => rangeStart.add(const Duration(days: 6)),
    SchedulePeriod.month => DateTime(rangeStart.year, rangeStart.month + 1, 0),
    SchedulePeriod.year => DateTime(rangeStart.year, 12, 31),
  };

  bool containsDate(DateTime date) {
    final value = DateUtils.dateOnly(date);
    return !value.isBefore(rangeStart) && !value.isAfter(rangeEnd);
  }

  List<ScheduleEntry> onDate(DateTime date) => entries
      .where((entry) => DateUtils.isSameDay(entry.date, date))
      .toList()
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'period': period.name,
    'anchorDate': anchorDate.toIso8601String(),
    'showOnHome': showOnHome,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory SchedulePlan.fromJson(Map<String, dynamic> json) => SchedulePlan(
    id: json['id'] as String,
    title: json['title'] as String,
    period: SchedulePeriod.values.firstWhere(
      (period) => period.name == json['period'],
      orElse: () => SchedulePeriod.week,
    ),
    anchorDate: DateTime.parse(json['anchorDate'] as String),
    showOnHome: json['showOnHome'] as bool? ?? false,
    entries: (json['entries'] as List<dynamic>? ?? [])
        .map((entry) => ScheduleEntry.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );
}
