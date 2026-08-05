import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_date_picker_panel.dart';
import '../../../design_system/widget/app_dropdown.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../view_model/statistics_view_model.dart';

class StatisticsPeriodSelection {
  const StatisticsPeriodSelection({
    required this.granularity,
    required this.mode,
    required this.from,
    required this.untilExclusive,
  });

  final StatisticsPeriodGranularity granularity;
  final StatisticsPeriodMode mode;
  final DateTime from;
  final DateTime untilExclusive;
}

/// 统计周期选择弹层：粒度下拉（年/月/日）+ 单个/范围切换 + 统一日期面板。
/// 单个模式点选即回传，范围模式选定起止后确认。
Future<StatisticsPeriodSelection?> showStatisticsPeriodSheet({
  required BuildContext context,
  required StatisticsPeriodGranularity granularity,
  required StatisticsPeriodMode mode,
  required DateTime from,
  required DateTime untilExclusive,
  required DateTime lastSelectableDate,
}) {
  return showModalBottomSheet<StatisticsPeriodSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (context) => _StatisticsPeriodSheet(
          granularity: granularity,
          mode: mode,
          from: from,
          untilExclusive: untilExclusive,
          lastSelectableDate: lastSelectableDate,
        ),
  );
}

class _StatisticsPeriodSheet extends StatefulWidget {
  const _StatisticsPeriodSheet({
    required this.granularity,
    required this.mode,
    required this.from,
    required this.untilExclusive,
    required this.lastSelectableDate,
  });

  final StatisticsPeriodGranularity granularity;
  final StatisticsPeriodMode mode;
  final DateTime from;
  final DateTime untilExclusive;
  final DateTime lastSelectableDate;

  @override
  State<_StatisticsPeriodSheet> createState() => _StatisticsPeriodSheetState();
}

class _StatisticsPeriodSheetState extends State<_StatisticsPeriodSheet> {
  late StatisticsPeriodGranularity _granularity;
  late StatisticsPeriodMode _mode;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    _granularity = widget.granularity;
    _mode = widget.mode;
    _rangeStart = _periodStart(widget.from);
    _rangeEnd = _periodStart(
      widget.untilExclusive.subtract(const Duration(days: 1)),
    );
    if (_rangeEnd.isBefore(_rangeStart)) _rangeEnd = _rangeStart;
  }

  @override
  Widget build(BuildContext context) {
    final panelGranularity = switch (_granularity) {
      StatisticsPeriodGranularity.year => AppDatePickerGranularity.year,
      StatisticsPeriodGranularity.month => AppDatePickerGranularity.month,
      StatisticsPeriodGranularity.date => AppDatePickerGranularity.date,
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space20,
          0,
          AppSpacing.space20,
          AppSpacing.space20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppDropdown<StatisticsPeriodGranularity>(
                  tooltip: '选择粒度',
                  options: const [
                    AppSelectOption(
                      value: StatisticsPeriodGranularity.year,
                      label: '年',
                    ),
                    AppSelectOption(
                      value: StatisticsPeriodGranularity.month,
                      label: '月',
                    ),
                    AppSelectOption(
                      value: StatisticsPeriodGranularity.date,
                      label: '日',
                    ),
                  ],
                  value: _granularity,
                  onChanged: _selectGranularity,
                ),
                const Spacer(),
                AppSlidingSegmentedControl<StatisticsPeriodMode>(
                  segments: const [
                    AppSegment(value: StatisticsPeriodMode.single, label: '单个'),
                    AppSegment(value: StatisticsPeriodMode.range, label: '范围'),
                  ],
                  selected: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            AppDatePickerPanel(
              key: ValueKey((_granularity, _mode)),
              granularity: panelGranularity,
              mode:
                  _mode == StatisticsPeriodMode.single
                      ? AppDatePickerMode.single
                      : AppDatePickerMode.range,
              initialValue: _rangeStart,
              initialRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
              firstDate: DateTime(2000),
              lastDate: widget.lastSelectableDate,
              onSelected: _confirmSingle,
              onRangeChanged:
                  (range, _) => setState(() {
                    _rangeStart = range.start;
                    _rangeEnd = range.end;
                  }),
            ),
            if (_mode == StatisticsPeriodMode.range) ...[
              const SizedBox(height: AppSpacing.space12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _rangeLabel,
                      style: context.appTextStyles.subsectionTitleStrong,
                    ),
                  ),
                  FilledButton(
                    onPressed: _confirmRange,
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectGranularity(StatisticsPeriodGranularity granularity) {
    setState(() {
      _granularity = granularity;
      _rangeStart = _periodStart(_rangeStart);
      _rangeEnd = _periodStart(_rangeEnd);
    });
  }

  String get _rangeLabel {
    final lastDay = _periodUntil(_rangeEnd).subtract(const Duration(days: 1));
    return '${_rangeStart.year}.${_rangeStart.month}.${_rangeStart.day} - '
        '${lastDay.year}.${lastDay.month}.${lastDay.day}';
  }

  void _confirmSingle(DateTime periodStart) {
    Navigator.of(context).pop(
      StatisticsPeriodSelection(
        granularity: _granularity,
        mode: StatisticsPeriodMode.single,
        from: periodStart,
        untilExclusive: _periodUntil(periodStart),
      ),
    );
  }

  void _confirmRange() {
    Navigator.of(context).pop(
      StatisticsPeriodSelection(
        granularity: _granularity,
        mode: StatisticsPeriodMode.range,
        from: _rangeStart,
        untilExclusive: _periodUntil(_rangeEnd),
      ),
    );
  }

  DateTime _periodStart(DateTime date) => switch (_granularity) {
    StatisticsPeriodGranularity.year => DateTime(date.year),
    StatisticsPeriodGranularity.month => DateTime(date.year, date.month),
    StatisticsPeriodGranularity.date => DateTime(
      date.year,
      date.month,
      date.day,
    ),
  };

  DateTime _periodUntil(DateTime periodStart) => switch (_granularity) {
    StatisticsPeriodGranularity.year => DateTime(periodStart.year + 1),
    StatisticsPeriodGranularity.month => DateTime(
      periodStart.year,
      periodStart.month + 1,
    ),
    StatisticsPeriodGranularity.date => DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day + 1,
    ),
  };
}
