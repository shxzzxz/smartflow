import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;
  final String label;
}

enum AppSegmentedControlSize { medium, small }

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
    this.size = AppSegmentedControlSize.medium,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final AppSegmentedControlSize size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = size == AppSegmentedControlSize.small;
    return SegmentedButton<T>(
      segments: [
        for (final segment in segments)
          ButtonSegment<T>(value: segment.value, label: Text(segment.label)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStatePropertyAll(
          Size(
            compact ? AppSpacing.space40 : AppSpacing.space48,
            compact ? AppSpacing.space28 : AppSpacing.space32,
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.space6 : AppSpacing.space10,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          ),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: colors.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? colors.primaryContainer
                  : colors.surfaceContainerLowest,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
        ),
        textStyle: WidgetStateProperty.resolveWith(
          (states) => context.appTextStyles.quickActionLabel(
            selected: states.contains(WidgetState.selected),
          ),
        ),
      ),
    );
  }
}
