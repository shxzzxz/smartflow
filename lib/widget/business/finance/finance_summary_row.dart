import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/list.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';

import 'money_text.dart';

class FinanceSummaryRowPresentation {
  const FinanceSummaryRowPresentation({
    required this.id,
    required this.title,
    required this.amount,
    required this.supportingTexts,
    required this.status,
    this.amountLabel,
    this.showChevron = false,
  });

  final String id;
  final String title;
  final Money amount;
  final String? amountLabel;
  final List<AppSupportingText> supportingTexts;
  final AppStatusBadgePresentation status;
  final bool showChevron;
}

class FinanceSummaryRow extends StatelessWidget {
  const FinanceSummaryRow({
    required this.presentation,
    required this.onTap,
    super.key,
  });

  final FinanceSummaryRowPresentation presentation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                    AppSupportingItems(items: presentation.supportingTexts),
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
              if (presentation.showChevron) ...[
                const SizedBox(width: AppSpacing.space4),
                Icon(
                  RemixIcons.arrow_right_s_line,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
