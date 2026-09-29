import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'challenge_provider.dart';
import 'models.dart';
import 'reminder_day_picker.dart';
import 'notification_service.dart';
import 'theme.dart';

class AddChallengeScreen extends StatefulWidget {
  /// لو مرَّرت تحديًا هنا، الشاشة تفتح في وضع التعديل بدل الإنشاء.
  final Challenge? editing;

  const AddChallengeScreen({super.key, this.editing});

  @override
  State<AddChallengeScreen> createState() => _AddChallengeScreenState();
}

class _AddChallengeScreenState extends State<AddChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _unitController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  late DateTimeRange _range;

  // إعدادات التنبيه
  late bool _reminderOn;
  late bool _sameTimeEveryDay;
  late TimeOfDay _defaultTime;

  // الأيام اللي اتخصص لها وقت مختلف عن الوقت الافتراضي (المفتاح: رقم اليوم
  // بداية من 0 من أول يوم في التحدي)
  late final Map<int, TimeOfDay> _perDayTimes;

  // المجموعة اللي التحدي منضم لها، أو null لتحدٍ منفرد
  String? _groupId;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;

    _titleController = TextEditingController(text: c?.title ?? '');
    _unitController = TextEditingController(text: c?.unit ?? '');
    _minController = TextEditingController(text: c?.targetMin.toString() ?? '');
    _maxController = TextEditingController(
      text: (c != null && c.targetMax > c.targetMin)
          ? c.targetMax.toString()
          : '',
    );

    _range = c == null
        ? DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 30)),
          )
        : DateTimeRange(start: c.startDate, end: c.endDate);

    _reminderOn = c?.reminder.enabled ?? false;
    _sameTimeEveryDay = c?.reminder.sameTimeEveryDay ?? true;
    _defaultTime =
        c?.reminder.defaultTime ?? const TimeOfDay(hour: 20, minute: 0);
    _perDayTimes = Map.of(c?.reminder.perDayTimes ?? {});
    _groupId = c?.groupId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _perDayTimes.clear(); // المدة تغيّرت، فالتخصيص القديم لم يعد له معنى
      });
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _pickDefaultTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _defaultTime,
    );
    if (picked != null) setState(() => _defaultTime = picked);
  }

  int _dayIndex(DateTime day) {
    final s = DateTime(_range.start.year, _range.start.month, _range.start.day);
    final d = DateTime(day.year, day.month, day.day);
    return d.difference(s).inDays;
  }

  /// بيفتح الأجندة، والمستخدم يختار يومًا من ضمن مدة التحدي فقط، وبعدها
  /// يفتح وقت التنبيه لذلك اليوم.
  Future<void> _addCustomDay() async {
    final day = await ReminderDayPicker.show(
      context,
      challengeStart: _range.start,
      challengeEnd: _range.end,
    );
    if (day == null || !mounted) return;

    final index = _dayIndex(day);
    final picked = await showTimePicker(
      context: context,
      initialTime: _perDayTimes[index] ?? _defaultTime,
    );
    if (picked != null) setState(() => _perDayTimes[index] = picked);
  }

  Future<void> _editCustomDay(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _perDayTimes[index] ?? _defaultTime,
    );
    if (picked != null) setState(() => _perDayTimes[index] = picked);
  }

  void _removeCustomDay(int index) =>
      setState(() => _perDayTimes.remove(index));

  Future<void> _toggleReminder(bool enabled) async {
    if (!enabled) {
      setState(() => _reminderOn = false);
      return;
    }

    final permissions = await NotificationService.instance
        .requestReminderPermissions();
    if (!mounted) return;

    if (!permissions.notificationsAllowed) {
      setState(() => _reminderOn = false);
      await _showNotificationSettingsPrompt();
      return;
    }

    setState(() => _reminderOn = true);
    if (!permissions.exactAlarmsAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'التذكير سيصل بوقت تقريبي. فعّلي «المنبهات والتذكيرات» لموعد دقيق.',
          ),
          duration: Duration(seconds: 6),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: () =>
                NotificationService.instance.openExactAlarmSettings(),
          ),
        ),
      );
    }
  }

  Future<void> _showNotificationSettingsPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إشعارات التطبيق متوقفة'),
        content: const Text(
          'اسمحي للتطبيق بإرسال الإشعارات من إعدادات الجهاز، ثم فعّلي التذكير مرة أخرى.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              NotificationService.instance.openNotificationSettings();
            },
            child: const Text('فتح إعدادات الإشعارات'),
          ),
        ],
      ),
    );
  }

  Future<void> _testNotification() async {
    final permissions = await NotificationService.instance
        .checkReminderPermissions();
    if (!permissions.notificationsAllowed) {
      if (mounted) await _showNotificationSettingsPrompt();
      return;
    }

    await NotificationService.instance.showTestNotification();
    if (!mounted) return;

    final message = permissions.exactAlarmsAllowed
        ? 'لو ظهر الإشعار، فصلاحية الإشعارات تعمل. جرّبي بعدها موعد التحدي.'
        : 'الإشعار الفوري يعمل؛ مواعيد التحديات ستصل بوقت تقريبي حتى تفعيل المنبهات الدقيقة.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scheduleTestNotification() async {
    final permissions = await NotificationService.instance
        .checkReminderPermissions();
    if (!permissions.notificationsAllowed) {
      if (mounted) await _showNotificationSettingsPrompt();
      return;
    }

    final result = await NotificationService.instance
        .scheduleTestNotificationInOneMinute();
    if (!mounted) return;

    final message = result.error != null
        ? 'فشلت جدولة الاختبار: ${result.error}'
        : result.exact
        ? 'اتجدول اختبار بعد دقيقة بموعد دقيق. سيظهر حتى لو خرجتِ من التطبيق.'
        : 'اتجدول اختبار بعد دقيقة بوقت تقريبي؛ قد يتأخر بسبب إعدادات أندرويد.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('مجموعة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم المجموعة',
            hintText: 'مثال: القراءة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final group = context.read<ChallengeProvider>().addGroup(name);
    setState(() => _groupId = group.id);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_reminderOn) {
      final permissions = await NotificationService.instance
          .checkReminderPermissions();
      if (!permissions.notificationsAllowed) {
        if (mounted) await _showNotificationSettingsPrompt();
        return;
      }
    }
    if (!mounted) return;

    final min = int.parse(_minController.text);
    final max = _maxController.text.isEmpty
        ? min
        : int.parse(_maxController.text);

    final reminder = ReminderSettings(
      enabled: _reminderOn,
      sameTimeEveryDay: _sameTimeEveryDay,
      defaultTime: _defaultTime,
      perDayTimes: Map.of(_perDayTimes),
    );

    final provider = context.read<ChallengeProvider>();
    late final ReminderScheduleResult scheduleResult;
    if (_isEditing) {
      scheduleResult = await provider.updateChallenge(
        widget.editing!.id,
        title: _titleController.text.trim(),
        unit: _unitController.text.trim(),
        targetMin: min,
        targetMax: max,
        startDate: _range.start,
        endDate: _range.end,
        reminder: reminder,
        groupId: _groupId,
      );
    } else {
      scheduleResult = await provider.addChallenge(
        title: _titleController.text.trim(),
        unit: _unitController.text.trim(),
        targetMin: min,
        targetMax: max,
        startDate: _range.start,
        endDate: _range.end,
        reminder: reminder,
        groupId: _groupId,
      );
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (_reminderOn) {
      final next = scheduleResult.nextScheduledAt;
      final nextTime = next == null
          ? ''
          : ' أول موعد: ${next.day}/${next.month}، '
                '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}.';
      final message = scheduleResult.error != null
          ? 'تعذر جدولة التنبيه: ${scheduleResult.error}'
          : scheduleResult.scheduledCount == 0
          ? 'لم يُجدول أي موعد مستقبلي. راجعي تاريخ ووقت التحدي.'
          : 'اتجدول ${scheduleResult.scheduledCount} تنبيه'
                '${scheduleResult.exact ? ' بموعد دقيق.' : ' بوقت تقريبي.'}$nextTime';
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
    }
  }

  String? _requiredNumber(String? value) {
    if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
      return 'اكتب رقمًا أكبر من صفر';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<ChallengeProvider>().groups;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل التحدي' : 'تحدٍ جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'اسم التحدي',
                hintText: 'مثلًا: القراءة، الرياضة، الصلاة...',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'ضع لتحدّيك اسمًا' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'وحدة قياس التحدّي',
                hintText: 'صفحة، صلاة، يوم، دقيقة...',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب الوحدة' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الهدف (الحد الأدنى)',
              ),
              validator: _requiredNumber,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الحد الأقصى (اختياري)',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final max = int.tryParse(v);
                final min = int.tryParse(_minController.text);
                if (max == null) return 'اكتب رقمًا صحيحًا';
                if (min != null && max < min) {
                  return 'حدّك الأقصى عليه أن يكون أكبر من الأدنى';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range),
              label: Text('من ${_fmt(_range.start)} إلى ${_fmt(_range.end)}'),
            ),
            const SizedBox(height: 24),
            _GroupPicker(
              groups: groups,
              selectedId: _groupId,
              onChanged: (id) => setState(() => _groupId = id),
              onCreateNew: _createGroup,
            ),
            const SizedBox(height: 24),
            _ReminderSection(
              on: _reminderOn,
              onToggle: _toggleReminder,
              onTestNotification: _testNotification,
              onScheduleTestNotification: _scheduleTestNotification,
              sameTimeEveryDay: _sameTimeEveryDay,
              onSameTimeToggle: (v) => setState(() => _sameTimeEveryDay = v),
              defaultTime: _defaultTime,
              onPickDefaultTime: _pickDefaultTime,
              challengeStart: _range.start,
              perDayTimes: _perDayTimes,
              onAddCustomDay: _addCustomDay,
              onEditCustomDay: _editCustomDay,
              onRemoveCustomDay: _removeCustomDay,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'حفظ التعديلات' : 'حفظ التحدي'),
            ),
          ],
        ),
      ),
    );
  }
}

/// اختيار المجموعة اللي ينضم إليها التحدي، أو إنشاء مجموعة جديدة.
class _GroupPicker extends StatelessWidget {
  final List<Group> groups;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreateNew;

  const _GroupPicker({
    required this.groups,
    required this.selectedId,
    required this.onChanged,
    required this.onCreateNew,
  });

  static const _newGroupValue = '__new__';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المجموعة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'اجمع التحديات المتشابهة في مجموعة واحدة لترى إحصائياتها معًا',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            dropdownColor: AppColors.surface,
            decoration: const InputDecoration(labelText: 'بلا مجموعة'),
            items: [
              const DropdownMenuItem(value: null, child: Text('بلا مجموعة')),
              ...groups.map(
                (g) => DropdownMenuItem(value: g.id, child: Text(g.title)),
              ),
              const DropdownMenuItem(
                value: _newGroupValue,
                child: Text('+ مجموعة جديدة'),
              ),
            ],
            onChanged: (value) {
              if (value == _newGroupValue) {
                onCreateNew();
              } else {
                onChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTestNotification;
  final VoidCallback onScheduleTestNotification;
  final bool sameTimeEveryDay;
  final ValueChanged<bool> onSameTimeToggle;
  final TimeOfDay defaultTime;
  final VoidCallback onPickDefaultTime;
  final DateTime challengeStart;
  final Map<int, TimeOfDay> perDayTimes;
  final VoidCallback onAddCustomDay;
  final void Function(int dayIndex) onEditCustomDay;
  final void Function(int dayIndex) onRemoveCustomDay;

  const _ReminderSection({
    required this.on,
    required this.onToggle,
    required this.onTestNotification,
    required this.onScheduleTestNotification,
    required this.sameTimeEveryDay,
    required this.onSameTimeToggle,
    required this.defaultTime,
    required this.onPickDefaultTime,
    required this.challengeStart,
    required this.perDayTimes,
    required this.onAddCustomDay,
    required this.onEditCustomDay,
    required this.onRemoveCustomDay,
  });

  String _fmtTime(BuildContext context, TimeOfDay t) => t.format(context);

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    // الأيام المخصصة، مرتبة زمنيًا، مع تاريخها الفعلي
    final customDays = perDayTimes.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ضع تنبيهًا لهذا التحدي'),
            subtitle: const Text('هذا البند اختياريٌ تمامًا'),
            value: on,
            onChanged: onToggle,
          ),
          if (on) ...[
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مطابقة الوقت دائمًا'),
              value: sameTimeEveryDay,
              onChanged: onSameTimeToggle,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onPickDefaultTime,
              icon: const Icon(Icons.access_time),
              label: Text(
                sameTimeEveryDay
                    ? 'وقت التنبيه: ${_fmtTime(context, defaultTime)}'
                    : 'الوقت الافتراضي لباقي الأيام: '
                          '${_fmtTime(context, defaultTime)}',
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onTestNotification,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('إرسال إشعار تجريبي الآن'),
            ),
            TextButton.icon(
              onPressed: onScheduleTestNotification,
              icon: const Icon(Icons.alarm_add_outlined),
              label: const Text('اختبار موعد بعد دقيقة'),
            ),
            if (!sameTimeEveryDay) ...[
              const SizedBox(height: 16),
              Text(
                'تحتاج وقتًا آخر ليوم معين ؟ خصّص له وقتًا مختلفًا',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onAddCustomDay,
                icon: const Icon(Icons.event_available),
                label: const Text('تخصيص وقت ليوم معين'),
              ),
              if (customDays.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...customDays.map((index) {
                  final date = challengeStart.add(Duration(days: index));
                  final time = perDayTimes[index]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.muted.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_fmtDate(date)} — ${_fmtTime(context, time)}',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEditCustomDay(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => onRemoveCustomDay(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
