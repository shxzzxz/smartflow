import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/token/transaction.dart';
import 'package:smartflow/design_system/widget/app_swipe_action.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';

import '../account/account_endpoint.dart';
import '../account/account_endpoint_view.dart';
import '../category/category_avatar.dart';
import '../finance/finance_tone_color.dart';
import 'transaction_progress_badges.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    required this.presentation,
    required this.onTap,
    super.key,
    this.enableQuickEdit = true,
    this.onQuickEdit,
  });

  final TransactionRowPresentation presentation;
  final VoidCallback onTap;
  final bool enableQuickEdit;
  final VoidCallback? onQuickEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final textStyles = context.appTextStyles;
    final amountColor = financeToneColor(
      colors,
      financeColors,
      presentation.amountTone,
    );

    final row = SizedBox(
      width: double.infinity,
      height: AppTransactionTokens.rowHeight,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space8,
            vertical: AppSpacing.space8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CategoryAvatar(
                iconKey: presentation.iconKey,
                size: AppSpacing.space32,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.space24,
                      child: _PrimaryLine(
                        title: presentation.title,
                        titleStyle: textStyles.transactionTitle,
                        amount: presentation.amountText,
                        compactAmount:
                            presentation.compactAmountText ??
                            presentation.amountText,
                        originalAmount: presentation.originalAmountText,
                        originalCompactAmount:
                            presentation.originalCompactAmountText,
                        amountStyle: textStyles.transactionAmount.copyWith(
                          color: amountColor,
                        ),
                        originalAmountStyle: textStyles.transactionSupporting,
                        badges: presentation.badges,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.space16,
                      child: Row(
                        children: [
                          Text(
                            presentation.subtitle,
                            style: textStyles.transactionSupporting,
                            maxLines: 1,
                          ),
                          const SizedBox(width: AppSpacing.space8),
                          Expanded(
                            child: _AccountLine(
                              flow: presentation.accountFlow,
                              style: textStyles.transactionSupporting,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!enableQuickEdit || !presentation.canQuickEdit || onQuickEdit == null) {
      return row;
    }

    return SizedBox(
      width: double.infinity,
      child: AppSwipeAction(
        dismissibleKey: ValueKey(
          'transaction-row-${presentation.transactionId}',
        ),
        label: '编辑',
        icon: RemixIcons.edit_2_line,
        onTriggered: () => onQuickEdit?.call(),
        child: row,
      ),
    );
  }
}

class _PrimaryLine extends StatelessWidget {
  static const _titleBadgeColumnCount = 2;

  const _PrimaryLine({
    required this.title,
    required this.titleStyle,
    required this.amount,
    required this.compactAmount,
    required this.originalAmount,
    required this.originalCompactAmount,
    required this.amountStyle,
    required this.originalAmountStyle,
    required this.badges,
  });

  final String title;
  final TextStyle titleStyle;
  final String amount;
  final String compactAmount;
  final String? originalAmount;
  final String? originalCompactAmount;
  final TextStyle amountStyle;
  final TextStyle originalAmountStyle;
  final List<TransactionBadgePresentation> badges;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Keep long titles from consuming the badge area, while letting
              // any unused part of the title allowance flow to the badges.
              final titleMaxWidth =
                  badges.isEmpty
                      ? AppTransactionTokens.categoryMaxWidth
                      : ((constraints.maxWidth - AppSpacing.space8) /
                              _titleBadgeColumnCount)
                          .clamp(
                            AppSpacing.space0,
                            AppTransactionTokens.categoryMaxWidth,
                          );

              return Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: titleMaxWidth),
                    child: Text(
                      title,
                      style: titleStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.space8),
                    Expanded(child: TransactionProgressBadges(badges: badges)),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(width: AppSpacing.space8),
        if (originalAmount != null)
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTransactionTokens.comparedAmountMaxWidth,
            ),
            child: ComparedMoneyText(
              originalPreciseText: originalAmount!,
              originalCompactText: originalCompactAmount ?? originalAmount!,
              actualPreciseText: amount,
              actualCompactText: compactAmount,
              originalStyle: originalAmountStyle,
              actualStyle: amountStyle,
              maxWidth: AppTransactionTokens.comparedAmountMaxWidth,
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTransactionTokens.amountMaxWidth,
            ),
            child: AdaptiveMoneyText(
              preciseText: amount,
              compactText: compactAmount,
              style: amountStyle,
              maxWidth: AppTransactionTokens.amountMaxWidth,
            ),
          ),
      ],
    );
  }
}

class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.flow, required this.style});

  final TransactionAccountFlowPresentation flow;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (flow.out != null && flow.in_ != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: AccountEndpointView.compactTrailing(
              endpoint: _endpoint(flow.out!),
              style: style,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
            child: Text(
              flow.separator,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
          Flexible(
            child: AccountEndpointView.compactTrailing(
              endpoint: _endpoint(flow.in_!),
              style: style,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: AccountEndpointView.compactTrailing(
        endpoint: _endpoint(flow.singleEndpoint),
        style: style,
      ),
    );
  }

  AccountEndpoint _endpoint(AccountEndpointPresentation value) {
    return AccountEndpoint(label: value.label, iconKey: value.iconKey);
  }
}
