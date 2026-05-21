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
import '../../../widgets/business/category_avatar.dart';
import '../view_models/transaction_row_presentation.dart';
import 'transaction_progress_badges.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    required this.item,
    super.key,
    this.enableQuickEdit = true,
    this.onQuickEdit,
  });

  final TransactionListItem item;
  final bool enableQuickEdit;
  final VoidCallback? onQuickEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final textStyles = context.appTextStyles;
    final isAccountLedger = item.accountBalanceDelta != null;
    final color =
        isAccountLedger
            ? colors.onSurface
            : amountColor(colors, financeColors, item.businessPurpose);
    final title = transactionPrimaryLabel(item);
    final note = item.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final subtitle =
        hasNote
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
            CategoryAvatar(iconKey: resolveCategoryIconKey(item), size: 24),
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
                        ? _formatAccountDelta(item.accountBalanceDelta!)
                        : formatTransactionAmount(item),
                    style: textStyles.amountList.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  _AccountLine(item: item),
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
  return item.isExcludedFromStats ||
      item.isExcludedFromBudget ||
      item.refundedTotal != null ||
      item.reimbursementReceivedTotal != null ||
      item.repaymentInterest != null ||
      item.repaymentFee != null ||
      item.repaymentDiscount != null ||
      item.reimbursementGapIncome != null ||
      item.reimbursementGapExpense != null;
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

class _AccountLine extends ConsumerWidget {
  const _AccountLine({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountListProvider).value ?? const <Account>[];
    final textStyle = context.appTextStyles.listSupporting;
    final flow = _resolveAccountFlow(item, accounts);
    final fallbackText = transactionAccountLabel(item);

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
  List<Account> accounts,
) {
  final flowOut = _resolveAccountEndpoint(
    id: item.flowOutAccountId,
    name: item.flowOutAccountName,
    accounts: accounts,
  );
  final flowIn = _resolveAccountEndpoint(
    id: item.flowInAccountId,
    name: item.flowInAccountName,
    accounts: accounts,
  );

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense => _AccountFlow(out: flowOut),
    BusinessPurpose.reimbursementAdvance => _AccountFlow(
      out: flowIn,
      in_: flowOut,
      separator: '|',
    ),
    BusinessPurpose.dailyIncome => _AccountFlow(in_: flowIn),
    _ => _AccountFlow(out: flowOut, in_: flowIn),
  };
}

AccountEndpoint? _resolveAccountEndpoint({
  required int? id,
  required String? name,
  required List<Account> accounts,
}) {
  final account = _findAccount(id, accounts);
  final label = _cleanText(name) ?? account?.name;
  if (label == null) return null;
  return AccountEndpoint(label: label, iconKey: account?.iconKey);
}

Account? _findAccount(int? id, List<Account> accounts) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
