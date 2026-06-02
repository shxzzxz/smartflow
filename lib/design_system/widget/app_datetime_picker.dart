import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_month_picker.dart';

const List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
const double _timeItemExtent = 34.0;
const int _loopBase = 120;

// ===== Public API =====

/// 仅选日期。返回的 [DateTime] 时分秒为 0。
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
}) async {
  final picked = await showDialog<int>(
    context: context,
    builder:
        (context) =>
            AppDayOfMonthPickerDialog(selectedDay: selectedDay, title: title),
  );
  if (picked == null) {
    return selectedDay;
  }
  return picked == 0 ? null : picked;
}

// ===== Date picker =====

class AppDatePickerDialog extends StatefulWidget {
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
  State<AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<AppDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final initial = _clampDateTime(
      widget.initialDate,
      widget.firstYear,
      widget.lastYear,
    );
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _visibleMonth = DateTime(initial.year, initial.month);
  }

  @override
  Widget build(BuildContext context) {
    return _PickerDialogShell(
      onCancel: () => Navigator.of(context).pop(),
      onConfirm:
          () => Navigator.of(context).pop(
            DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            ),
          ),
      children: [
        _CalendarPanel(
          visibleMonth: _visibleMonth,
          selectedDate: _selectedDate,
          onPreviousMonth: _canPreviousMonth ? _previousMonth : null,
          onNextMonth: _canNextMonth ? _nextMonth : null,
          onMonthPressed: _pickVisibleMonth,
          onDateSelected: (date) => setState(() => _selectedDate = date),
        ),
      ],
    );
  }

  bool get _canPreviousMonth =>
      _visibleMonth.year > widget.firstYear || _visibleMonth.month > 1;
  bool get _canNextMonth =>
      _visibleMonth.year < widget.lastYear || _visibleMonth.month < 12;

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  Future<void> _pickVisibleMonth() async {
    final picked = await showAppMonthPicker(
      context: context,
      initialMonth: _visibleMonth,
      firstYear: widget.firstYear,
      lastYear: widget.lastYear,
    );
    if (picked == null || !mounted) return;
    final selectedDay = _selectedDate.day.clamp(
      1,
      _daysInMonth(picked.year, picked.month),
    );
    setState(() {
      _visibleMonth = DateTime(picked.year, picked.month);
      _selectedDate = DateTime(picked.year, picked.month, selectedDay);
    });
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
      onCancel: () => Navigator.of(context).pop(),
      onConfirm:
          () => Navigator.of(
            context,
          ).pop(TimeOfDay(hour: _selectedHour, minute: _selectedMinute)),
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
  late DateTime _visibleMonth;
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
    _visibleMonth = DateTime(initial.year, initial.month);
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
      children: [
        _CalendarPanel(
          visibleMonth: _visibleMonth,
          selectedDate: _selectedDate,
          onPreviousMonth: _canPreviousMonth ? _previousMonth : null,
          onNextMonth: _canNextMonth ? _nextMonth : null,
          onMonthPressed: _pickVisibleMonth,
          onDateSelected: (date) => setState(() => _selectedDate = date),
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

  bool get _canPreviousMonth =>
      _visibleMonth.year > widget.firstYear || _visibleMonth.month > 1;
  bool get _canNextMonth =>
      _visibleMonth.year < widget.lastYear || _visibleMonth.month < 12;

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  Future<void> _pickVisibleMonth() async {
    final picked = await showAppMonthPicker(
      context: context,
      initialMonth: _visibleMonth,
      firstYear: widget.firstYear,
      lastYear: widget.lastYear,
    );
    if (picked == null || !mounted) return;
    final selectedDay = _selectedDate.day.clamp(
      1,
      _daysInMonth(picked.year, picked.month),
    );
    setState(() {
      _visibleMonth = DateTime(picked.year, picked.month);
      _selectedDate = DateTime(picked.year, picked.month, selectedDay);
    });
  }
}

// ===== Shared shell + reusable panels =====

class _PickerDialogShell extends StatelessWidget {
  const _PickerDialogShell({
    required this.children,
    required this.onCancel,
    required this.onConfirm,
  });

  final List<Widget> children;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight =
        MediaQuery.sizeOf(context).height - AppSpacing.space48;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
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
                const SizedBox(height: AppSpacing.space10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: onCancel, child: const Text('取消')),
                    const SizedBox(width: AppSpacing.space8),
                    FilledButton(onPressed: onConfirm, child: const Text('确定')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.visibleMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthPressed,
    this.onPreviousMonth,
    this.onNextMonth,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback onMonthPressed;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(visibleMonth);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _MonthArrowButton(
              icon: Icons.chevron_left,
              tooltip: '上个月',
              onPressed: onPreviousMonth,
            ),
            Expanded(
              child: InkWell(
                onTap: onMonthPressed,
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space6,
                    vertical: AppSpacing.space4,
                  ),
                  child: Text(
                    '${visibleMonth.year}年${visibleMonth.month}月',
                    textAlign: TextAlign.center,
                    style: context.appTextStyles.subsectionTitle,
                  ),
                ),
              ),
            ),
            _MonthArrowButton(
              icon: Icons.chevron_right,
              tooltip: '下个月',
              onPressed: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        Row(
          children: [
            for (final weekday in _weekdays)
              Expanded(
                child: Text(
                  weekday,
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.formLabel,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: AppSpacing.space2,
            crossAxisSpacing: AppSpacing.space2,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final date = days[index];
            if (date == null) {
              return const SizedBox.shrink();
            }
            return _CalendarDayButton(
              date: date,
              selected: _isSameDate(date, selectedDate),
              onTap: () => onDateSelected(date),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
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
            '${date.day}',
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

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: colors.onSurfaceVariant),
      iconSize: AppSpacing.space20,
      padding: const EdgeInsets.all(AppSpacing.space4),
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.space32,
        height: AppSpacing.space32,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ===== Day-of-month picker (unchanged) =====

class AppDayOfMonthPickerDialog extends StatefulWidget {
  const AppDayOfMonthPickerDialog({
    required this.selectedDay,
    required this.title,
    super.key,
  });

  final int? selectedDay;
  final String title;

  @override
  State<AppDayOfMonthPickerDialog> createState() =>
      _AppDayOfMonthPickerDialogState();
}

class _AppDayOfMonthPickerDialogState extends State<AppDayOfMonthPickerDialog> {
  late int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDay;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
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
                itemCount: 31,
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

List<DateTime?> _calendarDays(DateTime visibleMonth) {
  final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
  final dayCount = _daysInMonth(visibleMonth.year, visibleMonth.month);
  final leadingEmptyCount = firstDay.weekday - 1;
  final totalCount = _roundUpToWeek(leadingEmptyCount + dayCount);

  return List<DateTime?>.generate(totalCount, (index) {
    final day = index - leadingEmptyCount + 1;
    if (day < 1 || day > dayCount) {
      return null;
    }
    return DateTime(visibleMonth.year, visibleMonth.month, day);
  });
}

int _roundUpToWeek(int value) {
  final remainder = value % 7;
  return remainder == 0 ? value : value + 7 - remainder;
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _two(int value) => value.toString().padLeft(2, '0');
