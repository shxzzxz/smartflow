import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../view_model/statistics_view_model.dart';

/// 统计页的视图导航。只表达页面级视图切换，不占用页头标题位。
class StatisticsViewSwitcher extends StatefulWidget {
  const StatisticsViewSwitcher({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final StatisticsViewType selected;
  final ValueChanged<StatisticsViewType> onChanged;

  @override
  State<StatisticsViewSwitcher> createState() => _StatisticsViewSwitcherState();
}

class _StatisticsViewSwitcherState extends State<StatisticsViewSwitcher>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: StatisticsViewType.values.length,
      initialIndex: widget.selected.index,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant StatisticsViewSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabs.index != widget.selected.index) {
      _tabs.animateTo(widget.selected.index);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.space4,
        AppSpacing.space4,
        AppSpacing.space16,
        0,
      ),
      child: SizedBox(
        height: AppSpacing.space48,
        child: TabBar(
          key: const ValueKey('statistics-view-switcher'),
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
          ),
          labelStyle: textStyles.segmentedControlLabel(selected: true),
          unselectedLabelStyle: textStyles.segmentedControlLabel(
            selected: false,
          ),
          onTap: (index) {
            widget.onChanged(StatisticsViewType.values[index]);
          },
          tabs: [
            for (final view in StatisticsViewType.values) Tab(text: view.label),
          ],
        ),
      ),
    );
  }
}
