import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_date_picker_panel.dart';

const double _timeItemExtent = 34.0;
const int _loopBase = 120;

// ===== Public API =====

/// 仅选日期，点选即回传。返回的 [DateTime] 时分秒为 0。
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  int firstYear = 2000,
  int lastYear = 2100,
  String title = '选择日期',
}) {
  return showDialog<DateTime>(
    context: context,
    builder:
        (context) => AppDatePickerDialog(
          initialDate: initialDate,
          firstYear: firstYear,
          lastYear: lastYear,
          title: title,
        ),
  );
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder:
        (context) => AppDateRangePickerDialog(
          initialRange: initialRange,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
  );
}

/// 仅选时分。
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = '选择时间',
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder:
        (context) =>
            AppTimePickerDialog(initialTime: initialTime, title: title),
  );
}

/// 同时选日期与时分。
Future<DateTime?> showAppDateTimePicker({
  required BuildContext context,
  required DateTime initialDateTime,
  int firstYear = 2000,
  int lastYear = 2100,
  String title = '选择时间',
}) {
  return showDialog<DateTime>(
    context: context,
    builder:
        (context) => AppDateTimePickerDialog(
          initialDateTime: initialDateTime,
          firstYear: firstYear,
          lastYear: lastYear,
          title: title,
        ),
  );
}

Future<int?> showAppDayOfMonthPicker({
  required BuildContext context,
  required int? selectedDay,
  String title = '选择日期',
  int maxDay = 31,
}) async {
  final picked = await showDialog<int>(
    context: context,
    builder:
        (context) => AppDayOfMonthPickerDialog(
          selectedDay: selectedDay,
          title: title,
          maxDay: maxDay,
        ),
  );
  if (picked == null) {
    return selectedDay;
  }
  return picked == 0 ? null : picked;
}

// ===== Date picker =====

class AppDatePickerDialog extends StatelessWidget {
  const AppDatePickerDialog({
    required this.initialDate,
    this.firstYear = 2000,
    this.lastYear = 2100,
    this.title = '选择日期',
    super.key,
  });

  final DateTime initialDate;
  final int firstYear;
  final int lastYear;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _PickerDialogShell(
      children: [
        _TitleBar(title: title),
        const SizedBox(height: AppSpacing.space4),
        AppDatePickerPanel(
          granularity: AppDatePickerGranularity.date,
          initialValue: initialDate,
          firstDate: DateTime(firstYear),
          lastDate: DateTime(lastYear, 12, 31),
          onSelected: (date) => Navigator.of(context).pop(date),
        ),
      ],
    );
  }
}

class AppDateRangePickerDialog extends StatefulWidget {
  const AppDateRangePickerDialog({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    super.key,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<AppDateRangePickerDialog> createState() =>
      _AppDateRangePickerDialogState();
}

class _AppDateRangePickerDialogState extends State<AppDateRangePickerDialog> {
  late DateTime _start;
  late DateTime _end;
  bool _selectingEnd = false;

  @override
  void initState() {
    super.initState();
    _start = _clampDate(widget.initialRange.start);
    _end = _clampDate(widget.initialRange.end);
    if (_end.isBefore(_start)) _end = _start;
  }

  @override
  Widget build(BuildContext context) {
    return _PickerDialogShell(
      footer: _DialogFooter(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm:
            () => Navigator.of(
              context,
            ).pop(DateTimeRange(start: _start, end: _end)),
      ),
      children: [
        _RangeSummary(start: _start, end: _end, selectingEnd: _selectingEnd),
        const SizedBox(height: AppSpacing.space8),
        AppDatePickerPanel(
          granularity: AppDatePickerGranularity.date,
          mode: AppDatePickerMode.range,
          initialRange: DateTimeRange(start: _start, end: _end),
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onRangeChanged:
              (range, isComplete) => setState(() {
                _start = range.start;
                _end = range.end;
                _selectingEnd = !isComplete;
              }),
        ),
      ],
    );
  }

  DateTime _clampDate(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final first = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final last = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }
}

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({
    required this.start,
    required this.end,
    required this.selectingEnd,
  });

  final DateTime start;
  final DateTime end;
  final bool selectingEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space10,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _RangeDateValue(label: '开始', date: start)),
              const SizedBox(width: AppSpacing.space16),
              Expanded(child: _RangeDateValue(label: '结束', date: end)),
            ],
          ),
          if (selectingEnd) ...[
            const SizedBox(height: AppSpacing.space6),
            Text(
              '请选择结束日期',
              style: context.appTextStyles.listSupporting.copyWith(
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeDateValue extends StatelessWidget {
  const _RangeDateValue({required this.label, required this.date});

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.appTextStyles.listSupporting.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          '${date.year}.${date.month}.${date.day}',
          style: context.appTextStyles.detailValue,
        ),
      ],
    );
  }
}

// ===== Time picker =====

class AppTimePickerDialog extends StatefulWidget {
  const AppTimePickerDialog({
    required this.initialTime,
    this.title = '选择时间',
    super.key,
  });

  final TimeOfDay initialTime;
  final String title;

  @override
  State<AppTimePickerDialog> createState() => _AppTimePickerDialogState();
}

class _AppTimePickerDialogState extends State<AppTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(
      initialItem: _loopInitialItem(_selectedHour, 24),
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _loopInitialItem(_selectedMinute, 60),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PickerDialogShell(
      footer: _DialogFooter(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm:
            () => Navigator.of(
              context,
            ).pop(TimeOfDay(hour: _selectedHour, minute: _selectedMinute)),
      ),
      children: [
        _TitleBar(title: widget.title),
        const SizedBox(height: AppSpacing.space6),
        _TimeWheelPanel(
          selectedHour: _selectedHour,
          selectedMinute: _selectedMinute,
          hourController: _hourController,
          minuteController: _minuteController,
          itemExtent: _timeItemExtent,
          onHourChanged: (hour) => setState(() => _selectedHour = hour),
          onMinuteChanged: (minute) => setState(() => _selectedMinute = minute),
        ),
      ],
    );
  }
}

// ===== Combined date + time picker =====

class AppDateTimePickerDialog extends StatefulWidget {
  const AppDateTimePickerDialog({
    required this.initialDateTime,
    this.firstYear = 2000,
    this.lastYear = 2100,
    this.title = '选择时间',
    super.key,
  });

  final DateTime initialDateTime;
  final int firstYear;
  final int lastYear;
  final String title;

  @override
  State<AppDateTimePickerDialog> createState() =>
      _AppDateTimePickerDialogState();
}

class _AppDateTimePickerDialogState extends State<AppDateTimePickerDialog> {
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final initial = _clampDateTime(
      widget.initialDateTime,
      widget.firstYear,
      widget.lastYear,
    );
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _selectedHour = initial.hour;
    _selectedMinute = initial.minute;
    _hourController = FixedExtentScrollController(
      initialItem: _loopInitialItem(_selectedHour, 24),
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _loopInitialItem(_selectedMinute, 60),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PickerDialogShell(
      footer: _DialogFooter(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm:
            () => Navigator.of(context).pop(
              DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _selectedHour,
                _selectedMinute,
              ),
            ),
      ),
      children: [
        AppDatePickerPanel(
          granularity: AppDatePickerGranularity.date,
          initialValue: _selectedDate,
          firstDate: DateTime(widget.firstYear),
          lastDate: DateTime(widget.lastYear, 12, 31),
          onSelected: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: AppSpacing.space10),
        _TimeWheelPanel(
          selectedHour: _selectedHour,
          selectedMinute: _selectedMinute,
          hourController: _hourController,
          minuteController: _minuteController,
          itemExtent: _timeItemExtent,
          onHourChanged: (hour) => setState(() => _selectedHour = hour),
          onMinuteChanged: (minute) => setState(() => _selectedMinute = minute),
        ),
      ],
    );
  }
}

// ===== Shared shell + reusable panels =====

class _PickerDialogShell extends StatelessWidget {
  const _PickerDialogShell({required this.children, this.footer});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight =
        MediaQuery.sizeOf(context).height - AppSpacing.space48;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 336, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space12,
              AppSpacing.space12,
              AppSpacing.space12,
              AppSpacing.space10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.space10),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: onCancel, child: const Text('取消')),
        const SizedBox(width: AppSpacing.space8),
        FilledButton(onPressed: onConfirm, child: const Text('确定')),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: AppSpacing.space4,
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: context.appTextStyles.subsectionTitle,
      ),
    );
  }
}

class _TimeWheelPanel extends StatelessWidget {
  const _TimeWheelPanel({
    required this.selectedHour,
    required this.selectedMinute,
    required this.hourController,
    required this.minuteController,
    required this.itemExtent,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final int selectedHour;
  final int selectedMinute;
  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final double itemExtent;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 102,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: itemExtent,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _TimeWheel(
                  controller: hourController,
                  itemCount: 24,
                  selectedIndex: selectedHour,
                  itemExtent: itemExtent,
                  labelBuilder: (index) => '${_two(index)} 时',
                  onSelectedItemChanged: onHourChanged,
                ),
              ),
              Expanded(
                child: _TimeWheel(
                  controller: minuteController,
                  itemCount: 60,
                  selectedIndex: selectedMinute,
                  itemExtent: itemExtent,
                  labelBuilder: (index) => '${_two(index)} 分',
                  onSelectedItemChanged: onMinuteChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.controller,
    required this.itemCount,
    required this.selectedIndex,
    required this.itemExtent,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final int selectedIndex;
  final double itemExtent;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.25,
      perspective: 0.003,
      overAndUnderCenterOpacity: 0.42,
      onSelectedItemChanged:
          (index) => onSelectedItemChanged(index % itemCount),
      childDelegate: ListWheelChildLoopingListDelegate(
        children: [
          for (var index = 0; index < itemCount; index++)
            Center(
              child: Text(
                labelBuilder(index),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles
                    .segmentedControlLabel(selected: index == selectedIndex)
                    .copyWith(
                      color:
                          index == selectedIndex
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== Day-of-month picker (unchanged) =====

class AppDayOfMonthPickerDialog extends StatefulWidget {
  const AppDayOfMonthPickerDialog({
    required this.selectedDay,
    required this.title,
    this.maxDay = 31,
    super.key,
  });

  final int? selectedDay;
  final String title;
  final int maxDay;

  @override
  State<AppDayOfMonthPickerDialog> createState() =>
      _AppDayOfMonthPickerDialogState();
}

class _AppDayOfMonthPickerDialogState extends State<AppDayOfMonthPickerDialog> {
  late int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDay?.clamp(1, widget.maxDay);
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight =
        MediaQuery.sizeOf(context).height - AppSpacing.space48;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 336, maxHeight: maxDialogHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space12,
            AppSpacing.space12,
            AppSpacing.space12,
            AppSpacing.space10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space6,
                  vertical: AppSpacing.space4,
                ),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.subsectionTitle,
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.maxDay,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: AppSpacing.space2,
                  crossAxisSpacing: AppSpacing.space2,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final day = index + 1;
                  return _DayOfMonthButton(
                    day: day,
                    selected: day == _selectedDay,
                    onTap: () => setState(() => _selectedDay = day),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.space10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(0),
                    child: const Text('不设置'),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDay),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayOfMonthButton extends StatelessWidget {
  const _DayOfMonthButton({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        child: Center(
          child: Text(
            '$day',
            style: context.appTextStyles.detailValue.copyWith(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Utilities =====

DateTime _clampDateTime(DateTime value, int firstYear, int lastYear) {
  final first = DateTime(firstYear);
  final last = DateTime(lastYear, 12, 31, 23, 59);
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}

int _loopInitialItem(int value, int itemCount) {
  return itemCount * _loopBase + value;
}

String _two(int value) => value.toString().padLeft(2, '0');
