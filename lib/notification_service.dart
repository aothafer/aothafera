import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// المسؤول عن جدولة/إلغاء تنبيهات التحديات كإشعارات حقيقية من نظام
/// التشغيل، مستقلة تمامًا عن كون التطبيق فاتح أو مقفول.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
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

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // إذن ظهور الإشعارات نفسه (لازم على أندرويد 13 فأعلى)
    await android?.requestNotificationsPermission();
    // إذن التنبيهات الدقيقة في وقتها بالظبط (لازم على أندرويد 12 فأعلى)
    await android?.requestExactAlarmsPermission();

    _initialized = true;
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

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'challenge_reminders',
        'تذكيرات التحديات',
        channelDescription: 'تنبيه يومي بموعد تسجيل تقدمك في تحدي',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

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
        'سجّل تقدمك في ${c.unit} النهاردة',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
