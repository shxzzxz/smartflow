import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';

class LoanConfigurationEntry extends StatelessWidget {
  const LoanConfigurationEntry({
    required this.label,
    required this.configured,
    required this.onTap,
    super.key,
  });
  final String label;
  final bool configured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.appTextStyles.groupTitle),
                  const SizedBox(height: AppSpacing.space6),
                  Text(
                    configured ? '已配置' : '点击配置',
                    style: context.appTextStyles.listSupporting,
                  ),
                ],
              ),
            ),
            const Icon(RemixIcons.arrow_right_s_line),
          ],
        ),
      ),
    ),
  );
}
