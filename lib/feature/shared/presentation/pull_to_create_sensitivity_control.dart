import 'package:flutter/material.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';

class PullToCreateSensitivityControl extends StatelessWidget {
  const PullToCreateSensitivityControl({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final PullToCreateSensitivity selected;
  final ValueChanged<PullToCreateSensitivity> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSlidingSegmentedControl(
      selected: selected,
      onChanged: onChanged,
      segments: const [
        AppSegment(value: PullToCreateSensitivity.sensitive, label: '灵敏'),
        AppSegment(value: PullToCreateSensitivity.standard, label: '标准'),
        AppSegment(value: PullToCreateSensitivity.cautious, label: '稳妥'),
      ],
    );
  }
}
