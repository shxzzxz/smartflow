import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../view_model/statistics_view_model.dart';
import '../widget/statistics_analysis_sections.dart';
import '../widget/statistics_breakdown_section.dart';
import '../widget/statistics_comparison_sheet.dart';
import '../widget/statistics_period_context_bar.dart';
import '../widget/statistics_period_sheet.dart';

class StatisticsPeriodView extends ConsumerStatefulWidget {
  const StatisticsPeriodView({super.key});

  @override
  ConsumerState<StatisticsPeriodView> createState() =>
      _StatisticsPeriodViewState();
}

class _StatisticsPeriodViewState extends ConsumerState<StatisticsPeriodView> {
  StatisticsContentLoaded? _lastLoaded;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(statisticsPageProvider);
    final control = page.control;
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    final automatic = control.comparisonRangeFor(
      StatisticsComparisonMode.previousPeriod,
      page.lastSelectableDate,
    );
    final previousYear = control.comparisonRangeFor(
      StatisticsComparisonMode.previousYear,
      page.lastSelectableDate,
    );
    final comparison = control.comparisonRange(page.lastSelectableDate);
    final content = page.content;
    if (content is StatisticsContentLoaded) {
      _lastLoaded = content;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space8,
            AppSpacing.space16,
            AppSpacing.space8,
          ),
          child: StatisticsPeriodContextBar(
            currentRange: page.periodLabel,
            comparison: comparison,
            onPickPeriod: () => _pickPeriod(context, notifier),
            onOpenComparison: () => _openComparison(
              context,
              notifier,
              selected: control.comparisonMode,
              automatic: automatic,
              previousYear: previousYear,
            ),
          ),
        ),
        Expanded(
          child: switch (content) {
            StatisticsContentLoaded() => _PeriodContentView(
              content: content,
              control: control,
            ),
            StatisticsContentError(:final message) => _PageMessage(
              icon: RemixIcons.error_warning_line,
              message: message,
            ),
            StatisticsContentLoading() => switch (_lastLoaded) {
              null => const Center(child: CircularProgressIndicator()),
              final lastLoaded => IgnorePointer(
                child: Opacity(
                  opacity: AppComponentTokens.staleContentOpacity,
                  child: _PeriodContentView(
                    content: lastLoaded,
                    control: control,
                  ),
                ),
              ),
            },
          },
        ),
      ],
    );
  }

  Future<void> _pickPeriod(
    BuildContext context,
    StatisticsViewModel notifier,
  ) async {
    final page = ref.read(statisticsPageProvider);
    final control = page.control;
    final selection = await showStatisticsPeriodSheet(
      context: context,
      granularity: control.granularity,
      mode: control.mode,
      from: control.periodFrom,
      untilExclusive: control.periodUntil,
      lastSelectableDate: page.lastSelectableDate,
    );
    if (selection == null) return;
    notifier.applyPeriodSelection(
      granularity: selection.granularity,
      mode: selection.mode,
      from: selection.from,
      untilExclusive: selection.untilExclusive,
    );
  }

  Future<void> _openComparison(
    BuildContext context,
    StatisticsViewModel notifier, {
    required StatisticsComparisonMode selected,
    required StatisticsComparisonRange? automatic,
    required StatisticsComparisonRange? previousYear,
  }) async {
    final result = await showStatisticsComparisonSheet(
      context: context,
      selected: selected,
      automatic: automatic,
      previousYear: previousYear,
    );
    if (result == null) return;
    notifier.selectComparisonMode(result);
  }
}

class _PeriodContentView extends StatelessWidget {
  const _PeriodContentView({required this.content, required this.control});

  final StatisticsContentLoaded content;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        StatisticsOverviewSection(
          overview: content.overview,
          comparison: content.comparison,
        ),
        if (content.comparison case final comparison?) ...[
          const SizedBox(height: AppSpacing.space16),
          StatisticsComparisonSection(
            comparison: comparison,
            cashflow: content.cashflow,
            control: control,
          ),
        ],
        const SizedBox(height: AppSpacing.space16),
        StatisticsCashflowSection(cashflow: content.cashflow, control: control),
        const SizedBox(height: AppSpacing.space16),
        StatisticsBalanceSection(balance: content.balance, control: control),
        const SizedBox(height: AppSpacing.space16),
        StatisticsBreakdownSection(
          categories: content.categories,
          tags: content.tags,
          control: control,
        ),
        const SizedBox(height: AppSpacing.space16),
        StatisticsWeekdaySection(cashflow: content.cashflow),
      ],
    );
  }
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.appTextStyles.listSupporting,
            ),
          ],
        ),
      ),
    );
  }
}
