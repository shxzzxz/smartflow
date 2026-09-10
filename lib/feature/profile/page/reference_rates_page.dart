import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/credit/credit_command_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_dropdown.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../shared/presentation/reference_rate_presentation.dart';
import '../presentation/reference_rates_presentation.dart';
import '../view_model/reference_rates_view_model.dart';

class ReferenceRatesPage extends ConsumerStatefulWidget {
  const ReferenceRatesPage({super.key});

  @override
  ConsumerState<ReferenceRatesPage> createState() => _ReferenceRatesPageState();
}

class _ReferenceRatesPageState extends ConsumerState<ReferenceRatesPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: ReferenceRateGroup.values.length,
    vsync: this,
  );
  final _scrollControllers = {
    for (final group in ReferenceRateGroup.values) group: ScrollController(),
  };

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referenceRatesViewModelProvider);
    final vm = ref.read(referenceRatesViewModelProvider.notifier);
    ref.listen(referenceRatesViewModelProvider.select((value) => value.group), (
      _,
      group,
    ) {
      if (_tabs.index != group.index) _tabs.animateTo(group.index);
    });
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final current = state.current;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppPageHeader(title: '参考利率'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                  ),
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: colors.outlineVariant,
                    labelStyle: styles.formValueEmphasis,
                    unselectedLabelStyle: styles.formValue,
                    onTap: (index) =>
                        vm.selectGroup(ReferenceRateGroup.values[index]),
                    tabs: [
                      for (final group in ReferenceRateGroup.values)
                        Tab(text: group.label),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: vm.refresh,
                    child: ListView(
                      key: PageStorageKey(state.group),
                      controller: _scrollControllers[state.group],
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      children: [
                        _OverviewCard(group: state.group, state: current),
                        if (current.loading) ...[
                          const SizedBox(height: AppSpacing.space12),
                          const LinearProgressIndicator(
                            semanticsLabel: '正在更新参考利率',
                          ),
                        ],
                        if (state.warning case final message?) ...[
                          const SizedBox(height: AppSpacing.space12),
                          AppStatusBanner(
                            message: message,
                            tone: AppStatusBannerTone.warning,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: current.loading ? null : vm.refresh,
                              child: const Text('重试'),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.space24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final title = Text(
                              '历史数据',
                              style: styles.groupTitle,
                            );
                            final filter = AppDropdown<int?>(
                              options: [
                                const AppSelectOption(
                                  value: null,
                                  label: '全部年份',
                                ),
                                for (final year in state.years)
                                  AppSelectOption(
                                    value: year,
                                    label: '$year 年',
                                  ),
                              ],
                              value: current.year,
                              onChanged: vm.selectYear,
                              tooltip: '筛选历史年份',
                            );
                            if (constraints.maxWidth <
                                280 *
                                    MediaQuery.textScalerOf(context).scale(1)) {
                              return Wrap(
                                spacing: AppSpacing.space16,
                                runSpacing: AppSpacing.space12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [title, filter],
                              );
                            }
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [title, filter],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.space12),
                        AppSurface(
                          border: true,
                          child:
                              current.loading &&
                                  (current.history?.rates.isEmpty ?? true)
                              ? const _HistorySkeleton()
                              : state.rows.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.space32,
                                  ),
                                  child: Text(
                                    state.warning != null
                                        ? '暂时无法展示历史数据'
                                        : current.year == null
                                        ? '暂无参考利率记录'
                                        : '该年份暂无记录',
                                    style: styles.formSupporting,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : _HistoryTable(
                                  group: state.group,
                                  rows: state.rows,
                                ),
                        ),
                        const SizedBox(height: AppSpacing.space12),
                        Text(
                          state.group == ReferenceRateGroup.lpr
                              ? '按公布日期展示，利率单位为年利率。'
                              : '数据日期为来源记录日期，不等同于政策生效日期。',
                          style: styles.formSupporting,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.group, required this.state});
  final ReferenceRateGroup group;
  final ReferenceRatesGroupState state;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('今日参考利率', style: styles.groupTitle),
            const SizedBox(height: AppSpacing.space24),
            LayoutBuilder(
              builder: (context, constraints) {
                final metrics = [
                  for (final type in group.types)
                    _CurrentRate(type: type, group: group, state: state),
                ];
                if (constraints.maxWidth <
                    280 * MediaQuery.textScalerOf(context).scale(1)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      metrics.first,
                      const SizedBox(height: AppSpacing.space24),
                      metrics.last,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: metrics.first),
                    const SizedBox(width: AppSpacing.space16),
                    Expanded(child: metrics.last),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentRate extends StatelessWidget {
  const _CurrentRate({
    required this.type,
    required this.group,
    required this.state,
  });
  final ReferenceRateType type;
  final ReferenceRateGroup group;
  final ReferenceRatesGroupState state;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final rate = currentReferenceRate(type, state.history);
    final failure = state.history?.failures[type];
    return Column(
      key: ValueKey('current-${type.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(referenceRateTermLabel(type), style: styles.formSupporting),
        const SizedBox(height: AppSpacing.space8),
        if (rate == null && state.loading)
          const _SkeletonLine(height: AppSpacing.space40)
        else
          Text(
            rate == null ? '—' : referenceRatePercent(rate.ratePpm),
            style: styles.amountHero.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          rate == null
              ? (state.loading ? '正在获取' : '暂无记录')
              : '${group.dateLabel} ${formatDateLabel(rate.date)}',
          style: styles.listSupporting,
        ),
        if (failure != null && !state.loading) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            referenceRateFailureLabel(failure),
            style: styles.listSupporting,
          ),
        ],
      ],
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.group, required this.rows});
  final ReferenceRateGroup group;
  final List<ReferenceRateTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final minWidth = 288 * scale;
        final width = constraints.maxWidth > minWidth
            ? constraints.maxWidth
            : minWidth;
        final columnWidth = (width - AppSpacing.space48) / 3;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: AppSpacing.space12,
            columnSpacing: AppSpacing.space12,
            headingRowHeight:
                (group == ReferenceRateGroup.lpr
                    ? AppSpacing.space48
                    : AppSpacing.space48 + AppSpacing.space16) *
                scale,
            dataRowMinHeight: AppComponentTokens.controlMinHeight,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
            headingTextStyle: styles.listSupporting,
            dataTextStyle: styles.formValueEmphasis.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            columns: [
              DataColumn(
                label: SizedBox(
                  width: columnWidth,
                  child: Text(group.dateLabel),
                ),
              ),
              for (final type in group.types)
                DataColumn(
                  numeric: true,
                  label: SizedBox(
                    width: columnWidth,
                    child: Text(
                      referenceRateTermLabel(type),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        formatDateLabel(row.date),
                        style: styles.listSupporting.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    for (final type in group.types)
                      DataCell(
                        row.rates[type] == null
                            ? const Text('—')
                            : Tooltip(
                                message: referenceRateSourceLabel(
                                  row.rates[type]!.source,
                                ),
                                child: Text(
                                  referenceRatePercent(
                                    row.rates[type]!.ratePpm,
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.height = AppSpacing.space16});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
  );
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载历史数据',
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Column(
        children: [
          for (var index = 0; index < 4; index++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.space12),
              child: _SkeletonLine(),
            ),
        ],
      ),
    ),
  );
}
