import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/spacing.dart';

class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;
  final String label;
}

enum AppSegmentedControlSize { medium, small }

enum AppSegmentedControlTone { primary, neutral }

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
    this.size = AppSegmentedControlSize.medium,
    this.tone = AppSegmentedControlTone.primary,
    this.textStyle,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final AppSegmentedControlSize size;
  final AppSegmentedControlTone tone;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = size == AppSegmentedControlSize.small;
    final neutral = tone == AppSegmentedControlTone.neutral;
    return SegmentedButton<T>(
      segments: [
        for (final segment in segments)
          ButtonSegment<T>(value: segment.value, label: Text(segment.label)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(
            compact ? AppSpacing.space32 : AppSpacing.space48,
            AppComponentTokens.controlMinHeight,
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.space2 : AppSpacing.space10,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? neutral
                      ? colors.surfaceContainerHighest
                      : colors.primaryContainer
                  : colors.surfaceContainerLowest,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? neutral
                      ? colors.onSurface
                      : colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
        ),
        textStyle: WidgetStateProperty.resolveWith(
          (states) =>
              textStyle ??
              context.appTextStyles.quickActionLabel(
                selected: states.contains(WidgetState.selected),
              ),
        ),
      ),
    );
  }
}
