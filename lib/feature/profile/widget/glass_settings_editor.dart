import 'package:flutter/material.dart';

import '../../../application/shared/app_glass_settings.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/appearance.dart';
import '../../../design_system/token/spacing.dart';

/// 导航栏和顶部两层玻璃复用的参数编辑器。
class GlassSettingsEditor extends StatelessWidget {
  const GlassSettingsEditor({
    required this.value,
    required this.onChanged,
    super.key,
    this.showShadowControl = true,
  });

  final AppGlassSettings value;
  final ValueChanged<AppGlassSettings>? onChanged;
  final bool showShadowControl;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.space16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassSlider(
          label: '模糊程度',
          value: value.blurSigma,
          maximum: AppAppearanceTokens.maxGlassBlur,
          divisions: AppAppearanceTokens.maxGlassBlur.round(),
          display: value.blurSigma.round().toString(),
          onChanged: onChanged == null
              ? null
              : (blur) => onChanged!(value.copyWith(blurSigma: blur)),
        ),
        const SizedBox(height: AppSpacing.space8),
        _GlassSlider(
          label: '背景不透明度',
          value: value.backgroundOpacity,
          display: '${(value.backgroundOpacity * 100).round()}%',
          onChanged: onChanged == null
              ? null
              : (opacity) =>
                    onChanged!(value.copyWith(backgroundOpacity: opacity)),
        ),
        const SizedBox(height: AppSpacing.space8),
        _GlassSlider(
          label: '色彩饱和度',
          value: value.saturation,
          maximum: AppAppearanceTokens.maxGlassSaturation,
          divisions: (AppAppearanceTokens.maxGlassSaturation * 100).round(),
          display: '${(value.saturation * 100).round()}%',
          onChanged: onChanged == null
              ? null
              : (saturation) =>
                    onChanged!(value.copyWith(saturation: saturation)),
        ),
        if (showShadowControl) ...[
          const SizedBox(height: AppSpacing.space8),
          _GlassSlider(
            label: '阴影强度',
            value: value.shadowOpacity,
            maximum: AppAppearanceTokens.maxGlassShadowOpacity,
            divisions: (AppAppearanceTokens.maxGlassShadowOpacity * 100)
                .round(),
            display: '${(value.shadowOpacity * 100).round()}%',
            onChanged: onChanged == null
                ? null
                : (opacity) =>
                      onChanged!(value.copyWith(shadowOpacity: opacity)),
          ),
        ],
      ],
    ),
  );
}

class _GlassSlider extends StatelessWidget {
  const _GlassSlider({
    required this.label,
    required this.value,
    required this.display,
    required this.onChanged,
    this.maximum = 1,
    this.divisions = 100,
  });

  final String label;
  final double value;
  final String display;
  final double maximum;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(label, style: context.appTextStyles.settingsTitle),
          ),
          const SizedBox(width: AppSpacing.space8),
          Text(display, style: context.appTextStyles.listSupporting),
        ],
      ),
      Slider(
        value: value,
        max: maximum,
        divisions: divisions,
        label: display,
        semanticFormatterCallback: (_) => '$label $display',
        onChanged: onChanged,
      ),
    ],
  );
}
