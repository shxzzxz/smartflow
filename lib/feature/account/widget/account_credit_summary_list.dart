import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_list_divider.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/finance/finance_summary_row.dart';

class AccountCreditSummaryList extends StatelessWidget {
  const AccountCreditSummaryList({
    required this.items,
    required this.emptyMessage,
    required this.onTap,
    super.key,
  });

  final List<FinanceSummaryRowPresentation> items;
  final String emptyMessage;
  final ValueChanged<FinanceSummaryRowPresentation> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space20),
          child: Text(
            emptyMessage,
            style: context.appTextStyles.formLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return AppSurface(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            FinanceSummaryRow(
              presentation: items[i],
              onTap: () => onTap(items[i]),
            ),
            if (i < items.length - 1) const AppListDivider(),
          ],
        ],
      ),
    );
  }
}
