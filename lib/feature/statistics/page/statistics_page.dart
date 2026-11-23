import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_model/statistics_view_model.dart';
import '../view/statistics_period_view.dart';
import '../view/statistics_state_view.dart';
import '../view/statistics_view_switcher.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_tab_swipe_region.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewType = ref.watch(
      statisticsPageProvider.select((page) => page.control.viewType),
    );
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader.custom(
              showBackButton: false,
              titleContent: StatisticsViewSwitcher(
                selected: viewType,
                onChanged: notifier.selectView,
              ),
            ),
            Expanded(
              child: AppTabSwipeRegion<StatisticsViewType>(
                values: StatisticsViewType.values,
                selected: viewType,
                onChanged: notifier.selectView,
                child: switch (viewType) {
                  StatisticsViewType.period => const StatisticsPeriodView(),
                  StatisticsViewType.state => const StatisticsStateView(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
