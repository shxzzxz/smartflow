import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/list.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_list_divider.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';

import '../presentation/account_credit_summary_presentation.dart';

class AccountCreditSummaryList extends StatelessWidget {
  const AccountCreditSummaryList({
    required this.items,
    required this.emptyMessage,
    required this.onTap,
    super.key,
  });

  final List<AccountCreditSummaryPresentation> items;
  final String emptyMessage;
  final ValueChanged<AccountCreditSummaryPresentation> onTap;

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
            _AccountCreditSummaryRow(
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

class _AccountCreditSummaryRow extends StatelessWidget {
  const _AccountCreditSummaryRow({
    required this.presentation,
    required this.onTap,
  });

  final AccountCreditSummaryPresentation presentation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.title,
                      style: styles.listTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    AppSupportingItems(items: presentation.supportingItems),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space10),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppListTokens.trailingMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: presentation.amountLabel == null
                          ? MoneyText(
                              money: presentation.amount,
                              style: styles.amountList,
                              semantic: MoneySemantic.liability,
                            )
                          : Text(
                              presentation.amountLabel!,
                              style: styles.amountList,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    AppStatusBadge(
                      presentation: presentation.status,
                      size: AppStatusBadgeSize.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
