import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_model/statistics_view_model.dart';
import '../view/statistics_period_view.dart';
import '../view/statistics_state_view.dart';
import '../view/statistics_view_switcher.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewType = ref.watch(
      statisticsPageProvider.select((page) => page.control.viewType),
    );
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            StatisticsViewSwitcher(
              selected: viewType,
              onChanged: notifier.selectView,
            ),
            Expanded(
              child: switch (viewType) {
                StatisticsViewType.period => const StatisticsPeriodView(),
                StatisticsViewType.state => const StatisticsStateView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
