import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_section_header.dart';

typedef AppChoiceIconBuilder =
    Widget Function(BuildContext context, double size);

class AppChoiceGridGroup<T> {
  const AppChoiceGridGroup({
    required this.id,
    required this.label,
    required this.items,
  });

  final String id;
  final String label;
  final List<AppChoiceGridItem<T>> items;
}

class AppChoiceGridItem<T> {
  const AppChoiceGridItem({
    required this.id,
    required this.value,
    required this.label,
    required this.iconBuilder,
  });

  final String id;
  final T value;
  final String label;
  final AppChoiceIconBuilder iconBuilder;
}

class AppGroupedChoiceGrid<T> extends StatelessWidget {
  const AppGroupedChoiceGrid({
    required this.groups,
    required this.onSelected,
    super.key,
    this.selectedId,
    this.minItemWidth = AppComponentTokens.choiceGridMinItemWidth,
    this.maxColumns = 4,
    this.iconSize = AppSpacing.space20,
  });

  final List<AppChoiceGridGroup<T>> groups;
  final ValueChanged<AppChoiceGridItem<T>> onSelected;
  final String? selectedId;
  final double minItemWidth;
  final int maxColumns;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final visibleGroups = [
      for (final group in groups)
        if (group.items.isNotEmpty) group,
    ];
    if (visibleGroups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < visibleGroups.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.space16),
          AppSectionHeader(
            key: ValueKey('app-choice-grid-group-${visibleGroups[index].id}'),
            title: visibleGroups[index].label,
          ),
          const SizedBox(height: AppSpacing.space8),
          _AppChoiceGroupGrid<T>(
            group: visibleGroups[index],
            selectedId: selectedId,
            onSelected: onSelected,
            minItemWidth: minItemWidth,
            maxColumns: maxColumns,
            iconSize: iconSize,
          ),
        ],
      ],
    );
  }
}

class _AppChoiceGroupGrid<T> extends StatelessWidget {
  const _AppChoiceGroupGrid({
    required this.group,
    required this.selectedId,
    required this.onSelected,
    required this.minItemWidth,
    required this.maxColumns,
    required this.iconSize,
  });

  final AppChoiceGridGroup<T> group;
  final String? selectedId;
  final ValueChanged<AppChoiceGridItem<T>> onSelected;
  final double minItemWidth;
  final int maxColumns;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final effectiveMinWidth = (minItemWidth * textScale.clamp(1.0, 1.75))
        .toDouble();
    final itemMainExtent =
        (AppComponentTokens.choiceGridItemMainExtent +
                (textScale.clamp(1.0, 3.0) - 1) * AppSpacing.space24)
            .toDouble();
    const spacing = AppSpacing.space8;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount =
            ((constraints.maxWidth + spacing) / (effectiveMinWidth + spacing))
                .floor()
                .clamp(1, maxColumns)
                .toInt();
        final rowCount = (group.items.length / columnCount).ceil();
        final height = rowCount * itemMainExtent + (rowCount - 1) * spacing;

        return SizedBox(
          height: height,
          child: GridView.builder(
            key: ValueKey('app-choice-grid-${group.id}'),
            padding: EdgeInsets.zero,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              mainAxisExtent: itemMainExtent,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
            ),
            itemBuilder: (context, index) {
              final item = group.items[index];
              final selected = item.id == selectedId;
              final foreground = selected ? colors.primary : colors.onSurface;

              return Semantics(
                button: true,
                selected: selected,
                label: item.label,
                excludeSemantics: true,
                child: Material(
                  color: selected
                      ? colors.primary.withValues(
                          alpha: AppComponentTokens.selectedContainerOpacity,
                        )
                      : colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey(
                      'app-choice-grid-item-${group.id}-${item.id}',
                    ),
                    onTap: () => onSelected(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space4,
                        vertical: AppSpacing.space6,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: iconSize,
                            child: IconTheme.merge(
                              data: IconThemeData(
                                color: foreground,
                                size: iconSize,
                              ),
                              child: item.iconBuilder(context, iconSize),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          Flexible(
                            child: Text(
                              item.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.appTextStyles.iconGridLabel
                                  .copyWith(color: foreground),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
