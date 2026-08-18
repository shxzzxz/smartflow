import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/list.dart';
import 'package:smartflow/design_system/token/spacing.dart';

import 'bill_status_badge.dart';
import 'money_text.dart';

class BillItemRowPresentation {
  const BillItemRowPresentation({
    required this.id,
    required this.leadingIcon,
    required this.title,
    required this.supportingTexts,
    required this.amount,
    required this.status,
    this.showChevron = false,
  });

  final String id;
  final IconData leadingIcon;
  final String title;
  final List<String> supportingTexts;
  final Money amount;
  final BillStatusBadgePresentation status;
  final bool showChevron;
}

class BillItemRow extends StatelessWidget {
  const BillItemRow({required this.presentation, this.onTap, super.key});

  final BillItemRowPresentation presentation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return Semantics(
      button: onTap != null,
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
              Icon(
                presentation.leadingIcon,
                size: AppSpacing.space20,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.space10),
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
                    const SizedBox(height: AppSpacing.space2),
                    _SupportingItems(items: presentation.supportingTexts),
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
                    MoneyText(
                      money: presentation.amount,
                      style: styles.amountList,
                      semantic: MoneySemantic.liability,
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    BillStatusBadge(status: presentation.status),
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

class _SupportingItems extends StatelessWidget {
  const _SupportingItems({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.space8,
      runSpacing: AppSpacing.space2,
      children: [
        for (final item in items)
          Text(
            item,
            style: styles.listSupporting.copyWith(
              color: colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
