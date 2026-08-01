import 'package:flutter/material.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.visibleMonth,
    required this.onMonthPressed,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.trailing,
    super.key,
  });

  final DateTime visibleMonth;
  final VoidCallback onMonthPressed;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space10,
        AppSpacing.space8,
        AppSpacing.space12,
      ),
      child: Row(
        children: [
          AppMonthSelector(
            visibleMonth: visibleMonth,
            onPreviousMonth: onPreviousMonth,
            onMonthPressed: onMonthPressed,
            onNextMonth: onNextMonth,
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
