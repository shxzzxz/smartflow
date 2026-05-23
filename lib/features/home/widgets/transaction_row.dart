import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../domain/accounting/accounting_api.dart';
import '../../../widgets/business/account_endpoint_view.dart';
import '../../../widgets/business/account_lookup.dart';
import '../../../widgets/business/category_avatar.dart';
import '../view_models/transaction_row_presentation.dart';
import 'transaction_progress_badges.dart';

class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    required this.item,
    super.key,
    this.enableQuickEdit = true,
    this.onQuickEdit,
    this.viewAccountId,
  });

  final TransactionListItem item;
  final bool enableQuickEdit;
  final VoidCallback? onQuickEdit;

  /// 「账户视角」下当前账户 id。提供时,显示对该账户的余额变动而非交易金额。
  final int? viewAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsById =
        ref.watch(accountsByIdProvider).value ?? const <int, Account>{};
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final textStyles = context.appTextStyles;
    final balanceDelta = viewAccountId == null
        ? null
        : balanceDeltaForAccount(
            accountId: viewAccountId!,
            entries: item.entries,
            accountsById: accountsById,
            currencyCode: item.currencyCode,
          );
    final isAccountLedger = balanceDelta != null;
    final color = isAccountLedger
        ? colors.onSurface
        : amountColor(colors, financeColors, item.businessPurpose);
    final title = transactionPrimaryLabel(item, accountsById);
    final note = item.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final subtitle = hasNote
        ? '${formatTime(item.occurredAt)}  $note'
        : formatTime(item.occurredAt);
    final hasBadges = _hasBadges(item);

    final row = InkWell(
      onTap: () => _openTransaction(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CategoryAvatar(
              iconKey: resolveCategoryIconKey(item, accountsById),
              size: 24,
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TitleLine(
                    title: title,
                    style: textStyles.listTitle,
                    item: item,
                    hasBadges: hasBadges,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    subtitle,
                    style: textStyles.listSupporting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isAccountLedger
                        ? _formatAccountDelta(balanceDelta)
                        : formatTransactionAmount(item),
                    style: textStyles.amountList.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  _AccountLine(item: item, accountsById: accountsById),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!enableQuickEdit || !canQuickEditTransaction(item)) {
      return row;
    }

    return Dismissible(
      key: ValueKey('transaction-row-${item.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.4},
      background: const _QuickEditBackground(),
      confirmDismiss: (direction) {
        if (direction == DismissDirection.startToEnd) {
          final callback = onQuickEdit;
          if (callback != null) {
            callback();
          } else {
            _openTransactionEditor(context, item);
          }
        }
        return Future.value(false);
      },
      child: row,
    );
  }
}

String _formatAccountDelta(Money delta) {
  final sign = delta.minorUnits >= 0 ? '+' : '-';
  return '$sign${formatMinorAmount(delta.minorUnits)}';
}

void _openTransaction(BuildContext context, TransactionListItem item) {
  context.push('/transactions/${item.id}');
}

void _openTransactionEditor(BuildContext context, TransactionListItem item) {
  context.push('/transactions/${item.id}/edit');
}

class _QuickEditBackground extends StatelessWidget {
  const _QuickEditBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.primaryContainer),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                RemixIcons.edit_2_line,
                size: AppSpacing.space20,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.space8),
              Text(
                '编辑',
                style: textStyles.formLabel.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasBadges(TransactionListItem item) {
  if (item.isExcludedFromStats ||
      item.isExcludedFromBudget ||
      item.refundedTotal != null ||
      item.reimbursementReceivedTotal != null ||
      item.reimbursementGapIncome != null ||
      item.reimbursementGapExpense != null) {
    return true;
  }
  for (final line in item.details) {
    if (line.amount.minorUnits <= 0) continue;
    switch (line.type) {
      case TransactionDetailType.repaymentInterest:
      case TransactionDetailType.repaymentFee:
      case TransactionDetailType.repaymentDiscount:
        return true;
      default:
        break;
    }
  }
  return false;
}

class _TitleLine extends StatelessWidget {
  const _TitleLine({
    required this.title,
    required this.style,
    required this.item,
    required this.hasBadges,
  });

  static const _minBadgeWidth = 48.0;

  final String title;
  final TextStyle style;
  final TransactionListItem item;
  final bool hasBadges;

  @override
  Widget build(BuildContext context) {
    if (!hasBadges) {
      return Text(
        title,
        style: style,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const gap = AppSpacing.space8;
        if (maxWidth <= gap + _minBadgeWidth) {
          return Text(
            title,
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        }

        final titlePainter = TextPainter(
          text: TextSpan(text: title, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: double.infinity);
        final maxTitleWidth = maxWidth - gap - _minBadgeWidth;
        final titleWidth = titlePainter.width.clamp(0.0, maxTitleWidth);
        final badgeWidth = maxWidth - titleWidth - gap;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: titleWidth,
              child: Text(
                title,
                style: style,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: badgeWidth,
              child: TransactionProgressBadges(item: item),
            ),
          ],
        );
      },
    );
  }
}

class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.item, required this.accountsById});

  final TransactionListItem item;
  final Map<int, Account> accountsById;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.appTextStyles.listSupporting;
    final flow = _resolveAccountFlow(item, accountsById);
    final fallbackText = transactionAccountLabel(item, accountsById);

    if (flow.out != null && flow.in_ != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: AccountEndpointView(endpoint: flow.out!, style: textStyle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: Text(
              flow.separator,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
          Flexible(
            child: AccountEndpointView(endpoint: flow.in_!, style: textStyle),
          ),
        ],
      );
    }

    final endpoint =
        flow.out ??
        flow.in_ ??
        AccountEndpoint(
          label: fallbackText.isEmpty ? '未分配账户' : fallbackText,
          iconKey: null,
        );
    return Align(
      alignment: Alignment.centerRight,
      child: AccountEndpointView(endpoint: endpoint, style: textStyle),
    );
  }
}

class _AccountFlow {
  const _AccountFlow({this.out, this.in_, this.separator = '→'});

  final AccountEndpoint? out;
  final AccountEndpoint? in_;
  final String separator;
}

_AccountFlow _resolveAccountFlow(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  AccountEndpoint? endpointOf(Account? account) {
    if (account == null) return null;
    return AccountEndpoint(label: account.name, iconKey: account.iconKey);
  }

  final out = endpointOf(flowOutAccount(item, accountsById));
  final in_ = endpointOf(flowInAccount(item, accountsById));

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense => _AccountFlow(out: out),
    BusinessPurpose.reimbursementAdvance => _AccountFlow(
      out: in_,
      in_: out,
      separator: '|',
    ),
    BusinessPurpose.dailyIncome => _AccountFlow(in_: in_),
    _ => _AccountFlow(out: out, in_: in_),
  };
}
