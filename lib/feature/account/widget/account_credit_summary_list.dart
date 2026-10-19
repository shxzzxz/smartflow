import 'package:flutter/material.dart';

import 'package:smartflow/design_system/widget/app_empty_state.dart';
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
        child: AppEmptyState(
          layout: AppEmptyStateLayout.inline,
          title: emptyMessage,
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
