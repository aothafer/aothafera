import 'package:flutter/services.dart';
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

  // رقم إشعار فريد لكل يوم من كل تحدي، مبني من هوية التحدي ورقم اليوم
  int _idFor(String challengeId, int dayIndex) {
    final base = challengeId.hashCode.abs() % 100000;
    return base * 10000 + dayIndex;
  }

  /// بيحذف كل التنبيهات المجدولة لتحدي معين.
  Future<void> cancelForChallenge(Challenge c) async {
    for (var i = 0; i < c.totalDays; i++) {
      await _plugin.cancel(_idFor(c.id, i));
    }
  }

  /// بيجدول تنبيه لكل يوم من أيام التحدي حسب إعدادات reminder بتاعته.
  /// أي يوم معاده فات بالفعل بيتجاهل، ولو التنبيه متوقف بيلغي أي جدولة
  /// قديمة بس من غير ما يحط جديدة.
  Future<void> scheduleForChallenge(Challenge c) async {
    await cancelForChallenge(c);
    if (!c.reminder.enabled) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exactAlarmsAllowed =
        await android?.canScheduleExactNotifications() ?? true;

    final details = _reminderNotificationDetails;

    final now = tz.TZDateTime.now(tz.local);

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

      await _plugin.zonedSchedule(
        _idFor(c.id, day),
        'وقت "${c.title}"',
        'سجّل تقدمك في ${c.unit} اليوم',
        scheduled,
        details,
        androidScheduleMode: exactAlarmsAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
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
