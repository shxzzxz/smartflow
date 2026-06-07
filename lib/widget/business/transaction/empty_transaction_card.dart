import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';

class EmptyTransactionCard extends StatelessWidget {
  const EmptyTransactionCard({super.key, this.message = '本月暂无交易记录'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Row(
          children: [
            Icon(RemixIcons.file_list_3_line, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Text(
                message,
                style: context.appTextStyles.inputText.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
