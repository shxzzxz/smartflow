import 'package:flutter/material.dart';

import '../../design_system/token/radius.dart';
import '../../design_system/token/spacing.dart';
import 'business_icon_bubble.dart';

class IconChoiceGrid extends StatelessWidget {
  const IconChoiceGrid({
    required this.choices,
    required this.selectedKey,
    required this.onChanged,
    super.key,
    this.crossAxisCount = 5,
    this.maxVisibleRows = 4,
    this.iconSize = 28,
    this.bubbleSize = 32,
    this.tileMainExtent = 64,
    this.mainAxisSpacing = AppSpacing.space0,
    this.crossAxisSpacing = AppSpacing.space16,
    this.bubbleColor,
    this.selectedBubbleColor,
  });

  final List<IconChoiceGridItem> choices;
  final String? selectedKey;
  final ValueChanged<String> onChanged;
  final int crossAxisCount;
  final int maxVisibleRows;
  final double iconSize;
  final double bubbleSize;
  final double tileMainExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final Color? bubbleColor;
  final Color? selectedBubbleColor;

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) {
      return const SizedBox.shrink();
    }

    final rowCount = (choices.length / crossAxisCount).ceil();
    final height =
        maxVisibleRows * tileMainExtent +
        (maxVisibleRows - 1) * mainAxisSpacing;

    return SizedBox(
      height: height,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        primary: false,
        itemCount: choices.length,
        physics:
            rowCount > maxVisibleRows
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisExtent: tileMainExtent,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
        ),
        itemBuilder: (context, index) {
          final choice = choices[index];
          return _IconChoiceTile(
            choice: choice,
            selected: choice.iconKey == selectedKey,
            iconSize: iconSize,
            bubbleSize: bubbleSize,
            tileMainExtent: tileMainExtent,
            bubbleColor: bubbleColor,
            selectedBubbleColor: selectedBubbleColor,
            onTap: () => onChanged(choice.iconKey),
          );
        },
      ),
    );
  }
}

class IconChoiceGridItem {
  const IconChoiceGridItem({
    required this.iconKey,
    required this.label,
    required this.iconBuilder,
    this.accentColor,
  });

  final String iconKey;
  final String label;
  final Widget Function(BuildContext context, double size) iconBuilder;
  final Color? accentColor;
}

class _IconChoiceTile extends StatelessWidget {
  const _IconChoiceTile({
    required this.choice,
    required this.selected,
    required this.iconSize,
    required this.bubbleSize,
    required this.tileMainExtent,
    required this.bubbleColor,
    required this.selectedBubbleColor,
    required this.onTap,
  });

  final IconChoiceGridItem choice;
  final bool selected;
  final double iconSize;
  final double bubbleSize;
  final double tileMainExtent;
  final Color? bubbleColor;
  final Color? selectedBubbleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BusinessIconTile(
      extent: tileMainExtent,
      borderRadius: AppRadius.radiusLg,
      onTap: onTap,
      child: BusinessIconBubble(
        size: bubbleSize,
        selected: selected,
        label: choice.label,
        bubbleColor: bubbleColor,
        selectedBubbleColor: selectedBubbleColor,
        child: choice.iconBuilder(context, iconSize),
      ),
    );
  }
}
