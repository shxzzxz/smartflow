import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import 'package:smartflow/widget/business/finance/finance_tone_color.dart';
import 'package:smartflow/widget/business/transaction/transaction_day_card.dart';
import '../presentation/calendar_month_presentation.dart';
import '../view_model/calendar_view_model.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarViewModelProvider);
    final content = ref.watch(
      calendarContentProvider(
        visibleMonth: state.visibleMonth,
        selectedDate: state.selectedDate,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CalendarHeader(
              visibleMonth: state.visibleMonth,
              showLunar: state.showLunar,
              onMonthPressed: _pickMonth,
              onPreviousMonth: () => _shiftMonth(-1),
              onNextMonth: () => _shiftMonth(1),
              onTodayPressed: _goToday,
              onToggleLunar:
                  () =>
                      ref
                          .read(calendarViewModelProvider.notifier)
                          .toggleLunar(),
            ),
            Expanded(
              child: switch (content) {
                CalendarContentLoaded(:final month) => _CalendarContent(
                  month: month,
                  showLunar: state.showLunar,
                  onDateSelected: _selectDate,
                  onMonthSwipe: _shiftMonth,
                ),
                CalendarContentError(:final message) => Center(
                  child: Text(message),
                ),
                CalendarContentLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transaction/new'),
        tooltip: '新建记账',
        shape: const CircleBorder(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(RemixIcons.add_line),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final selected = await showAppMonthPicker(
      context: context,
      initialMonth: ref.read(calendarViewModelProvider).visibleMonth,
    );
    if (!mounted || selected == null) {
      return;
    }
    ref.read(calendarViewModelProvider.notifier).pickMonth(selected);
  }

  void _goToday() {
    ref.read(calendarViewModelProvider.notifier).goToday();
  }

  void _selectDate(DateTime date) {
    ref.read(calendarViewModelProvider.notifier).selectDate(date);
  }

  void _shiftMonth(int delta) {
    ref.read(calendarViewModelProvider.notifier).shiftMonth(delta);
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.visibleMonth,
    required this.showLunar,
    required this.onMonthPressed,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onTodayPressed,
    required this.onToggleLunar,
  });

  final DateTime visibleMonth;
  final bool showLunar;
  final VoidCallback onMonthPressed;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTodayPressed;
  final VoidCallback onToggleLunar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space10,
        AppSpacing.space8,
        AppSpacing.space12,
      ),
      child: Row(
        children: [
          AppMonthSelector(
            visibleMonth: visibleMonth,
            onPreviousMonth: onPreviousMonth,
            onMonthPressed: onMonthPressed,
            onNextMonth: onNextMonth,
          ),
          const Spacer(),
          _HeaderIconButton(
            onPressed: onTodayPressed,
            tooltip: '回到今天',
            icon: const Icon(RemixIcons.calendar_check_line),
          ),
          _HeaderIconButton(
            onPressed: onToggleLunar,
            tooltip: showLunar ? '隐藏农历' : '显示农历',
            icon: Icon(
              showLunar ? RemixIcons.eye_line : RemixIcons.eye_off_line,
            ),
          ),
          AppPopupMenuButton<_CalendarMenuAction>(
            tooltip: '更多',
            icon: RemixIcons.more_2_line,
            onSelected: (action) {
              switch (action) {
                case _CalendarMenuAction.today:
                  onTodayPressed();
              }
            },
            options: const [
              AppPopupMenuOption(
                value: _CalendarMenuAction.today,
                label: '回到今天',
                icon: RemixIcons.calendar_check_line,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
      iconSize: AppSpacing.space20,
      padding: const EdgeInsets.all(AppSpacing.space6),
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.space32,
        height: AppSpacing.space32,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

enum _CalendarMenuAction { today }

class _CalendarContent extends StatelessWidget {
  const _CalendarContent({
    required this.month,
    required this.showLunar,
    required this.onDateSelected,
    required this.onMonthSwipe,
  });

  final CalendarMonthPresentation month;
  final bool showLunar;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onMonthSwipe;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        _MonthlySummaryStrip(summary: month.summary),
        const SizedBox(height: AppSpacing.space10),
        const _WeekdayHeader(),
        const SizedBox(height: AppSpacing.space8),
        _CalendarGrid(
          days: month.days,
          showLunar: showLunar,
          onDateSelected: onDateSelected,
          onMonthSwipe: onMonthSwipe,
        ),
        const SizedBox(height: AppSpacing.space10),
        TransactionDayCard(
          group: month.selectedGroup,
          emptyMessage: '当天暂无交易记录',
        ),
      ],
    );
  }
}

class _MonthlySummaryStrip extends StatelessWidget {
  const _MonthlySummaryStrip({required this.summary});

  final CalendarMonthlySummaryPresentation summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final metrics = summary.metrics;

    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.space24),
          if (i == metrics.length - 1)
            Expanded(
              child: _SummaryText(
                metric: metrics[i],
                amountColor: financeToneColor(
                  colors,
                  financeColors,
                  metrics[i].tone,
                ),
              ),
            )
          else
            _SummaryText(
              metric: metrics[i],
              amountColor: financeToneColor(
                colors,
                financeColors,
                metrics[i].tone,
              ),
            ),
        ],
      ],
    );
  }
}

class _SummaryText extends StatelessWidget {
  const _SummaryText({required this.metric, required this.amountColor});

  final CalendarMonthlySummaryMetricPresentation metric;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;

    return Text.rich(
      TextSpan(
        text: '${metric.label} ',
        style: textStyles.listSupporting,
        children: [
          TextSpan(
            text: metric.amountText,
            style: textStyles.calendarSummaryAmount.copyWith(
              color: amountColor,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labels = ['日', '一', '二', '三', '四', '五', '六'];

    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: context.appTextStyles.formLabel.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.days,
    required this.showLunar,
    required this.onDateSelected,
    required this.onMonthSwipe,
  });

  final List<CalendarDayPresentation> days;
  final bool showLunar;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onMonthSwipe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: DateTime.daysPerWeek,
          mainAxisExtent: 56,
        ),
        itemBuilder:
            (context, index) => _CalendarDayCell(
              day: days[index],
              showLunar: showLunar,
              onTap: () => onDateSelected(days[index].date),
            ),
      ),
    );
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 260) {
      return;
    }
    onMonthSwipe(velocity < 0 ? 1 : -1);
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.showLunar,
    required this.onTap,
  });

  final CalendarDayPresentation day;
  final bool showLunar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final foregroundOpacity = day.isInVisibleMonth ? 1.0 : 0.38;
    final selectedColor = colors.primaryContainer.withValues(alpha: 0.42);
    final borderColor =
        day.isToday && !day.isSelected
            ? colors.primary.withValues(alpha: 0.35)
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: day.isSelected ? selectedColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space2,
              vertical: AppSpacing.space2,
            ),
            child: Opacity(
              opacity: foregroundOpacity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        Text(
                          '${day.date.day}',
                          style: textStyles.calendarDayNumber.copyWith(
                            color:
                                day.isSelected
                                    ? colors.primary
                                    : colors.onSurface,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: AppSpacing.space2),
                        SizedBox(
                          height: 20,
                          child:
                              day.hasCashflow
                                  ? _CashflowLines(
                                    day: day,
                                    incomeColor: financeColors.income,
                                    expenseColor: financeColors.expense,
                                  )
                                  : _LunarLabel(
                                    label: showLunar ? day.lunarLabel : '',
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (day.markerLabel != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _DayMarkerBadge(label: day.markerLabel!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayMarkerBadge extends StatelessWidget {
  const _DayMarkerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 14),
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: context.appTextStyles.calendarBadgeLabel.copyWith(
          color: colors.onPrimary,
        ),
        maxLines: 1,
      ),
    );
  }
}

class _CashflowLines extends StatelessWidget {
  const _CashflowLines({
    required this.day,
    required this.incomeColor,
    required this.expenseColor,
  });

  final CalendarDayPresentation day;
  final Color incomeColor;
  final Color expenseColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AmountLine(text: day.incomeText, color: incomeColor),
        _AmountLine(text: day.expenseText, color: expenseColor),
      ],
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: context.appTextStyles.calendarCellAmount.copyWith(
            color: color,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

class _LunarLabel extends StatelessWidget {
  const _LunarLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        label,
        style: context.appTextStyles.listSupporting.copyWith(
          color: colors.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
