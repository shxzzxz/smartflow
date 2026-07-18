import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

const double _wheelItemExtent = 44;
const double _wheelPanelHeight = 220;
const double _wheelDialogMaxWidth = 360;
const double _wheelSelectionOverlayOpacity = 0.26;

class AppMonthSelector extends StatelessWidget {
  const AppMonthSelector({
    required this.visibleMonth,
    required this.onPreviousMonth,
    required this.onMonthPressed,
    required this.onNextMonth,
    super.key,
  });

  final DateTime visibleMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onMonthPressed;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthArrowButton(
          icon: Icons.chevron_left,
          tooltip: '上个月',
          onPressed: onPreviousMonth,
        ),
        InkWell(
          onTap: onMonthPressed,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space6,
            ),
            child: Text(
              '${visibleMonth.year}年${visibleMonth.month}月',
              style: context.appTextStyles.dateNavigationTitle,
            ),
          ),
        ),
        _MonthArrowButton(
          icon: Icons.chevron_right,
          tooltip: '下个月',
          onPressed: onNextMonth,
        ),
      ],
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
  final VoidCallback onPressed;

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
        width: AppSpacing.space28,
        height: AppSpacing.space32,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

Future<DateTime?> showAppMonthPicker({
  required BuildContext context,
  required DateTime initialMonth,
  int firstYear = 2000,
  int lastYear = 2100,
  String title = '选择月份',
}) {
  return showDialog<DateTime>(
    context: context,
    builder:
        (context) => AppMonthPickerDialog(
          initialMonth: initialMonth,
          firstYear: firstYear,
          lastYear: lastYear,
          title: title,
        ),
  );
}

Future<int?> showAppYearPicker({
  required BuildContext context,
  required int initialYear,
  int firstYear = 2000,
  int lastYear = 2100,
  String title = '选择年份',
}) {
  return showDialog<int>(
    context: context,
    builder:
        (context) => AppYearPickerDialog(
          initialYear: initialYear,
          firstYear: firstYear,
          lastYear: lastYear,
          title: title,
        ),
  );
}

class AppYearPickerDialog extends StatefulWidget {
  const AppYearPickerDialog({
    required this.initialYear,
    required this.firstYear,
    required this.lastYear,
    required this.title,
    super.key,
  });

  final int initialYear;
  final int firstYear;
  final int lastYear;
  final String title;

  @override
  State<AppYearPickerDialog> createState() => _AppYearPickerDialogState();
}

class _AppYearPickerDialogState extends State<AppYearPickerDialog> {
  late int _selectedYear;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear.clamp(widget.firstYear, widget.lastYear);
    _controller = FixedExtentScrollController(
      initialItem: _selectedYear - widget.firstYear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearCount = widget.lastYear - widget.firstYear + 1;
    return _WheelPickerDialogShell(
      title: widget.title,
      onConfirm: () => Navigator.of(context).pop(_selectedYear),
      child: _WheelPicker(
        controller: _controller,
        itemCount: yearCount,
        selectedIndex: _selectedYear - widget.firstYear,
        itemExtent: _wheelItemExtent,
        labelBuilder: (index) => '${widget.firstYear + index}年',
        onSelectedItemChanged:
            (index) => setState(() => _selectedYear = widget.firstYear + index),
      ),
    );
  }
}

class AppMonthPickerDialog extends StatefulWidget {
  const AppMonthPickerDialog({
    required this.initialMonth,
    required this.firstYear,
    required this.lastYear,
    required this.title,
    super.key,
  });

  final DateTime initialMonth;
  final int firstYear;
  final int lastYear;
  final String title;

  @override
  State<AppMonthPickerDialog> createState() => _AppMonthPickerDialogState();
}

class _AppMonthPickerDialogState extends State<AppMonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialMonth.year;
    _selectedMonth = widget.initialMonth.month;
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - widget.firstYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearCount = widget.lastYear - widget.firstYear + 1;
    return _WheelPickerDialogShell(
      onConfirm:
          () => Navigator.of(
            context,
          ).pop(DateTime(_selectedYear, _selectedMonth)),
      child: Row(
        children: [
          Expanded(
            child: _WheelPicker(
              controller: _yearController,
              itemCount: yearCount,
              selectedIndex: _selectedYear - widget.firstYear,
              itemExtent: _wheelItemExtent,
              labelBuilder: (index) => '${widget.firstYear + index}年',
              onSelectedItemChanged:
                  (index) =>
                      setState(() => _selectedYear = widget.firstYear + index),
            ),
          ),
          Expanded(
            child: _WheelPicker(
              controller: _monthController,
              itemCount: 12,
              selectedIndex: _selectedMonth - 1,
              itemExtent: _wheelItemExtent,
              labelBuilder: (index) => '${index + 1}月',
              onSelectedItemChanged:
                  (index) => setState(() => _selectedMonth = index + 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPickerDialogShell extends StatelessWidget {
  const _WheelPickerDialogShell({
    required this.child,
    required this.onConfirm,
    this.title,
  });

  final Widget child;
  final VoidCallback onConfirm;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _wheelDialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space20,
            AppSpacing.space20,
            AppSpacing.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.subsectionTitle,
                ),
                const SizedBox(height: AppSpacing.space12),
              ],
              SizedBox(
                height: _wheelPanelHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: _wheelItemExtent,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(
                          alpha: _wheelSelectionOverlayOpacity,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child,
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  FilledButton(onPressed: onConfirm, child: const Text('确定')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPicker extends StatelessWidget {
  const _WheelPicker({
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
      diameterRatio: 1.35,
      perspective: 0.003,
      overAndUnderCenterOpacity: 0.42,
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final selected = index == selectedIndex;
          return Center(
            child: Text(
              labelBuilder(index),
              style: context.appTextStyles
                  .segmentedControlLabel(selected: selected)
                  .copyWith(
                    color:
                        selected ? colors.onSurface : colors.onSurfaceVariant,
                  ),
            ),
          );
        },
      ),
    );
  }
}
