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

  Future<void> showTestNotification() async {
    await _plugin.show(
      2147483646,
      'اختبار تنبيه التحديات',
      'الإشعارات تعمل على هذا الجهاز.',
      _reminderNotificationDetails,
    );
  }

  Future<ReminderScheduleResult> scheduleTestNotificationInOneMinute() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final scheduledAt = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: 1));

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _settingsChannel.invokeMethod<bool>('cancelAlarm', {
          'id': 2147483645,
        });
        final nativeExact = await _scheduleNativeAlarm(
          id: 2147483645,
          scheduledAt: scheduledAt,
          title: 'اختبار منبه التحديات',
          body: 'إذا سمعتِ الرنين وأوقفتِه من الإشعار، فالمنبه الفعلي يعمل.',
        );
        return ReminderScheduleResult(
          scheduledCount: 1,
          nextScheduledAt: scheduledAt,
          exact: nativeExact,
        );
      }

      await _plugin.zonedSchedule(
        2147483645,
        'اختبار موعد تنبيه التحديات',
        'إذا وصل هذا الإشعار، فجدولة المواعيد تعمل.',
        scheduledAt,
        _reminderNotificationDetails,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return ReminderScheduleResult(
        scheduledCount: 1,
        nextScheduledAt: scheduledAt,
        exact: exact,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to schedule the ringing alarm test: $error\n$stackTrace',
      );
      return ReminderScheduleResult(
        scheduledCount: 0,
        nextScheduledAt: null,
        exact: exact,
        error: 'تعذرت جدولة المنبه. راجعي أذونات الإشعارات والمنبهات الدقيقة.',
      );
    }
  }

  // رقم إشعار فريد لكل يوم من كل تحدي، مبني من هوية التحدي ورقم اليوم
  int _idFor(String challengeId, int dayIndex) {
    var hash = 0x811C9DC5;
    for (final codeUnit in challengeId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    final base = hash % 100000;
    return base * 10000 + dayIndex;
  }

  /// بيحذف كل التنبيهات المجدولة لتحدي معين.
  Future<void> cancelForChallenge(Challenge c) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _settingsChannel.invokeMethod<void>('cancelChallengeAlarms', {
        'challengeId': c.id,
      });
      return;
    }
    for (var i = 0; i < c.totalDays; i++) {
      await _plugin.cancel(_idFor(c.id, i));
    }
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

        if (scheduled.isBefore(now)) continue;

        final id = _idFor(c.id, day);
        final scheduledExactly =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? await _scheduleNativeAlarm(
                id: id,
                scheduledAt: scheduled,
                title: 'وقت "${c.title}"',
                body: 'سجّلي تقدمك في ${c.unit} اليوم',
                challengeId: c.id,
              )
            : await _schedulePluginNotification(id, c, scheduled, exact);
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
        error: 'تعذرت جدولة المنبه. راجعي أذونات الإشعارات والمنبهات الدقيقة.',
      );
    }
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
      'سجّلي تقدمك في ${challenge.unit} اليوم',
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
          'challenge_alarm_reminders_v2',
          'منبهات التحديات',
          channelDescription: 'منبه بموعد تسجيل تقدمك في التحدي',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          enableVibration: true,
        ),
      );
}
