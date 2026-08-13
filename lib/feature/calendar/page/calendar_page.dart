import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import 'package:smartflow/widget/business/finance/finance_tone_color.dart';
import 'package:smartflow/widget/business/transaction/transaction_feed.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../presentation/calendar_heat_metric_options.dart';
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
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();
    final content = ref.watch(
      calendarContentProvider(
        visibleMonth: state.visibleMonth,
        selectedDate: state.selectedDate,
        heatMetric:
            settings.calendarHeatmapEnabled
                ? settings.calendarHeatMetric
                : null,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CalendarHeader(
              visibleMonth: state.visibleMonth,
              showLunar: state.showLunar,
              showHeatmap: settings.calendarHeatmapEnabled,
              heatMetric: settings.calendarHeatMetric,
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
                CalendarContentLoaded(:final month, :final day) =>
                  _CalendarContent(
                    month: month,
                    day: day,
                    showLunar: state.showLunar,
                    onDateSelected: _selectDate,
                    onMonthSwipe: _shiftMonth,
                    onLoadMore:
                        () =>
                            ref
                                .read(
                                  calendarTransactionFeedViewModelProvider(
                                    state.selectedDate,
                                  ).notifier,
                                )
                                .loadMore(),
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

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({
    required this.visibleMonth,
    required this.showLunar,
    required this.showHeatmap,
    required this.heatMetric,
    required this.onMonthPressed,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onTodayPressed,
    required this.onToggleLunar,
  });

  final DateTime visibleMonth;
  final bool showLunar;
  final bool showHeatmap;
  final CalendarHeatMetric heatMetric;
  final VoidCallback onMonthPressed;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTodayPressed;
  final VoidCallback onToggleLunar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsViewModelProvider.notifier);
    return AppPageHeader.custom(
      titleContent: AppMonthSelector(
        visibleMonth: visibleMonth,
        onPreviousMonth: onPreviousMonth,
        onMonthPressed: onMonthPressed,
        onNextMonth: onNextMonth,
      ),
      actions: [
        AppHeaderIconButton(
          onPressed: onTodayPressed,
          tooltip: '回到今天',
          icon: RemixIcons.calendar_check_line,
        ),
        AppHeaderIconButton(
          onPressed: onToggleLunar,
          tooltip: showLunar ? '隐藏农历' : '显示农历',
          icon: showLunar ? RemixIcons.eye_line : RemixIcons.eye_off_line,
        ),
        AppPopupMenuButton(
          tooltip: '更多',
          icon: RemixIcons.more_2_line,
          items: [
            AppPopupMenuAction(
              label: '回到今天',
              icon: RemixIcons.calendar_check_line,
              onPressed: onTodayPressed,
            ),
            AppPopupMenuToggle(
              label: '热力图',
              icon: RemixIcons.fire_line,
              value: showHeatmap,
              onChanged: settings.setCalendarHeatmapEnabled,
            ),
            if (showHeatmap)
              AppPopupMenuSelect<CalendarHeatMetric>(
                label: '热力维度',
                value: heatMetric,
                options: calendarHeatMetricOptions,
                onChanged: settings.setCalendarHeatMetric,
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarContent extends StatelessWidget {
  const _CalendarContent({
    required this.month,
    required this.day,
    required this.showLunar,
    required this.onDateSelected,
    required this.onMonthSwipe,
    required this.onLoadMore,
  });

  final CalendarMonthPresentation month;
  final CalendarDaySectionPresentation day;
  final bool showLunar;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onMonthSwipe;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return TransactionFeedScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
      bottomPadding: AppSpacing.space24,
      leading: [
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
      ],
      // 当日首页加载期间不渲染分组，避免闪现“暂无交易”后再跳成列表。
      groups: day.isLoading ? const [] : [day.group],
      groupEmptyMessage: '当天暂无交易记录',
      hasMore: day.hasMore,
      isLoadingMore: day.isLoading || day.isLoadingMore,
      loadMoreErrorMessage: day.loadMoreErrorMessage,
      onLoadMore: onLoadMore,
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
        for (final metric in metrics)
          Expanded(
            child: _SummaryText(
              metric: metric,
              amountColor: financeToneColor(colors, financeColors, metric.tone),
            ),
          ),
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

    return FittedBox(
      alignment: Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: Text.rich(
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
      ),
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
    final heat = day.heat;
    final heatColor =
        heat == null
            ? null
            : financeToneColor(
              colors,
              financeColors,
              heat.tone,
            ).withValues(alpha: AppHeatScale.alphaForIntensity(heat.intensity));
    final selectedColor = colors.primaryContainer.withValues(alpha: 0.42);
    // 热力底色占着格子背景时，选中态让出填充改用描边，热力强度才不会被选中盖掉。
    final border =
        day.isSelected && heatColor != null
            ? Border.all(color: colors.primary, width: 2)
            : Border.all(
              color:
                  day.isToday && !day.isSelected
                      ? colors.primary.withValues(alpha: 0.35)
                      : Colors.transparent,
            );

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
              color:
                  heatColor ??
                  (day.isSelected ? selectedColor : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: border,
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
