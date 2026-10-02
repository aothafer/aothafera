import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class ReminderPermissionStatus {
  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;

  const ReminderPermissionStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });
}

class ReminderScheduleResult {
  final int scheduledCount;
  final DateTime? nextScheduledAt;
  final bool exact;
  final String? error;

  const ReminderScheduleResult({
    required this.scheduledCount,
    required this.nextScheduledAt,
    required this.exact,
    this.error,
  });
}

/// المسؤول عن جدولة/إلغاء تنبيهات التحديات كإشعارات حقيقية من نظام
/// التشغيل، مستقلة تمامًا عن كون التطبيق فاتح أو مقفول.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _settingsChannel = MethodChannel(
    'com.example.challenge_tracker/notification_settings',
  );
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // لو فشل تحديد المنطقة الزمنية، بنسيب الإعداد الافتراضي بدل ما
      // نحسب وقت غلط.
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Remove one-shot plugin alarms from older app versions. Native alarm
      // scheduling below now owns the ringing service and stop action.
      try {
        final legacyRequests = await _plugin.pendingNotificationRequests();
        for (final request in legacyRequests) {
          await _plugin.cancel(request.id);
        }
        await _settingsChannel.invokeMethod<void>('restoreAlarms');
      } catch (error) {
        debugPrint('Could not migrate pending reminders: $error');
      }
    }

    _initialized = true;
  }

  /// يطلب الأذونات عند تفعيل المستخدم للتذكير، بدل إظهار طلب إذن مباغت
  /// بمجرد فتح التطبيق. الدقة مطلوبة لموعد التنبيه المحدد.
  Future<ReminderPermissionStatus> requestReminderPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return const ReminderPermissionStatus(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );
    }

    final notificationsAllowed =
        await android.requestNotificationsPermission() ?? true;
    if (!notificationsAllowed) {
      return const ReminderPermissionStatus(
        notificationsAllowed: false,
        exactAlarmsAllowed: false,
      );
    }

    var exactAlarmsAllowed =
        await android.canScheduleExactNotifications() ?? true;
    if (!exactAlarmsAllowed) {
      await android.requestExactAlarmsPermission();
      exactAlarmsAllowed =
          await android.canScheduleExactNotifications() ?? false;
    }

    return ReminderPermissionStatus(
      notificationsAllowed: true,
      exactAlarmsAllowed: exactAlarmsAllowed,
    );
  }

  Future<ReminderPermissionStatus> checkReminderPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return const ReminderPermissionStatus(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );
    }

    return ReminderPermissionStatus(
      notificationsAllowed: await android.areNotificationsEnabled() ?? true,
      exactAlarmsAllowed: await android.canScheduleExactNotifications() ?? true,
    );
  }

  Future<void> openNotificationSettings() =>
      _settingsChannel.invokeMethod<void>('openNotificationSettings');

  Future<void> openExactAlarmSettings() =>
      _settingsChannel.invokeMethod<void>('openExactAlarmSettings');

  // رقم إشعار فريد لكل يوم من كل تحدي، مبني من هوية التحدي ورقم اليوم
  int _idFor(String challengeId, int dayIndex) {
    var hash = 0x811C9DC5;
    for (final codeUnit in challengeId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    final base = hash % 100000;
    return base * 10000 + dayIndex;
  }

  int _nudgeIdFor(String challengeId, int dayIndex) =>
      (_idFor(challengeId, dayIndex) ^ 0x40000000) & 0x7fffffff;

  /// بيحذف كل التنبيهات المجدولة لتحدي معين.
  Future<void> cancelForChallenge(Challenge c) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _settingsChannel.invokeMethod<void>('cancelChallengeAlarms', {
        'challengeId': c.id,
      });
    }
    for (var i = 0; i < c.totalDays; i++) {
      await _plugin.cancel(_idFor(c.id, i));
      await _plugin.cancel(_nudgeIdFor(c.id, i));
    }
  }

  /// يتحقق من وجود موعد تنبيه واحد على الأقل ما زال في المستقبل.
  /// يُستخدم قبل حفظ تحدٍ جديد حتى لا يُقبل تنبيه انتهى وقته بالفعل.
  Future<bool> hasFutureReminderOccurrence({
    required DateTime startDate,
    required DateTime endDate,
    required ReminderSettings reminder,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = end.difference(start).inDays + 1;

    for (var day = 0; day < totalDays; day++) {
      final date = start.add(Duration(days: day));
      final time = reminder.timeForDay(day);
      final scheduled = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (scheduled.isAfter(now)) return true;
    }
    return false;
  }

  /// بيجدول تنبيه لكل يوم من أيام التحدي حسب إعدادات reminder بتاعته.
  /// أي يوم معاده فات بالفعل بيتجاهل، ولو التنبيه متوقف بيلغي أي جدولة
  /// قديمة بس من غير ما يحط جديدة.
  Future<ReminderScheduleResult> scheduleForChallenge(Challenge c) async {
    try {
      await cancelForChallenge(c);
      if (!c.reminder.enabled) {
        return const ReminderScheduleResult(
          scheduledCount: 0,
          nextScheduledAt: null,
          exact: true,
        );
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      var exact = await android?.canScheduleExactNotifications() ?? true;
      final now = tz.TZDateTime.now(tz.local);
      DateTime? nextScheduledAt;
      var scheduledCount = 0;

      for (var day = 0; day < c.totalDays; day++) {
        final date = c.startDate.add(Duration(days: day));
        final time = c.reminder.timeForDay(day);
        final scheduled = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        final id = _idFor(c.id, day);
        final nudgeId = _nudgeIdFor(c.id, day);
        // Replacing a challenge schedule must also remove yesterday's pending
        // follow-up nudges, including when the day's alarm already passed.
        await _plugin.cancel(nudgeId);
        if (!scheduled.isAfter(now)) continue;

        final (dailyMin, dailyMax) = _dailyRangeForDate(c, date);
        final body =
            'المتوسط المطلوب الآن $dailyMin–$dailyMax ${c.unit} يوميًا. '
            'التسويف قد يراكم المطلوب ويبعدك عن هدفك.';
        final scheduledExactly =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? await _scheduleNativeAlarm(
                id: id,
                scheduledAt: scheduled,
                title: 'وقت "${c.title}"',
                body: body,
                challengeId: c.id,
              )
            : await _schedulePluginNotification(id, c, scheduled, exact);
        final nudgeAt = scheduled.add(const Duration(minutes: 45));
        final endOfDay = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          23,
          45,
        );
        final nudgeTime = nudgeAt.isAfter(endOfDay) ? endOfDay : nudgeAt;
        if (nudgeTime.isAfter(now) && nudgeTime.isAfter(scheduled)) {
          await _plugin.zonedSchedule(
            nudgeId,
            'تذكير بتقدم "${c.title}"',
            _missedNudgeBody(c, date),
            nudgeTime,
            _nudgeNotificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: c.id,
          );
        }
        exact = exact && scheduledExactly;
        scheduledCount++;
        nextScheduledAt ??= scheduled;
      }

      return ReminderScheduleResult(
        scheduledCount: scheduledCount,
        nextScheduledAt: nextScheduledAt,
        exact: exact,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to schedule challenge alarm: $error\n$stackTrace');
      return ReminderScheduleResult(
        scheduledCount: 0,
        nextScheduledAt: null,
        exact: false,
        error: 'تعذرت جدولة المنبه. راجع أذونات الإشعارات والمنبهات الدقيقة.',
      );
    }
  }

  (int, int) _dailyRangeForDate(Challenge challenge, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final end = DateTime(
      challenge.endDate.year,
      challenge.endDate.month,
      challenge.endDate.day,
    );
    final days = (end.difference(dateOnly).inDays + 1).clamp(
      1,
      challenge.totalDays,
    );
    final completedBefore = challenge.logs
        .where(
          (log) => log.date.isBefore(dateOnly.add(const Duration(days: 1))),
        )
        .fold<int>(0, (sum, log) => sum + log.amount);
    final minRemaining = (challenge.targetMin - completedBefore).clamp(
      0,
      challenge.targetMin,
    );
    final maxRemaining = (challenge.targetMax - completedBefore).clamp(
      0,
      challenge.targetMax,
    );
    return ((minRemaining / days).ceil(), (maxRemaining / days).ceil());
  }

  String _missedNudgeBody(Challenge challenge, DateTime alarmDate) {
    final tomorrow = DateTime(
      alarmDate.year,
      alarmDate.month,
      alarmDate.day + 1,
    );
    final end = DateTime(
      challenge.endDate.year,
      challenge.endDate.month,
      challenge.endDate.day,
    );
    final remainingDays = end.difference(tomorrow).inDays + 1;
    final completedBefore = challenge.logs
        .where(
          (log) => log.date.isBefore(
            DateTime(alarmDate.year, alarmDate.month, alarmDate.day),
          ),
        )
        .fold<int>(0, (sum, log) => sum + log.amount);
    final minRemaining = (challenge.targetMin - completedBefore).clamp(
      0,
      challenge.targetMin,
    );
    final maxRemaining = (challenge.targetMax - completedBefore).clamp(
      0,
      challenge.targetMax,
    );
    final minTomorrow = remainingDays <= 0
        ? minRemaining
        : (minRemaining / remainingDays).ceil();
    final maxTomorrow = remainingDays <= 0
        ? maxRemaining
        : (maxRemaining / remainingDays).ceil();
    return 'لم تسجّل تقدمك اليوم. إذا مرّ اليوم دون إنجاز، سيصبح متوسط الغد '
        '$minTomorrow–$maxTomorrow ${challenge.unit} يوميًا. التسويف قد يراكم المطلوب؛ '
        'افتح التطبيق وسجّل تقدمك.';
  }

  Future<bool> _scheduleNativeAlarm({
    required int id,
    required tz.TZDateTime scheduledAt,
    required String title,
    required String body,
    String? challengeId,
  }) async {
    return await _settingsChannel.invokeMethod<bool>('scheduleAlarm', {
          'id': id,
          'atMillis': scheduledAt.millisecondsSinceEpoch,
          'title': title,
          'body': body,
          'year': scheduledAt.year,
          'month': scheduledAt.month,
          'day': scheduledAt.day,
          'hour': scheduledAt.hour,
          'minute': scheduledAt.minute,
          'challengeId': challengeId,
        }) ??
        false;
  }

  Future<bool> _schedulePluginNotification(
    int id,
    Challenge challenge,
    tz.TZDateTime scheduledAt,
    bool exact,
  ) async {
    await _plugin.zonedSchedule(
      id,
      'وقت "${challenge.title}"',
      'سجّل تقدمك في ${challenge.unit} اليوم',
      scheduledAt,
      _reminderNotificationDetails,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return exact;
  }

  NotificationDetails get _reminderNotificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          // تغيير المعرّف ينشئ قناة جديدة على الأجهزة التي أنشأت القناة
          // القديمة بإعداداتها الافتراضية.
          'challenge_alarm_reminders_v3',
          'منبهات التحديات',
          channelDescription: 'منبه بموعد تسجيل تقدمك في التحدي',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          icon: 'ic_stat_logo',
          playSound: true,
          enableVibration: true,
        ),
      );

  NotificationDetails get _nudgeNotificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'challenge_progress_nudges_v1',
          'تذكير بالتقدم',
          channelDescription: 'تذكير هادئ إذا لم يُسجل تقدم بعد المنبه',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_stat_logo',
          playSound: false,
          enableVibration: false,
        ),
      );
}
