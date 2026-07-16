import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/list.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';
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
            if (i < items.length - 1) const _SummaryDivider(),
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
                    _SupportingItems(items: presentation.supportingItems),
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
                      child: MoneyText(
                        money: presentation.amount,
                        style: styles.amountList,
                        semantic: MoneySemantic.liability,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    _StatusBadge(status: presentation.status),
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

class _SupportingItems extends StatelessWidget {
  const _SupportingItems({required this.items});

  final List<AccountCreditSummarySupportingItem> items;

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
              color: _toneColor(context, item.tone),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AccountCreditSummaryStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, status.tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppListTokens.statusBackgroundOpacity),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      ),
      child: Text(
        status.label,
        style: context.appTextStyles.badgeLabel.copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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

Color _toneColor(BuildContext context, AccountCreditSummaryTone tone) {
  final colors = Theme.of(context).colorScheme;
  final extension = Theme.of(context).extension<AppThemeExtension>()!;
  return switch (tone) {
    AccountCreditSummaryTone.neutral => colors.onSurfaceVariant,
    AccountCreditSummaryTone.primary => colors.primary,
    AccountCreditSummaryTone.warning => extension.warning,
    AccountCreditSummaryTone.success => extension.success,
    AccountCreditSummaryTone.danger => extension.danger,
  };
}
