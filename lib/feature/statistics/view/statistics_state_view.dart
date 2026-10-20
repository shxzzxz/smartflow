import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_bottom_navigation_layout_scope.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../widget/business/analytics/analysis_section_card.dart';
import '../../../widget/business/analytics/analysis_chart_card.dart';
import '../../../widget/business/analytics/analytics_amount_column.dart';
import '../../../widget/business/analytics/category_progress_list_item.dart';
import '../../../widget/business/analytics/chart/app_chart_expand_button.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/statistics_presentation.dart';
import '../presentation/statistics_state_presentation.dart';
import '../view_model/statistics_state_view_model.dart';
import '../view_model/statistics_view_model.dart';
import '../widget/statistics_charts.dart';
import '../widget/statistics_composition_list.dart';

class StatisticsStateView extends ConsumerWidget {
  const StatisticsStateView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentInset = AppBottomNavigationLayoutScope.of(
      context,
    ).contentInset;
    final asOf = ref.watch(
      statisticsPageProvider.select((page) => page.asOfDate),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        AppSpacing.space24 + contentInset,
      ),
      children: [
        _StateStructure(asOf: asOf),
        const SizedBox(height: AppSpacing.space16),
        _StateInstallmentsSection(asOf: asOf),
      ],
    );
  }
}

class _StateStructure extends ConsumerWidget {
  const _StateStructure({required this.asOf});

  final DateTime asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(statisticsStateContentProvider(asOf));
    return switch (content) {
      StatisticsStateContentLoaded(:final presentation) => Column(
        children: [
          _StateBreakdownCard(
            key: const ValueKey('statistics-state-assets'),
            title: '资产构成',
            subtitle: '按账户余额',
            items: presentation.assetAccounts,
            total: presentation.totalAssets,
            semantic: MoneySemantic.asset,
            centerLabel: '总资产',
            emptyMessage: '暂无资产账户',
          ),
          const SizedBox(height: AppSpacing.space16),
          _StateBreakdownCard(
            key: const ValueKey('statistics-state-liabilities'),
            title: '负债构成',
            subtitle: '按账户余额',
            items: presentation.liabilityAccounts,
            total: presentation.totalLiabilities,
            semantic: MoneySemantic.liability,
            centerLabel: '总负债',
            emptyMessage: '暂无负债账户',
          ),
        ],
      ),
      StatisticsStateContentError(:final message) => _StateMessage(
        message: message,
      ),
      StatisticsStateContentLoading() => const SizedBox(
        height: AppSpacing.space48 + AppSpacing.space48,
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _StateBreakdownCard extends StatelessWidget {
  const _StateBreakdownCard({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.total,
    required this.semantic,
    required this.centerLabel,
    required this.emptyMessage,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<StatisticsBreakdownItem> items;
  final Money total;
  final MoneySemantic semantic;
  final String centerLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AnalysisSectionCard(
      title: title,
      subtitle: subtitle,
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space12,
        AppSpacing.space16,
        AppSpacing.space8,
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space8),
              child: Text(
                emptyMessage,
                style: context.appTextStyles.listSupporting,
              ),
            )
          : Column(
              children: [
                StatisticsDonutChart(
                  items: items,
                  centerLabel: centerLabel,
                  centerValue: total.format(),
                ),
                StatisticsCompositionList<StatisticsBreakdownItem>(
                  key: ValueKey(
                    'statistics-state-composition-list-${semantic.name}',
                  ),
                  items: items,
                  itemUnit: '项',
                  itemBuilder: (context, item, index) =>
                      CategoryProgressListItem(
                        title: item.title,
                        progress: item.progress,
                        color: statisticsCategoryRowColor(
                          context,
                          index: index,
                          itemCount: items.length,
                        ),
                        trailing: AnalyticsAmountColumn(
                          key: ValueKey(
                            'statistics-state-amount-${semantic.name}-'
                            '${item.id}',
                          ),
                          money: item.amount,
                          semantic: semantic,
                          maxWidth: AppChartGeometry.categoryAmountColumnWidth,
                        ),
                        trailingGap: AppSpacing.space4,
                        trailingWidth:
                            AppChartGeometry.categoryAmountColumnWidth,
                        onTap: () => context.push('/account/${item.id}'),
                      ),
                ),
              ],
            ),
    );
  }
}

class _StateInstallmentsSection extends ConsumerStatefulWidget {
  const _StateInstallmentsSection({required this.asOf});

  final DateTime asOf;

  @override
  ConsumerState<_StateInstallmentsSection> createState() =>
      _StateInstallmentsSectionState();
}

class _StateInstallmentsSectionState
    extends ConsumerState<_StateInstallmentsSection> {
  StatisticsInstallmentsPresentation? _lastLoaded;
  StatisticsInstallmentCompositionMetric _compositionMetric =
      StatisticsInstallmentCompositionMetric.principal;
  StatisticsInstallmentCashflowHorizon _cashflowHorizon =
      StatisticsInstallmentCashflowHorizon.sixMonths;

  @override
  void didUpdateWidget(covariant _StateInstallmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asOf != widget.asOf) {
      _lastLoaded = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(statisticsInstallmentsProvider(widget.asOf));
    final loaded = value.value;
    if (loaded != null) {
      _lastLoaded = loaded;
    }
    final presentation = _lastLoaded;
    final updating = value.isLoading && presentation != null;
    return Column(
      children: [
        AnalysisSectionCard(
          key: const ValueKey('statistics-installment-composition-card'),
          title: '分期构成',
          subtitle: '仅进行中 · 待还构成',
          trailing:
              AppSlidingSegmentedControl<
                StatisticsInstallmentCompositionMetric
              >(
                key: const ValueKey(
                  'statistics-installment-composition-metric',
                ),
                segments: const [
                  AppSegment(
                    value: StatisticsInstallmentCompositionMetric.principal,
                    label: '待还本金',
                  ),
                  AppSegment(
                    value: StatisticsInstallmentCompositionMetric.total,
                    label: '总待还',
                  ),
                ],
                selected: _compositionMetric,
                onChanged: (metric) =>
                    setState(() => _compositionMetric = metric),
              ),
          child: _InstallmentCardBody(
            loading: value.isLoading,
            updating: updating,
            error: value is AsyncError,
            errorMessage: '分期构成加载失败，请稍后重试。',
            presentation: presentation,
            builder: (presentation) => _InstallmentCompositionContent(
              presentation: presentation,
              metric: _compositionMetric,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        AnalysisSectionCard(
          key: const ValueKey('statistics-installment-cashflow-card'),
          title: '分期还款走势',
          subtitle: '仅进行中 · 按当前计划估算',
          trailing:
              AppSlidingSegmentedControl<StatisticsInstallmentCashflowHorizon>(
                key: const ValueKey('statistics-installment-cashflow-horizon'),
                segments: const [
                  AppSegment(
                    value: StatisticsInstallmentCashflowHorizon.sixMonths,
                    label: '半年',
                  ),
                  AppSegment(
                    value: StatisticsInstallmentCashflowHorizon.oneYear,
                    label: '一年',
                  ),
                  AppSegment(
                    value: StatisticsInstallmentCashflowHorizon.all,
                    label: '全部',
                  ),
                ],
                selected: _cashflowHorizon,
                onChanged: (horizon) =>
                    setState(() => _cashflowHorizon = horizon),
              ),
          child: _InstallmentCardBody(
            loading: value.isLoading,
            updating: updating,
            error: value is AsyncError,
            errorMessage: '分期还款走势加载失败，请稍后重试。',
            presentation: presentation,
            builder: (presentation) => _InstallmentCashflowContent(
              presentation: presentation,
              horizon: _cashflowHorizon,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentCardBody extends StatelessWidget {
  const _InstallmentCardBody({
    required this.loading,
    required this.updating,
    required this.error,
    required this.errorMessage,
    required this.presentation,
    required this.builder,
  });

  final bool loading;
  final bool updating;
  final bool error;
  final String errorMessage;
  final StatisticsInstallmentsPresentation? presentation;
  final Widget Function(StatisticsInstallmentsPresentation presentation)
  builder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: AppSpacing.space2,
          child: loading
              ? const LinearProgressIndicator(minHeight: AppSpacing.space2)
              : null,
        ),
        const SizedBox(height: AppSpacing.space12),
        if (presentation != null)
          IgnorePointer(
            ignoring: updating,
            child: Opacity(
              opacity: updating ? AppComponentTokens.staleContentOpacity : 1,
              child: builder(presentation!),
            ),
          )
        else if (error)
          Text(errorMessage, style: context.appTextStyles.listSupporting)
        else
          const SizedBox(
            height: AppSpacing.space48,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _InstallmentCompositionContent extends StatelessWidget {
  const _InstallmentCompositionContent({
    required this.presentation,
    required this.metric,
  });

  final StatisticsInstallmentsPresentation presentation;
  final StatisticsInstallmentCompositionMetric metric;

  @override
  Widget build(BuildContext context) {
    final items = sortStatisticsInstallmentCompositionItems(
      presentation.compositionItems,
      metric,
    );
    if (items.isEmpty) {
      return Text('暂无进行中的分期合同', style: context.appTextStyles.listSupporting);
    }
    final selectedTotal =
        metric == StatisticsInstallmentCompositionMetric.principal
        ? presentation.remainingPrincipal
        : presentation.remainingTotal;
    final selectedValues = [
      for (final item in items)
        if (metric == StatisticsInstallmentCompositionMetric.principal)
          item.remainingPrincipal.minorUnits
        else
          item.remainingTotal.minorUnits,
    ];
    final maxSelectedValue = selectedValues.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatisticsDonutChart(
          items: [
            for (final item in items)
              StatisticsBreakdownItem(
                id: item.contractId,
                title: '${item.accountName} · ${item.contractName}',
                accountType: AccountType.liability,
                amount:
                    metric == StatisticsInstallmentCompositionMetric.principal
                    ? item.remainingPrincipal
                    : item.remainingTotal,
                progress: 0,
              ),
          ],
          centerLabel:
              metric == StatisticsInstallmentCompositionMetric.principal
              ? '待还本金'
              : '总待还',
          centerValue: selectedTotal.format(),
        ),
        const SizedBox(height: AppSpacing.space16),
        StatisticsCompositionList<StatisticsInstallmentCompositionItem>(
          key: const ValueKey('statistics-installment-composition-list'),
          items: items,
          itemUnit: '笔',
          resetToken: metric,
          itemBuilder: (context, item, index) => CategoryProgressListItem(
            title: '${item.accountName} · ${item.contractName}',
            progress: maxSelectedValue == 0
                ? 0
                : (metric == StatisticsInstallmentCompositionMetric.principal
                          ? item.remainingPrincipal.minorUnits
                          : item.remainingTotal.minorUnits) /
                      maxSelectedValue,
            color: statisticsCategoryRowColor(
              context,
              index: index,
              itemCount: items.length,
            ),
            trailing: AnalyticsAmountColumn(
              key: ValueKey('statistics-installment-value-${item.contractId}'),
              money: metric == StatisticsInstallmentCompositionMetric.principal
                  ? item.remainingPrincipal
                  : item.remainingTotal,
              semantic: MoneySemantic.liability,
              maxWidth: AppChartGeometry.categoryAmountColumnWidth,
            ),
            trailingGap: AppSpacing.space4,
            trailingWidth: AppChartGeometry.categoryAmountColumnWidth,
            footer: _InstallmentCompositionValues(item: item),
            onTap: () => context.push('/installments/${item.contractId}'),
          ),
        ),
      ],
    );
  }
}

class _InstallmentCompositionValues extends StatelessWidget {
  const _InstallmentCompositionValues({required this.item});

  final StatisticsInstallmentCompositionItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompositionValue(
            value: _compactAmountLabel(item.remainingPrincipal),
            semanticLabel: '待还本金 ${item.remainingPrincipal.format()}',
          ),
        ),
        Expanded(
          child: _CompositionValue(
            value: _compactAmountLabel(item.remainingInterest),
            semanticLabel: '待还利息 ${item.remainingInterest.format()}',
          ),
        ),
        Expanded(
          child: _CompositionValue(
            value: _rateLabel(item.xirr),
            semanticLabel: item.xirr == null
                ? 'XIRR 不可用'
                : 'XIRR ${_rateLabel(item.xirr)}',
          ),
        ),
      ],
    );
  }
}

class _CompositionValue extends StatelessWidget {
  const _CompositionValue({required this.value, required this.semanticLabel});

  final String value;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: context.appTextStyles.listSupporting,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}

class _InstallmentCashflowContent extends StatelessWidget {
  const _InstallmentCashflowContent({
    required this.presentation,
    required this.horizon,
  });

  final StatisticsInstallmentsPresentation presentation;
  final StatisticsInstallmentCashflowHorizon horizon;

  @override
  Widget build(BuildContext context) {
    final months = switch (horizon) {
      StatisticsInstallmentCashflowHorizon.sixMonths =>
        presentation.cashflowMonths.take(6).toList(),
      StatisticsInstallmentCashflowHorizon.oneYear =>
        presentation.cashflowMonths.take(12).toList(),
      StatisticsInstallmentCashflowHorizon.all => presentation.cashflowMonths,
    };
    final hasRepayment = months.any(
      (month) =>
          month.principal.minorUnits > 0 || month.interest.minorUnits > 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.space24,
          runSpacing: AppSpacing.space12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _InstallmentMetric(
              label: '待还本金',
              child: MoneyText(
                money: presentation.remainingPrincipal,
                semantic: MoneySemantic.liability,
                style: context.appTextStyles.metricValue,
              ),
            ),
            _InstallmentMetric(
              label: '待还利息',
              child: MoneyText(
                money: presentation.remainingInterest,
                semantic: MoneySemantic.liability,
                style: context.appTextStyles.metricValue,
              ),
            ),
            _InstallmentMetric(
              label: '逾期待还',
              child: MoneyText(
                money: presentation.overdueTotal,
                semantic: MoneySemantic.liability,
                style: context.appTextStyles.metricValue,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space16),
        if (presentation.compositionItems.isEmpty)
          Text('暂无进行中的分期合同', style: context.appTextStyles.listSupporting)
        else if (!hasRepayment)
          Text('所选期间暂无还款', style: context.appTextStyles.listSupporting)
        else
          Stack(
            children: [
              StatisticsInstallmentCashflowChart(months: months),
              Positioned(
                top: 0,
                right: 0,
                child: AppChartExpandButton(
                  key: const ValueKey('chart-expand-分期还款走势'),
                  tooltip: '横屏查看分期还款走势',
                  onTap: () => openAnalysisChartExpanded(
                    context,
                    chartBuilder: (height) =>
                        StatisticsInstallmentCashflowChart(
                          months: months,
                          height: height,
                        ),
                    reservedHeight:
                        AppChartGeometry.interactiveLegendReservedHeight,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _InstallmentMetric extends StatelessWidget {
  const _InstallmentMetric({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.appTextStyles.metricLabel),
        const SizedBox(height: AppSpacing.space4),
        child,
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.appTextStyles.listSupporting,
        ),
      ),
    );
  }
}

String _rateLabel(double? value) {
  if (value == null || !value.isFinite) return '—';
  return '${(value * 100).toStringAsFixed(2)}%';
}

String _compactAmountLabel(Money value) {
  final text = value.format();
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}
