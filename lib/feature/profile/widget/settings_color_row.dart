import 'package:flutter/material.dart';

import '../../../design_system/token/component.dart';
import '../../../design_system/widget/app_settings_row.dart';
import 'settings_color_picker.dart';

class SettingsColorRow extends StatelessWidget {
  const SettingsColorRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.example,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int>? onChanged;
  final Widget? example;

  @override
  Widget build(BuildContext context) {
    return AppSettingsRow(
      label: label,
      description: example == null
          ? '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
          : null,
      enabled: onChanged != null,
      onTap: onChanged == null
          ? null
          : () => showSettingsColorPicker(
              context: context,
              title: label,
              color: value,
              onChanged: onChanged!,
            ),
      child:
          example ??
          Container(
            width: AppComponentTokens.settingsColorSwatchSize,
            height: AppComponentTokens.settingsColorSwatchSize,
            decoration: BoxDecoration(
              color: Color(value),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: AppComponentTokens.outlineWidth,
              ),
            ),
          ),
    );
  }
}
