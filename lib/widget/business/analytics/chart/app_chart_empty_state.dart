import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/chart.dart';

class AppChartEmptyState extends StatelessWidget {
  const AppChartEmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppChartGeometry.emptyStateHeight,
      child: Center(
        child: Text(
          message,
          style: context.appTextStyles.listSupporting.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
