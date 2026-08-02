import 'package:flutter/material.dart';

import '../token/component.dart';

/// SmartFlow 的紧凑开关。
///
/// 保留 Material 3 [Switch] 的状态、焦点、语义和 48dp 触控目标，仅缩小
/// 视觉呈现，以适配表单行和紧凑菜单的文字密度。
class AppSwitch extends StatelessWidget {
  const AppSwitch({required this.value, required this.onChanged, super.key});

  static const _visualScale = 0.85;
  static const _width = 52.0;

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: AppComponentTokens.controlMinHeight,
      child: Center(
        child: Transform.scale(
          scale: _visualScale,
          transformHitTests: false,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      ),
    );
  }
}
