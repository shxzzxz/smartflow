import 'package:flutter/material.dart';

import 'app_sliding_segmented_control.dart';

/// 页头中间的 Tab，跟随顶部外观并与 TabBarView 的控制器同步。
class AppHeaderTabs extends StatelessWidget {
  const AppHeaderTabs({required this.labels, super.key, this.controller});

  final List<String> labels;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    final tabController = controller ?? DefaultTabController.of(context);
    assert(tabController.length == labels.length);
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: AppSlidingSegmentedControl<int>(
          variant: AppSegmentedControlVariant.header,
          segments: [
            for (var i = 0; i < labels.length; i++)
              AppSegment(value: i, label: labels[i]),
          ],
          selected: tabController.index,
          onChanged: tabController.animateTo,
        ),
      ),
    );
  }
}
