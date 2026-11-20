import 'package:flutter/material.dart';

import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../view_model/statistics_view_model.dart';

/// 统计页头中间的受控 Tab，跟随顶部外观并表达页面级视图切换。
class StatisticsViewSwitcher extends StatelessWidget {
  const StatisticsViewSwitcher({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final StatisticsViewType selected;
  final ValueChanged<StatisticsViewType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: AppSlidingSegmentedControl<StatisticsViewType>(
        key: const ValueKey('statistics-view-switcher'),
        variant: AppSegmentedControlVariant.header,
        selected: selected,
        onChanged: onChanged,
        segments: [
          for (final view in StatisticsViewType.values)
            AppSegment(value: view, label: view.label),
        ],
      ),
    );
  }
}
