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
    _minController = TextEditingController(
      text: c?.dailyTargetMin.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: (c != null && c.dailyTargetMax > c.dailyTargetMin)
          ? c.dailyTargetMax.toString()
          : '',
    );

    _range = c == null
        ? DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 29)),
          )
        : DateTimeRange(start: c.startDate, end: c.endDate);

    _reminderOn = c?.reminder.enabled ?? false;
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
    final firstAllowed = DateUtils.dateOnly(
      DateTime.now().subtract(const Duration(days: 365)),
    );
    final lastAllowed = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 365 * 3)),
    );
    final pickedStart = await showDatePicker(
      context: context,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
      initialDate: DateUtils.dateOnly(_range.start),
    );
    if (pickedStart == null || !mounted) return;

    final start = DateUtils.dateOnly(pickedStart);
    final oldEnd = DateUtils.dateOnly(_range.end);
    final initialEnd = oldEnd.isBefore(start) ? start : oldEnd;
    final pickedEnd = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: lastAllowed,
      initialDate: initialEnd,
    );
    if (pickedEnd == null || !mounted) return;

    setState(() {
      _range = DateTimeRange(start: start, end: DateUtils.dateOnly(pickedEnd));
      _perDayTimes.clear(); // تغيّرت المدة، فالتخصيص القديم لم يعد صالحًا
    });
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  int get _durationDays =>
      DateUtils.dateOnly(_range.end)
          .difference(DateUtils.dateOnly(_range.start))
          .inDays +
      1;

  int get _dailyMinPreview => int.tryParse(_minController.text) ?? 0;

  int get _dailyMaxPreview =>
      int.tryParse(_maxController.text) ?? _dailyMinPreview;

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

  bool _isReminderTimeInFuture(DateTime day, TimeOfDay time) {
    final occurrence = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    return occurrence.isAfter(DateTime.now());
  }

  void _showPastCustomTimeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'ميعاد التنبيه لليوم ده فات بالفعل. اختر وقتًا قادمًا عشان التنبيه يرن.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
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
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.dateOnly(day).isBefore(today)) {
      _showPastCustomTimeMessage();
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: _perDayTimes[index] ?? _defaultTime,
    );
    if (picked == null || !mounted) return;
    if (!_isReminderTimeInFuture(day, picked)) {
      _showPastCustomTimeMessage();
      return;
    }
    setState(() => _perDayTimes[index] = picked);
  }

  Future<bool> _editCustomDay(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _perDayTimes[index] ?? _defaultTime,
    );
    if (picked == null || !mounted) return false;
    final day = _range.start.add(Duration(days: index));
    if (!_isReminderTimeInFuture(day, picked)) {
      _showPastCustomTimeMessage();
      return false;
    }
    setState(() => _perDayTimes[index] = picked);
    return true;
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
            'التذكير سيصل بوقت تقريبي. فعّل «المنبهات والتذكيرات» لموعد دقيق.',
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
          'اسمح للتطبيق بإرسال الإشعارات من إعدادات الجهاز، ثم فعّل التذكير مرة أخرى.',
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

  Future<void> _save({bool skipMissedToday = false}) async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (!mounted) return;

      final dailyMin = int.parse(_minController.text);
      final dailyMax = _maxController.text.isEmpty
          ? dailyMin
          : int.parse(_maxController.text);
      final reminder = ReminderSettings(
        enabled: _reminderOn,
        defaultTime: _defaultTime,
        perDayTimes: Map.of(_perDayTimes),
      );

      final today = DateUtils.dateOnly(DateTime.now());
      final todayIndex = _dayIndex(today);
      final todayIsInChallenge = todayIndex >= 0 && todayIndex < _durationDays;
      if (_reminderOn && todayIsInChallenge && !skipMissedToday) {
        final hasLaterDays = DateUtils.dateOnly(_range.end).isAfter(today);
        final todayTime = reminder.timeForDay(todayIndex);
        final todayReminder = DateTime(
          today.year,
          today.month,
          today.day,
          todayTime.hour,
          todayTime.minute,
        );
        if (!todayReminder.isAfter(DateTime.now())) {
          final choice = await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('ميعاد تنبيه اليوم فات'),
              content: Text(
                hasLaterDays
                    ? 'التنبيه ده مش هيرن النهارده لأن ميعاده عدى. يمكنك تغيير ميعاد اليوم فقط، أو المتابعة من غير تنبيه النهارده؛ مواعيد باقي الأيام هتفضل زي ما هي.'
                    : 'ميعاد اليوم عدى ومفيش أيام تانية في مدة التحدي. غيّر وقت التنبيه لوقت قادم، أو أوقف التذكير.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'edit'),
                  child: const Text('تغيير ميعاد اليوم'),
                ),
                if (hasLaterDays)
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, 'continue'),
                    child: const Text('متابعة بدون تنبيه اليوم'),
                  ),
              ],
            ),
          );
          if (!mounted) return;
          if (choice == 'edit') {
            if (await _editCustomDay(todayIndex) && mounted) await _save();
            return;
          }
          if (choice == 'continue') {
            await _save(skipMissedToday: true);
          }
          return;
        }
      }

      final hasFutureReminder =
          !_reminderOn ||
          await NotificationService.instance.hasFutureReminderOccurrence(
            startDate: _range.start,
            endDate: _range.end,
            reminder: reminder,
          );
      if (!mounted) return;
      if (!hasFutureReminder) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'وقت التنبيه المختار فات خلال مدة التحدي. اختر وقتًا قادمًا أو غيّر التاريخ، أو أوقف التذكير.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      final provider = context.read<ChallengeProvider>();
      final scheduleResult = _isEditing
          ? await provider.updateChallenge(
              widget.editing!.id,
              title: _titleController.text.trim(),
              unit: _unitController.text.trim(),
              dailyTargetMin: dailyMin,
              dailyTargetMax: dailyMax,
              startDate: _range.start,
              endDate: _range.end,
              reminder: reminder,
              groupId: _groupId,
            )
          : await provider.addChallenge(
              title: _titleController.text.trim(),
              unit: _unitController.text.trim(),
              dailyTargetMin: dailyMin,
              dailyTargetMax: dailyMax,
              startDate: _range.start,
              endDate: _range.end,
              reminder: reminder,
              groupId: _groupId,
            );
      if (!mounted) return;
      Navigator.pop(context);
      if (_reminderOn && scheduleResult.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حُفظ التحدي، لكن تعذرت جدولة التنبيه: ${scheduleResult.error}',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Could not save challenge: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حصلت مشكلة أثناء حفظ التحدي. راجع مساحة الجهاز وحاول مرة أخرى.',
          ),
          duration: Duration(seconds: 6),
        ),
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
              onChanged: (_) => setState(() {}),
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
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الحد الأدنى يوميًا',
              ),
              validator: _requiredNumber,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الحد الأقصى يوميًا (اختياري)',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final max = int.tryParse(v);
                final min = int.tryParse(_minController.text);
                if (max == null) return 'اكتب رقمًا صحيحًا';
                if (min != null && max < min) {
                  return 'يجب أن يكون الحد الأقصى أكبر من الحد الأدنى';
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
            const SizedBox(height: 8),
            Text(
              'لمدة $_durationDays يوم: من '
              '${_dailyMinPreview * _durationDays} إلى '
              '${_dailyMaxPreview * _durationDays} '
              '${_unitController.text.isEmpty ? 'وحدة' : _unitController.text}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
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
            OutlinedButton.icon(
              onPressed: onPickDefaultTime,
              icon: const Icon(Icons.access_time),
              label: Text('الوقت اليومي: ${_fmtTime(context, defaultTime)}'),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            Text(
              'الوقت ده يتكرر كل يوم، ويمكنك اختيار أيام معينة بوقت مختلف.',
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
      ),
    );
  }
}
