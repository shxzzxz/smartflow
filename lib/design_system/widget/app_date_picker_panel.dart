import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

const List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
const double _headerArrowIconSize = AppSpacing.space20;
const double _gridCellAspectRatio = 2.2;

/// 面板粒度：日 / 月 / 年。
enum AppDatePickerGranularity { date, month, year }

/// 选择模式：单个周期 / 连续范围。
enum AppDatePickerMode { single, range }

/// antd 风格的统一日期面板：宫格主体 + 头部标题钻取导航
/// （日历格点标题进入月宫格，月宫格点标题进入年宫格，年宫格点标题进入十年宫格）。
///
/// 所有回调值均为所选周期的起始日（月为当月 1 日，年为当年 1 月 1 日），
/// 完整区间由调用方按粒度换算。
class AppDatePickerPanel extends StatefulWidget {
  const AppDatePickerPanel({
    required this.granularity,
    this.mode = AppDatePickerMode.single,
    this.initialValue,
    this.initialRange,
    this.firstDate,
    this.lastDate,
    this.onSelected,
    this.onRangeChanged,
    super.key,
  });

  final AppDatePickerGranularity granularity;
  final AppDatePickerMode mode;

  /// 单选模式的初始值。
  final DateTime? initialValue;

  /// 范围模式的初始范围（start / end 为周期起始日，按粒度归一）。
  final DateTimeRange? initialRange;

  final DateTime? firstDate;
  final DateTime? lastDate;

  /// 单选模式点选即回调。
  final ValueChanged<DateTime>? onSelected;

  /// 范围模式每次点选端点后回调；[isComplete] 表示起止均已选定。
  final void Function(DateTimeRange range, bool isComplete)? onRangeChanged;

  @override
  State<AppDatePickerPanel> createState() => _AppDatePickerPanelState();
}

enum _PanelView { day, month, year, decade }

class _AppDatePickerPanelState extends State<AppDatePickerPanel> {
  late _PanelView _view;
  late DateTime _anchor;
  DateTime? _selected;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _selectingEnd = false;

  _PanelView get _baseView => switch (widget.granularity) {
    AppDatePickerGranularity.date => _PanelView.day,
    AppDatePickerGranularity.month => _PanelView.month,
    AppDatePickerGranularity.year => _PanelView.year,
  };

  DateTime get _firstDate => widget.firstDate ?? DateTime(2000);
  DateTime get _lastDate => widget.lastDate ?? DateTime(2100, 12, 31);

  @override
  void initState() {
    super.initState();
    _view = _baseView;
    if (widget.mode == AppDatePickerMode.single) {
      final initial = widget.initialValue ?? DateTime.now();
      _selected = _periodStart(_clamp(initial));
      _anchor = _selected!;
    } else {
      final range = widget.initialRange;
      if (range != null) {
        _rangeStart = _periodStart(_clamp(range.start));
        _rangeEnd = _periodStart(_clamp(range.end));
        if (_rangeEnd!.isBefore(_rangeStart!)) _rangeEnd = _rangeStart;
      }
      _anchor = _rangeStart ?? _periodStart(_clamp(DateTime.now()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        const SizedBox(height: AppSpacing.space4),
        switch (_view) {
          _PanelView.day => _buildDayGrid(context),
          _PanelView.month => _buildMonthGrid(context),
          _PanelView.year => _buildYearGrid(context),
          _PanelView.decade => _buildDecadeGrid(context),
        },
      ],
    );
  }

  // ===== Header =====

  Widget _buildHeader(BuildContext context) {
    final (title, canDrillUp) = switch (_view) {
      _PanelView.day => ('${_anchor.year}年${_anchor.month}月', true),
      _PanelView.month => ('${_anchor.year}年', true),
      _PanelView.year => ('${_decadeStart(_anchor.year)}-'
          '${_decadeStart(_anchor.year) + 9}', true),
      _PanelView.decade => ('${_centuryStart(_anchor.year)}-'
          '${_centuryStart(_anchor.year) + 99}', false),
    };
    final showMonthArrows = _view == _PanelView.day;
    final yearStep = switch (_view) {
      _PanelView.day || _PanelView.month => 1,
      _PanelView.year => 10,
      _PanelView.decade => 100,
    };

    return Row(
      children: [
        if (showMonthArrows)
          _HeaderArrowButton(
            icon: Icons.keyboard_double_arrow_left,
            tooltip: '上一年',
            onPressed: _canShiftAnchor(years: -1) ? () => _shiftAnchor(years: -1) : null,
          ),
        _HeaderArrowButton(
          icon: Icons.chevron_left,
          tooltip: showMonthArrows ? '上个月' : '向前',
          onPressed: showMonthArrows
              ? (_canShiftAnchor(months: -1) ? () => _shiftAnchor(months: -1) : null)
              : (_canShiftAnchor(years: -yearStep)
                  ? () => _shiftAnchor(years: -yearStep)
                  : null),
        ),
        Expanded(
          child: InkWell(
            onTap: canDrillUp ? _drillUp : null,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space6,
                vertical: AppSpacing.space4,
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.appTextStyles.subsectionTitle,
              ),
            ),
          ),
        ),
        _HeaderArrowButton(
          icon: Icons.chevron_right,
          tooltip: showMonthArrows ? '下个月' : '向后',
          onPressed: showMonthArrows
              ? (_canShiftAnchor(months: 1) ? () => _shiftAnchor(months: 1) : null)
              : (_canShiftAnchor(years: yearStep)
                  ? () => _shiftAnchor(years: yearStep)
                  : null),
        ),
        if (showMonthArrows)
          _HeaderArrowButton(
            icon: Icons.keyboard_double_arrow_right,
            tooltip: '下一年',
            onPressed: _canShiftAnchor(years: 1) ? () => _shiftAnchor(years: 1) : null,
          ),
      ],
    );
  }

  void _drillUp() {
    setState(() {
      _view = switch (_view) {
        _PanelView.day => _PanelView.month,
        _PanelView.month => _PanelView.year,
        _PanelView.year || _PanelView.decade => _PanelView.decade,
      };
    });
  }

  bool _canShiftAnchor({int years = 0, int months = 0}) {
    final shifted = DateTime(_anchor.year + years, _anchor.month + months);
    return switch (_view) {
      _PanelView.day =>
        !DateTime(shifted.year, shifted.month + 1)
                .isBefore(DateTime(_firstDate.year, _firstDate.month + 1)) &&
            !DateTime(shifted.year, shifted.month)
                .isAfter(DateTime(_lastDate.year, _lastDate.month)),
      _PanelView.month =>
        shifted.year >= _firstDate.year && shifted.year <= _lastDate.year,
      _PanelView.year =>
        _decadeStart(shifted.year) + 9 >= _firstDate.year &&
            _decadeStart(shifted.year) <= _lastDate.year,
      _PanelView.decade =>
        _centuryStart(shifted.year) + 99 >= _firstDate.year &&
            _centuryStart(shifted.year) <= _lastDate.year,
    };
  }

  void _shiftAnchor({int years = 0, int months = 0}) {
    setState(() {
      _anchor = DateTime(_anchor.year + years, _anchor.month + months);
    });
  }

  // ===== Grids =====

  Widget _buildDayGrid(BuildContext context) {
    final days = _calendarDays(_anchor);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            if (date == null) return const SizedBox.shrink();
            return _buildPeriodCell(
              context,
              periodStart: date,
              label: '${date.day}',
            );
          },
        ),
      ],
    );
  }

  Widget _buildMonthGrid(BuildContext context) {
    return _buildThreeColumnGrid(context, [
      for (var month = 1; month <= 12; month++)
        (periodStart: DateTime(_anchor.year, month), label: '$month月', dimmed: false),
    ]);
  }

  Widget _buildYearGrid(BuildContext context) {
    final start = _decadeStart(_anchor.year);
    return _buildThreeColumnGrid(context, [
      for (var year = start - 1; year <= start + 10; year++)
        (
          periodStart: DateTime(year),
          label: '$year',
          dimmed: year < start || year > start + 9,
        ),
    ]);
  }

  Widget _buildDecadeGrid(BuildContext context) {
    final start = _centuryStart(_anchor.year);
    return _buildThreeColumnGrid(context, [
      for (var decade = start - 10; decade <= start + 100; decade += 10)
        (
          periodStart: DateTime(decade),
          label: '$decade-${decade + 9}',
          dimmed: decade < start || decade > start + 90,
        ),
    ]);
  }

  Widget _buildThreeColumnGrid(
    BuildContext context,
    List<({DateTime periodStart, String label, bool dimmed})> cells,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.space4,
        crossAxisSpacing: AppSpacing.space4,
        childAspectRatio: _gridCellAspectRatio,
      ),
      itemBuilder: (context, index) {
        final cell = cells[index];
        return _buildPeriodCell(
          context,
          periodStart: cell.periodStart,
          label: cell.label,
          dimmed: cell.dimmed,
        );
      },
    );
  }

  Widget _buildPeriodCell(
    BuildContext context, {
    required DateTime periodStart,
    required String label,
    bool dimmed = false,
  }) {
    final atBaseView = _view == _baseView;
    final enabled = _isViewPeriodEnabled(periodStart);
    final selected =
        atBaseView &&
        (widget.mode == AppDatePickerMode.single
            ? _isSamePeriod(periodStart, _selected)
            : _isSamePeriod(periodStart, _rangeStart) ||
                _isSamePeriod(periodStart, _rangeEnd));
    final inRange =
        atBaseView &&
        widget.mode == AppDatePickerMode.range &&
        _rangeStart != null &&
        _rangeEnd != null &&
        periodStart.isAfter(_rangeStart!) &&
        periodStart.isBefore(_rangeEnd!);
    return _PanelCell(
      label: label,
      selected: selected,
      inRange: inRange,
      dimmed: dimmed,
      isCurrent: atBaseView && _isSamePeriod(periodStart, _viewPeriodStartOfNow()),
      onTap: enabled ? () => _onCellTap(periodStart) : null,
    );
  }

  void _onCellTap(DateTime periodStart) {
    if (_view != _baseView) {
      setState(() {
        _anchor = periodStart;
        _view = switch (_view) {
          _PanelView.decade => _PanelView.year,
          _PanelView.year =>
            _baseView == _PanelView.year ? _PanelView.year : _PanelView.month,
          _PanelView.month || _PanelView.day => _PanelView.day,
        };
      });
      return;
    }
    if (widget.mode == AppDatePickerMode.single) {
      setState(() {
        _selected = periodStart;
        _anchor = periodStart;
      });
      widget.onSelected?.call(periodStart);
      return;
    }
    setState(() {
      if (!_selectingEnd || _rangeStart == null) {
        _rangeStart = periodStart;
        _rangeEnd = periodStart;
        _selectingEnd = true;
      } else if (periodStart.isBefore(_rangeStart!)) {
        _rangeStart = periodStart;
        _rangeEnd = periodStart;
      } else {
        _rangeEnd = periodStart;
        _selectingEnd = false;
      }
    });
    widget.onRangeChanged?.call(
      DateTimeRange(start: _rangeStart!, end: _rangeEnd!),
      !_selectingEnd,
    );
  }

  // ===== Period math =====

  DateTime _periodStart(DateTime date) => switch (widget.granularity) {
    AppDatePickerGranularity.date => DateTime(date.year, date.month, date.day),
    AppDatePickerGranularity.month => DateTime(date.year, date.month),
    AppDatePickerGranularity.year => DateTime(date.year),
  };

  /// 当前视图层级的周期起始（钻取上层时按上层粒度归一）。
  DateTime _viewPeriodStart(DateTime date) => switch (_view) {
    _PanelView.day => DateTime(date.year, date.month, date.day),
    _PanelView.month => DateTime(date.year, date.month),
    _PanelView.year => DateTime(date.year),
    _PanelView.decade => DateTime(_decadeStart(date.year)),
  };

  DateTime _viewPeriodStartOfNow() => _viewPeriodStart(DateTime.now());

  bool _isViewPeriodEnabled(DateTime periodStart) {
    return !periodStart.isAfter(_viewPeriodStart(_lastDate)) &&
        !periodStart.isBefore(_viewPeriodStart(_firstDate));
  }

  bool _isSamePeriod(DateTime a, DateTime? b) {
    return b != null && _viewPeriodStart(a) == _viewPeriodStart(b);
  }

  DateTime _clamp(DateTime value) {
    if (value.isBefore(_firstDate)) return _firstDate;
    if (value.isAfter(_lastDate)) return _lastDate;
    return value;
  }
}

class _PanelCell extends StatelessWidget {
  const _PanelCell({
    required this.label,
    required this.selected,
    required this.inRange,
    required this.dimmed,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool inRange;
  final bool dimmed;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color:
          selected
              ? colors.primary
              : inRange
              ? colors.primaryContainer
              : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            border:
                isCurrent && !selected
                    ? Border.all(color: colors.primary)
                    : null,
          ),
          child: Center(
            child: Text(
              label,
              style: context.appTextStyles.detailValue.copyWith(
                color:
                    onTap == null || dimmed
                        ? colors.onSurfaceVariant
                        : selected
                        ? colors.onPrimary
                        : colors.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderArrowButton extends StatelessWidget {
  const _HeaderArrowButton({
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
      iconSize: _headerArrowIconSize,
      padding: const EdgeInsets.all(AppSpacing.space4),
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.space32,
        height: AppSpacing.space32,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

List<DateTime?> _calendarDays(DateTime visibleMonth) {
  final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
  final dayCount = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
  final leadingEmptyCount = firstDay.weekday - 1;
  final remainder = (leadingEmptyCount + dayCount) % 7;
  final totalCount =
      leadingEmptyCount + dayCount + (remainder == 0 ? 0 : 7 - remainder);

  return List<DateTime?>.generate(totalCount, (index) {
    final day = index - leadingEmptyCount + 1;
    if (day < 1 || day > dayCount) return null;
    return DateTime(visibleMonth.year, visibleMonth.month, day);
  });
}

int _decadeStart(int year) => year - year % 10;

int _centuryStart(int year) => year - year % 100;
