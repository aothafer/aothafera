import 'package:flutter/material.dart';

import 'theme.dart';

/// أجندة لاختيار يوم واحد من أيام التحدي عشان تتخصص له وقت تنبيه مختلف.
/// الأيام اللي بره مدة التحدي بتظهر باهتة، ولو دوس المستخدم عليها بتظهر
/// رسالة توضّح إن التنبيه مش متاح فيها، بدل ما يتفتح وقت لها زي أي يوم عادي.
class ReminderDayPicker extends StatefulWidget {
  final DateTime challengeStart;
  final DateTime challengeEnd;

  const ReminderDayPicker({
    super.key,
    required this.challengeStart,
    required this.challengeEnd,
  });

  /// بيفتح الأجندة كـ bottom sheet، وبيرجع اليوم اللي اتختار (أو null لو
  /// المستخدم قفل من غير ما يختار).
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime challengeStart,
    required DateTime challengeEnd,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReminderDayPicker(
        challengeStart: challengeStart,
        challengeEnd: challengeEnd,
      ),
    );
  }

  @override
  State<ReminderDayPicker> createState() => _ReminderDayPickerState();
}

class _ReminderDayPickerState extends State<ReminderDayPicker> {
  late DateTime _visibleMonth;

  // الأسبوع هنا بيبدأ بالسبت زي المعتاد عندنا
  static const _weekdayLabels = ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];
  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  DateTime get _minMonth {
    final d = DateTime.now().subtract(const Duration(days: 365));
    return DateTime(d.year, d.month);
  }

  DateTime get _maxMonth {
    final d = DateTime.now().add(const Duration(days: 365 * 3));
    return DateTime(d.year, d.month);
  }

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.challengeStart.year, widget.challengeStart.month);
  }

  bool _inChallenge(DateTime day) {
    final s = DateTime(widget.challengeStart.year, widget.challengeStart.month,
        widget.challengeStart.day);
    final e = DateTime(
        widget.challengeEnd.year, widget.challengeEnd.month, widget.challengeEnd.day);
    return !day.isBefore(s) && !day.isAfter(e);
  }

  void _changeMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() => _visibleMonth = next);
  }

  void _onDayTap(DateTime day) {
    if (_inChallenge(day)) {
      Navigator.pop(context, day);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('عفوًا، الأيام خارج التحدي غير متاح وضع الإشعارات بها'),
      ),
    );
  }

  // خريطة تحويل ترقيم Dart لأيام الأسبوع (الاثنين = 1) لترتيب يبدأ بالسبت
  static const _weekdayToColumn = {6: 0, 7: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6};

  List<DateTime?> _monthCells() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leading = _weekdayToColumn[firstOfMonth.weekday] ?? 0;
    return [
      ...List.filled(leading, null),
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_visibleMonth.year, _visibleMonth.month, d),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cells = _monthCells();
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final atMinMonth = _visibleMonth == _minMonth;
    final atMaxMonth = _visibleMonth == _maxMonth;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.track,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text('اختر يوم التنبيه', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'الأيام الباهتة برة مدة التحدي، مش هتقدر تحط تنبيه فيها',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: atMaxMonth ? null : () => _changeMonth(1),
                ),
                Text(
                  '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: atMinMonth ? null : () => _changeMonth(-1),
                ),
              ],
            ),
            Row(
              children: _weekdayLabels
                  .map((w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.muted, fontSize: 11),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells.map((day) {
                if (day == null) return const SizedBox.shrink();
                final enabled = _inChallenge(day);
                final isToday = day == todayOnly;
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _onDayTap(day),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: isToday
                              ? Border.all(color: AppColors.muted)
                              : null,
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: enabled
                                ? null
                                : AppColors.muted.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
