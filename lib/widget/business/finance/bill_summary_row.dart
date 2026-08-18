import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/list.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';

import 'bill_status_badge.dart';
import 'money_text.dart';

class BillSummarySupportingText {
  const BillSummarySupportingText({
    required this.text,
    this.tone = BillStatusTone.neutral,
  });

  final String text;
  final BillStatusTone tone;
}

class BillSummaryRowPresentation {
  const BillSummaryRowPresentation({
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
  final List<BillSummarySupportingText> supportingTexts;
  final BillStatusBadgePresentation status;
  final bool showChevron;
}

class BillSummaryRow extends StatelessWidget {
  const BillSummaryRow({
    required this.presentation,
    required this.onTap,
    super.key,
  });

  final BillSummaryRowPresentation presentation;
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child:
                          presentation.amountLabel == null
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

class BillSummaryList extends StatelessWidget {
  const BillSummaryList({
    required this.items,
    required this.emptyMessage,
    required this.onTap,
    super.key,
  });

  final List<BillSummaryRowPresentation> items;
  final String emptyMessage;
  final ValueChanged<BillSummaryRowPresentation> onTap;

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
            BillSummaryRow(
              presentation: items[i],
              onTap: () => onTap(items[i]),
            ),
            if (i < items.length - 1) const _SummaryDivider(),
          ],
        ],
      ),
    );
  }
}

class _SupportingItems extends StatelessWidget {
  const _SupportingItems({required this.items});

  final List<BillSummarySupportingText> items;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Wrap(
      spacing: AppSpacing.space8,
      runSpacing: AppSpacing.space2,
      children: [
        for (final item in items)
          Text(
            item.text,
            style: styles.listSupporting.copyWith(
              color: billStatusToneColor(context, item.tone),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
      height: AppListTokens.dividerThickness,
      color: colors.outlineVariant.withValues(
        alpha: AppListTokens.dividerOpacity,
      ),
    );
  }
}
