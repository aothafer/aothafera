import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'challenge_provider.dart';
import 'schedule_models.dart';
import 'theme.dart';

String _dateLabel(DateTime date) {
  const weekdays = [
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
  ];
  const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  return '${weekdays[date.weekday - 1]}، ${date.day} ${months[date.month - 1]} ${date.year}';
}

String _rangeLabel(SchedulePlan plan) {
  if (plan.period == SchedulePeriod.day) return _dateLabel(plan.rangeStart);
  return '${plan.period.label} · ${plan.rangeStart.day}/${plan.rangeStart.month} – ${plan.rangeEnd.day}/${plan.rangeEnd.month}/${plan.rangeEnd.year}';
}

class ScheduleManagerScreen extends StatelessWidget {
  const ScheduleManagerScreen({super.key});

  Future<void> _create(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleEditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedules = context.watch<ChallengeProvider>().schedules;
    return Scaffold(
      appBar: AppBar(title: const Text('جداولي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('إنشاء جدول'),
      ),
      body: schedules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, size: 52, color: AppColors.mustard),
                    const SizedBox(height: 16),
                    Text('رتّب وقتك بطريقتك', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'أضف مواعيدك بالعدد الذي يناسب يومك، واكتشف الفترات المتاحة لوقت التحدي.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _create(context),
                      icon: const Icon(Icons.add),
                      label: const Text('أنشئ جدولك الأول'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: schedules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _SchedulePlanTile(plan: schedules[index]),
            ),
    );
  }
}

class _SchedulePlanTile extends StatelessWidget {
  final SchedulePlan plan;
  const _SchedulePlanTile({required this.plan});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChallengeProvider>();
    final entries = plan.entries.length;
    return Card(
      color: AppColors.surface,
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.track,
              child: Icon(Icons.calendar_today, color: AppColors.mustard),
            ),
            title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_rangeLabel(plan)}\n$entries ${entries == 1 ? 'موعد' : 'مواعيد'}'),
            isThreeLine: true,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => ScheduleDetailScreen(scheduleId: plan.id)),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => ScheduleEditorScreen(existing: plan)),
                  );
                } else if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('حذف الجدول؟'),
                      content: const Text('سيتم حذف مواعيد هذا الجدول.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
                      ],
                    ),
                  );
                  if (confirmed == true) await provider.removeSchedule(plan.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ),
          SwitchListTile.adaptive(
            value: plan.showOnHome,
            activeTrackColor: AppColors.mustard,
            title: const Text('إظهار في شاشة التحديات'),
            secondary: const Icon(Icons.view_carousel_outlined, color: AppColors.tealLight),
            onChanged: (show) => provider.updateSchedule(
              SchedulePlan(
                id: plan.id,
                title: plan.title,
                period: plan.period,
                anchorDate: plan.anchorDate,
                showOnHome: show,
                entries: plan.entries,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleEditorScreen extends StatefulWidget {
  final SchedulePlan? existing;
  const ScheduleEditorScreen({super.key, this.existing});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  late final TextEditingController _title;
  late SchedulePeriod _period;
  late DateTime _anchorDate;
  late bool _showOnHome;
  late List<ScheduleEntry> _entries;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.existing;
    _title = TextEditingController(text: plan?.title ?? '');
    _period = plan?.period ?? SchedulePeriod.week;
    _anchorDate = DateUtils.dateOnly(plan?.anchorDate ?? DateTime.now());
    _showOnHome = plan?.showOnHome ?? false;
    _entries = List.of(plan?.entries ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  SchedulePlan get _rangePlan => SchedulePlan(
    id: widget.existing?.id ?? 'draft',
    title: _title.text,
    period: _period,
    anchorDate: _anchorDate,
  );

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final nextDate = DateUtils.dateOnly(picked);
      final nextRange = SchedulePlan(
        id: 'draft',
        title: _title.text,
        period: _period,
        anchorDate: nextDate,
      );
      if (_entries.any((entry) => !nextRange.containsDate(entry.date))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فيه مواعيد خارج الفترة الجديدة. احذفها أو اختار تاريخًا يشملها.')),
        );
        return;
      }
      setState(() => _anchorDate = nextDate);
    }
  }

  void _changePeriod(SchedulePeriod period) {
    final nextRange = SchedulePlan(
      id: 'draft',
      title: _title.text,
      period: period,
      anchorDate: _anchorDate,
    );
    if (_entries.any((entry) => !nextRange.containsDate(entry.date))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فيه مواعيد خارج الفترة دي. احذفها الأول أو احتفظ بالفترة الحالية.')),
      );
      return;
    }
    setState(() => _period = period);
  }

  Future<void> _addEntry() async {
    final range = _rangePlan;
    final result = await showDialog<ScheduleEntry>(
      context: context,
      builder: (_) => _ScheduleEntryDialog(
        startDate: range.rangeStart,
        endDate: range.rangeEnd,
        initialDate: _anchorDate.isBefore(range.rangeStart)
            ? range.rangeStart
            : _anchorDate.isAfter(range.rangeEnd)
                ? range.rangeEnd
                : _anchorDate,
        existing: _entries,
      ),
    );
    if (result != null && mounted) setState(() => _entries.add(result));
  }

  Future<void> _editEntry(ScheduleEntry entry) async {
    final range = _rangePlan;
    final result = await showDialog<ScheduleEntry>(
      context: context,
      builder: (_) => _ScheduleEntryDialog(
        startDate: range.rangeStart,
        endDate: range.rangeEnd,
        initialDate: entry.date,
        existing: _entries,
        initialEntry: entry,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final index = _entries.indexWhere((item) => item.id == entry.id);
        if (index >= 0) _entries[index] = result;
      });
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسمًا للجدول أولًا.')));
      return;
    }
    setState(() => _saving = true);
    final schedule = SchedulePlan(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      period: _period,
      anchorDate: _anchorDate,
      showOnHome: _showOnHome,
      entries: _entries,
    );
    final provider = context.read<ChallengeProvider>();
    if (widget.existing == null) {
      await provider.addSchedule(schedule);
    } else {
      await provider.updateSchedule(schedule);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final range = _rangePlan;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'إنشاء جدول' : 'تعديل الجدول')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ الجدول')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _title,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(labelText: 'اسم الجدول', hintText: 'مثال: أسبوعي المزدحم'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          Text('الفترة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final period in SchedulePeriod.values)
                ChoiceChip(
                  label: Text(period.label),
                  selected: _period == period,
                  onSelected: (_) => _changePeriod(period),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.event, color: AppColors.mustard),
              title: const Text('يبدأ من'),
              subtitle: Text('${_dateLabel(range.rangeStart)}\nينتهي ${_dateLabel(range.rangeEnd)}'),
              isThreeLine: true,
              trailing: IconButton(icon: const Icon(Icons.edit_calendar), onPressed: _pickAnchor),
              onTap: _pickAnchor,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _showOnHome,
            activeTrackColor: AppColors.mustard,
            title: const Text('أظهره في شاشة التحديات'),
            subtitle: const Text('تقدر تفتحه من الشريط المتحرك بجوار لوحة الطريق.'),
            onChanged: (value) => setState(() => _showOnHome = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('مواعيدك (${_entries.length})', style: Theme.of(context).textTheme.titleLarge)),
              TextButton.icon(onPressed: _addEntry, icon: const Icon(Icons.add), label: const Text('إضافة موعد')),
            ],
          ),
          const Text('أضف أي عدد من البنود؛ مفيش قالب بعدد خانات ثابت.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          if (_entries.isEmpty)
            const _NoEntriesCard()
          else
            ..._entries.map((entry) => _EntryTile(
              entry: entry,
              onEdit: () => _editEntry(entry),
              onDelete: () => setState(() => _entries.removeWhere((item) => item.id == entry.id)),
            )),
        ],
      ),
    );
  }
}

class _NoEntriesCard extends StatelessWidget {
  const _NoEntriesCard();
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: const Padding(
      padding: EdgeInsets.all(20),
      child: Row(children: [Icon(Icons.add_task, color: AppColors.tealLight), SizedBox(width: 12), Expanded(child: Text('جدولك فاضي لسه. أضف أول موعد عشان تظهر الفترات المتاحة.'))]),
    ),
  );
}

class _EntryTile extends StatelessWidget {
  final ScheduleEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EntryTile({required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: ListTile(
      leading: const Icon(Icons.waterfall_chart, color: AppColors.terracotta),
      title: Text(entry.title),
      subtitle: Text('${_dateLabel(entry.date)} · ${entry.startTime.format(context)}–${entry.endTime.format(context)}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'تعديل الموعد', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: AppColors.tealLight)),
        IconButton(tooltip: 'حذف الموعد', onPressed: onDelete, icon: const Icon(Icons.close)),
      ]),
    ),
  );
}

class _ScheduleEntryDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime initialDate;
  final List<ScheduleEntry> existing;
  final ScheduleEntry? initialEntry;
  const _ScheduleEntryDialog({required this.startDate, required this.endDate, required this.initialDate, required this.existing, this.initialEntry});

  @override
  State<_ScheduleEntryDialog> createState() => _ScheduleEntryDialogState();
}

class _ScheduleEntryDialogState extends State<_ScheduleEntryDialog> {
  late final TextEditingController _title;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    final entry = widget.initialEntry;
    _title = TextEditingController(text: entry?.title ?? '');
    _start = entry?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    _end = entry?.endTime ?? const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  int get _startMinute => _start.hour * 60 + _start.minute;
  int get _endMinute => _end.hour * 60 + _end.minute;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.startDate,
      lastDate: widget.endDate,
    );
    if (date != null) setState(() => _date = DateUtils.dateOnly(date));
  }

  Future<void> _pickTime({required bool start}) async {
    final time = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (time != null) setState(() { if (start) { _start = time; } else { _end = time; } });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty || _endMinute <= _startMinute) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم الموعد واختر وقت نهاية بعد البداية.')));
      return;
    }
    final overlaps = widget.existing.any((entry) => entry.id != widget.initialEntry?.id &&
      DateUtils.isSameDay(entry.date, _date) &&
      _startMinute < entry.endMinute && _endMinute > entry.startMinute,
    );
    if (overlaps) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الموعد يتداخل مع موعد آخر في اليوم نفسه.')));
      return;
    }
    Navigator.pop(context, ScheduleEntry(
      id: widget.initialEntry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      date: _date,
      startMinute: _startMinute,
      endMinute: _endMinute,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('إضافة موعد'),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'اسم النشاط')),
        const SizedBox(height: 10),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.today, color: AppColors.tealLight), title: const Text('اليوم'), subtitle: Text(_dateLabel(_date)), onTap: _pickDate),
        Row(children: [
          Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: const Text('من'), subtitle: Text(_start.format(context)), onTap: () => _pickTime(start: true))),
          Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: const Text('إلى'), subtitle: Text(_end.format(context)), onTap: () => _pickTime(start: false))),
        ]),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: _save, child: const Text('إضافة')),
    ],
  );
}

class ScheduleDetailScreen extends StatefulWidget {
  final String scheduleId;
  const ScheduleDetailScreen({super.key, required this.scheduleId});

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  DateTime? _selectedDate;

  Future<void> _changeDate(SchedulePlan plan, int delta) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = _selectedDate ?? (plan.containsDate(today) ? today : plan.rangeStart);
    final next = DateUtils.dateOnly(current.add(Duration(days: delta)));
    if (plan.containsDate(next)) setState(() => _selectedDate = next);
  }

  Future<void> _pickDate(SchedulePlan plan) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final selected = _selectedDate ?? (plan.containsDate(now) ? now : plan.rangeStart);
    final date = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: plan.rangeStart,
      lastDate: plan.rangeEnd,
    );
    if (date != null) setState(() => _selectedDate = DateUtils.dateOnly(date));
  }

  List<(int, int)> _freeSlots(List<ScheduleEntry> entries) {
    const dayStart = 6 * 60;
    const dayEnd = 23 * 60;
    var cursor = dayStart;
    final gaps = <(int, int)>[];
    for (final entry in entries) {
      final start = entry.startMinute.clamp(dayStart, dayEnd).toInt();
      final end = entry.endMinute.clamp(dayStart, dayEnd).toInt();
      if (start > cursor) gaps.add((cursor, start));
      if (end > cursor) cursor = end;
    }
    if (cursor < dayEnd) gaps.add((cursor, dayEnd));
    return gaps.where((gap) => gap.$2 - gap.$1 >= 30).toList();
  }

  String _timeLabel(int minute) => TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final schedules = context.watch<ChallengeProvider>().schedules;
    final matches = schedules.where((item) => item.id == widget.scheduleId);
    if (matches.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('الجدول لم يعد موجودًا.')));
    }
    final plan = matches.first;
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = plan.containsDate(today) ? today : plan.rangeStart;
    final date = _selectedDate ?? initial;
    final entries = plan.onDate(date);
    final freeSlots = _freeSlots(entries);
    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surface, Color(0xFF43352B), AppColors.surface]),
              border: Border.all(color: AppColors.mustard.withValues(alpha: .4)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome, color: AppColors.mustard),
                const SizedBox(width: 8),
                Text(plan.period.label, style: const TextStyle(color: AppColors.tealLight, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 18),
              Text(_dateLabel(date), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('${entries.length} ${entries.length == 1 ? 'موعد' : 'مواعيد'} مخططة', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              Row(children: [
                IconButton(
                  tooltip: 'اليوم السابق',
                  onPressed: () => _changeDate(plan, -1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const Spacer(),
                TextButton.icon(onPressed: () => _pickDate(plan), icon: const Icon(Icons.calendar_month), label: const Text('اختيار يوم')),
                const Spacer(),
                IconButton(
                  tooltip: 'اليوم التالي',
                  onPressed: () => _changeDate(plan, 1),
                  icon: const Icon(Icons.chevron_left),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 22),
          Text('مواعيد اليوم', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Card(color: AppColors.surface, child: Padding(padding: EdgeInsets.all(18), child: Text('اليوم ده فاضي في جدولك. اختار نشاط أو خصص الوقت لتحدٍ.')))
          else
            ...entries.map((entry) => _TimelineEntry(entry: entry)),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('فترات متاحة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (freeSlots.isEmpty)
              const Text('مافيش فترة متاحة مدتها نصف ساعة أو أكتر بين ٦ صباحًا و١١ مساءً.', style: TextStyle(color: AppColors.muted))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final slot in freeSlots)
                  Chip(
                    avatar: const Icon(Icons.hourglass_empty, size: 17, color: AppColors.tealLight),
                    label: Text('${_timeLabel(slot.$1)} – ${_timeLabel(slot.$2)}'),
                    backgroundColor: AppColors.track,
                  ),
              ]),
          ],
          const SizedBox(height: 22),
          Text('الفترة كاملة · ${_rangeLabel(plan)}', style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ScheduleEntry entry;
  const _TimelineEntry({required this.entry});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: ListTile(
      leading: const Icon(Icons.schedule, color: AppColors.mustard),
      title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${entry.startTime.format(context)} – ${entry.endTime.format(context)}'),
      trailing: Container(width: 4, height: 38, decoration: BoxDecoration(color: AppColors.terracotta, borderRadius: BorderRadius.circular(8))),
    ),
  );
}
