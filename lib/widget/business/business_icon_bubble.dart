import 'package:flutter/material.dart';

import '../../design_system/theme/app_text_styles.dart';
import '../../design_system/token/radius.dart';
import '../../design_system/token/spacing.dart';

class BusinessIconTile extends StatelessWidget {
  const BusinessIconTile({
    required this.child,
    super.key,
    this.onTap,
    this.onLongPress,
    this.extent = 64,
    this.borderRadius = AppRadius.radiusLg,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double extent;
  final double borderRadius;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox.square(
      dimension: extent,
      child: Center(child: child),
    );

    if (onTap == null && onLongPress == null) {
      return Align(alignment: alignment, child: content);
    }

    return Align(
      alignment: alignment,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}

class BusinessIconBubble extends StatelessWidget {
  const BusinessIconBubble({
    required this.child,
    super.key,
    this.size = 32,
    this.selected = false,
    this.label,
    this.onTap,
    this.bubbleColor,
    this.selectedBubbleColor,
    this.iconColor,
    this.labelSpacing = AppSpacing.space6,
    this.labelMaxLines = 2,
    this.tapBorderRadius = AppRadius.radiusLg,
    this.tapAreaWidth,
    this.tapAreaAlignment = Alignment.center,
  });

  final Widget child;
  final double size;
  final bool selected;
  final String? label;
  final VoidCallback? onTap;
  final Color? bubbleColor;
  final Color? selectedBubbleColor;
  final Color? iconColor;
  final double labelSpacing;
  final int labelMaxLines;
  final double tapBorderRadius;
  final double? tapAreaWidth;
  final AlignmentGeometry tapAreaAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveBubbleColor =
        selected
            ? selectedBubbleColor ??
                bubbleColor ??
                colors.primary.withValues(alpha: 0.12)
            : bubbleColor ?? Colors.transparent;

    Widget icon = Center(child: child);
    icon = IconTheme.merge(
      data: IconThemeData(color: iconColor ?? colors.onSurface),
      child: icon,
    );

    final bubble = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBubbleColor,
        shape: BoxShape.circle,
      ),
      child: icon,
    );

    final content =
        label == null
            ? bubble
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble,
                SizedBox(height: labelSpacing),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  maxLines: labelMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.iconGridLabel,
                ),
              ],
            );

    final tapContent =
        tapAreaWidth == null
            ? content
            : SizedBox(
              width: tapAreaWidth,
              child: Align(alignment: tapAreaAlignment, child: content),
            );

    if (onTap == null) {
      return tapContent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tapBorderRadius),
      child: tapContent,
    );
  }
}
