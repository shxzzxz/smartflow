import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';

/// 构成列表默认展示的条目数；超过该阈值时折叠其余条目。
const int statisticsCompositionCollapsedItemCount = 5;

class StatisticsCompositionList<T> extends StatefulWidget {
  const StatisticsCompositionList({
    required this.items,
    required this.itemBuilder,
    super.key,
    this.itemUnit = '项',
    this.resetToken,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final String itemUnit;

  /// 口径或筛选变化时传入新值，使列表恢复折叠状态。
  final Object? resetToken;

  @override
  State<StatisticsCompositionList<T>> createState() =>
      _StatisticsCompositionListState<T>();
}

class _StatisticsCompositionListState<T>
    extends State<StatisticsCompositionList<T>> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant StatisticsCompositionList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken ||
        widget.items.length <= statisticsCompositionCollapsedItemCount) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOverflow =
        widget.items.length > statisticsCompositionCollapsedItemCount;
    final visibleCount = _expanded
        ? widget.items.length
        : widget.items.length < statisticsCompositionCollapsedItemCount
        ? widget.items.length
        : statisticsCompositionCollapsedItemCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visibleCount; index++)
          widget.itemBuilder(context, widget.items[index], index),
        if (hasOverflow) ...[
          const SizedBox(height: AppSpacing.space4),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? RemixIcons.arrow_up_s_line
                    : RemixIcons.arrow_down_s_line,
                size: AppSpacing.space16,
              ),
              label: Text(
                _expanded
                    ? '收起'
                    : '查看全部 ${widget.items.length} ${widget.itemUnit}',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
