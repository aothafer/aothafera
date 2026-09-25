import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'challenge_provider.dart';
import 'models.dart';
import 'reminder_day_picker.dart';
import 'theme.dart';

class AddChallengeScreen extends StatefulWidget {
  const AddChallengeScreen({super.key});

  @override
  State<AddChallengeScreen> createState() => _AddChallengeScreenState();
}

class _AddChallengeScreenState extends State<AddChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _unitController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 30)),
  );

  // إعدادات التنبيه
  bool _reminderOn = false;
  bool _sameTimeEveryDay = true;
  TimeOfDay _defaultTime = const TimeOfDay(hour: 20, minute: 0);

  // الأيام اللي اتخصص لها وقت مختلف عن الوقت الافتراضي (المفتاح: رقم اليوم
  // بداية من 0 من أول يوم في التحدي)
  final Map<int, TimeOfDay> _perDayTimes = {};

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
        _perDayTimes.clear(); // المدة اتغيرت، فالتخصيص القديم ملوش معنى
      });
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _pickDefaultTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _defaultTime);
    if (picked != null) setState(() => _defaultTime = picked);
  }

  int _dayIndex(DateTime day) {
    final s = DateTime(_range.start.year, _range.start.month, _range.start.day);
    final d = DateTime(day.year, day.month, day.day);
    return d.difference(s).inDays;
  }

  /// بيفتح الأجندة، والمستخدم بيختار يوم من ضمن مدة التحدي بس، وبعدها
  /// بيفتح وقت التنبيه لليوم ده.
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

  void _removeCustomDay(int index) => setState(() => _perDayTimes.remove(index));

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final min = int.parse(_minController.text);
    final max =
        _maxController.text.isEmpty ? min : int.parse(_maxController.text);

    context.read<ChallengeProvider>().addChallenge(
          title: _titleController.text.trim(),
          unit: _unitController.text.trim(),
          targetMin: min,
          targetMax: max,
          startDate: _range.start,
          endDate: _range.end,
          reminder: ReminderSettings(
            enabled: _reminderOn,
            sameTimeEveryDay: _sameTimeEveryDay,
            defaultTime: _defaultTime,
            perDayTimes: Map.of(_perDayTimes),
          ),
        );
    Navigator.pop(context);
  }

  String? _requiredNumber(String? value) {
    if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
      return 'اكتب رقمًا أكبر من صفر';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحدي جديد')),
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
                  (v == null || v.trim().isEmpty) ? 'اكتب اسم التحدي' : null,
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
              decoration: const InputDecoration(labelText: 'الهدف (الحد الأدنى)'),
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
            _ReminderSection(
              on: _reminderOn,
              onToggle: (v) => setState(() => _reminderOn = v),
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
            FilledButton(onPressed: _save, child: const Text('حفظ التحدي')),
          ],
        ),
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onToggle;
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
            if (!sameTimeEveryDay) ...[
              const SizedBox(height: 16),
              Text(
                'تحتاج وقتًا آخر ؟ خصص وقتك الذي تودّ لأي يوم',
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
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.muted.withValues(alpha: 0.3)),
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
