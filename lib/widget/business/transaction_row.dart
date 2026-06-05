import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../app/provider.dart';
import '../../application/ledger/ledger_query_api.dart';
import '../../design_system/theme/app_text_styles.dart';
import '../../design_system/theme/app_theme_extension.dart';
import '../../design_system/token/spacing.dart';
import 'account_endpoint_view.dart';
import 'account_lookup.dart';
import 'category_avatar.dart';
import 'finance_tone_color.dart';
import 'transaction_list_presentation.dart';
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
  final String? viewAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountLookup =
        ref.watch(accountLookupProvider).value ??
        const AccountLookup(<String, Account>{});
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final textStyles = context.appTextStyles;
    final presentation = buildTransactionRowPresentation(
      item: item,
      accountLookup: accountLookup,
      viewAccountId: viewAccountId,
    );
    final amountColor = financeToneColor(
      colors,
      financeColors,
      presentation.amountTone,
    );

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
            CategoryAvatar(iconKey: presentation.iconKey, size: 24),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TitleLine(
                    title: presentation.title,
                    style: textStyles.listTitle,
                    badges: presentation.badges,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    presentation.subtitle,
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
                    presentation.amountText,
                    style: textStyles.amountList.copyWith(color: amountColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  _AccountLine(flow: presentation.accountFlow),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!enableQuickEdit || !presentation.canQuickEdit) {
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

void _openTransaction(BuildContext context, TransactionListItem item) {
  context.push('/transaction/${item.id}');
}

void _openTransactionEditor(BuildContext context, TransactionListItem item) {
  context.push('/transaction/${item.id}/edit');
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

class _TitleLine extends StatelessWidget {
  const _TitleLine({
    required this.title,
    required this.style,
    required this.badges,
  });

  static const _minBadgeWidth = 48.0;

  final String title;
  final TextStyle style;
  final List<TransactionBadgePresentation> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
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
              child: TransactionProgressBadges(badges: badges),
            ),
          ],
        );
      },
    );
  }
}

class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.flow});

  final TransactionAccountFlowPresentation flow;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.appTextStyles.listSupporting;

    if (flow.out != null && flow.in_ != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: AccountEndpointView(
              endpoint: _endpoint(flow.out!),
              style: textStyle,
            ),
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
            child: AccountEndpointView(
              endpoint: _endpoint(flow.in_!),
              style: textStyle,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: AccountEndpointView(
        endpoint: _endpoint(flow.singleEndpoint),
        style: textStyle,
      ),
    );
  }

  AccountEndpoint _endpoint(AccountEndpointPresentation value) {
    return AccountEndpoint(label: value.label, iconKey: value.iconKey);
  }
}
