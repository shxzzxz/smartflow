import 'package:flutter/material.dart';

import 'package:smartflow/design_system/widget/app_empty_state.dart';
import 'package:smartflow/design_system/widget/app_list_section.dart';
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

    return AppListSection(
      children: [
        for (final item in items)
          FinanceSummaryRow(presentation: item, onTap: () => onTap(item)),
      ],
    );
  }
}
