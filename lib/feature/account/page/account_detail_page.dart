import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/transaction/transaction_feed.dart';
import '../presentation/account_credit_summary_presentation.dart';
import '../view_model/account_detail_view_model.dart';
import '../view_model/account_transactions_view_model.dart';
import '../view_model/account_view.dart';
import '../widget/account_bill_list.dart';
import '../widget/account_credit_summary_list.dart';

class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDetailViewModelProvider(accountId));
    final loadedAccount = state is AccountDetailLoaded ? state.account : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '账户概览',
              actions: [
                if (loadedAccount != null && !loadedAccount.isArchived)
                  AppHeaderIconButton(
                    onPressed: () => context.push('/account/$accountId/edit'),
                    icon: RemixIcons.edit_line,
                    tooltip: '编辑账户',
                  ),
                if (loadedAccount != null && !loadedAccount.isArchived)
                  AppHeaderIconButton(
                    onPressed: () => _confirmArchive(context, ref),
                    icon: RemixIcons.archive_line,
                    tooltip: '归档账户',
                  ),
                if (loadedAccount != null && loadedAccount.isArchived)
                  AppHeaderIconButton(
                    onPressed: () => _restore(context, ref),
                    icon: RemixIcons.restart_line,
                    tooltip: '恢复账户',
                  ),
                if (loadedAccount != null && loadedAccount.isArchived)
                  AppHeaderIconButton(
                    onPressed: () => _confirmPermanentDelete(context, ref),
                    icon: RemixIcons.delete_bin_line,
                    tooltip: '永久删除账户',
                  ),
              ],
            ),
            Expanded(
              child: switch (state) {
                AccountDetailLoaded(
                  :final account,
                  :final actions,
                  :final transactions,
                  :final contracts,
                  :final bills,
                  :final creditOverview,
                ) =>
                  _AccountDetailContent(
                    account: account,
                    actions: actions,
                    transactions: transactions,
                    contracts: contracts,
                    bills: bills,
                    creditOverview: creditOverview,
                    onLoadMoreTransactions:
                        () =>
                            ref
                                .read(
                                  accountDetailViewModelProvider(
                                    accountId,
                                  ).notifier,
                                )
                                .loadMoreTransactions(),
                  ),
                AccountDetailNotFound() => const Center(child: Text('账户不存在')),
                AccountDetailError(:final message) => Center(
                  child: Text(message),
                ),
                AccountDetailLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final outcome =
        await ref
            .read(accountDetailViewModelProvider(accountId).notifier)
            .restoreAccount();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<void>():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('账户已恢复')));
      case UiActionFailure<void>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('归档账户？'),
          content: const Text('归档后账户将不再用于新交易，历史数据会保留且可以恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('归档'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;

    final outcome =
        await ref
            .read(accountDetailViewModelProvider(accountId).notifier)
            .archiveAccount();
    if (!context.mounted) return;

    switch (outcome) {
      case UiActionSuccess<void>():
        context.go('/account');
      case UiActionFailure<void>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmPermanentDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final danger =
            Theme.of(dialogContext).extension<AppThemeExtension>()?.danger ??
            Theme.of(dialogContext).colorScheme.error;
        return AlertDialog(
          title: const Text('永久删除账户？'),
          content: const Text('账户仅在没有任何业务数据时才能删除。永久删除后无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: danger),
              child: const Text('永久删除'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;

    final outcome =
        await ref
            .read(accountDetailViewModelProvider(accountId).notifier)
            .deletePermanently();
    if (!context.mounted) return;

    switch (outcome) {
      case UiActionSuccess<void>():
        context.go('/account');
      case UiActionFailure<void>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
class _AccountDetailContent extends StatelessWidget {
  const _AccountDetailContent({
    required this.account,
    required this.actions,
    required this.transactions,
    required this.contracts,
    required this.bills,
    required this.creditOverview,
    required this.onLoadMoreTransactions,
  });

  final AccountView account;
  final List<AccountDetailAction> actions;
  final AccountTransactionsState transactions;
  final AccountContractsState contracts;
  final AccountBillsState bills;
  final AccountCreditOverviewState creditOverview;
  final VoidCallback onLoadMoreTransactions;

  @override
  Widget build(BuildContext context) {
    final showInstallments = account.isCreditLiability;
    final feed = switch (transactions) {
      AccountTransactionsLoaded(
        :final groups,
        :final hasMore,
        :final isLoadingMore,
        :final loadMoreErrorMessage,
      ) =>
        (
          groups: groups,
          hasMore: hasMore,
          isLoadingMore: isLoadingMore,
          loadMoreErrorMessage: loadMoreErrorMessage,
          emptyState: null as Widget?,
        ),
      AccountTransactionsError(:final message) => (
        groups: const <TransactionDayGroup>[],
        hasMore: false,
        isLoadingMore: false,
        loadMoreErrorMessage: null as String?,
        emptyState:
            AppSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space20),
                    child: Text(message),
                  ),
                )
                as Widget?,
      ),
      AccountTransactionsLoading() => (
        groups: const <TransactionDayGroup>[],
        hasMore: false,
        isLoadingMore: false,
        loadMoreErrorMessage: null as String?,
        emptyState:
            const AppSurface(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.space20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
                as Widget?,
      ),
    };
    return TransactionFeedScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space12,
        AppSpacing.space8,
        AppSpacing.space12,
        AppSpacing.space20,
      ),
      leading: [
        _AccountInfoSection(account: account, creditOverview: creditOverview),
        const SizedBox(height: AppSpacing.space12),
        if (actions.isNotEmpty) _AccountActionBar(actions: actions),
        if (showInstallments) ...[
          const SizedBox(height: AppSpacing.space20),
          _BillSection(accountId: account.id, bills: bills),
          const SizedBox(height: AppSpacing.space20),
          _InstallmentSection(contracts: contracts, accountKind: account.kind),
          const SizedBox(height: AppSpacing.space20),
        ],
        const _OverviewHeader(title: '账户交易'),
      ],
      groups: feed.groups,
      emptyMessage: '暂无账户交易',
      emptyState: feed.emptyState,
      showDailyTotals: false,
      hasMore: feed.hasMore,
      isLoadingMore: feed.isLoadingMore,
      loadMoreErrorMessage: feed.loadMoreErrorMessage,
      onLoadMore: onLoadMoreTransactions,
    );
  }
}

class _AccountInfoSection extends StatelessWidget {
  const _AccountInfoSection({
    required this.account,
    required this.creditOverview,
  });

  final AccountView account;
  final AccountCreditOverviewState creditOverview;

  @override
  Widget build(BuildContext context) {
    if (account.isCreditLiability) {
      return _CreditHeroCard(account: account, creditOverview: creditOverview);
    }

    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: _AccountBalanceBlock(account: account),
      ),
    );
  }
}

class _CreditHeroCard extends StatelessWidget {
  const _CreditHeroCard({required this.account, required this.creditOverview});

  final AccountView account;
  final AccountCreditOverviewState creditOverview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final gradientEnd =
        Color.lerp(colors.primary, colors.primaryContainer, 0.36) ??
        colors.primary;
    final metrics = _creditDebtMetrics(account, creditOverview);
    final accountMetrics = _creditAccountMetrics(account, creditOverview);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, gradientEnd],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  Expanded(child: _HeroMetric(item: metrics[i])),
                  if (i < metrics.length - 1)
                    const SizedBox(width: AppSpacing.space12),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.space18),
            _HeroInfoRow(items: accountMetrics.take(2).toList()),
            if (account.isCredit && accountMetrics.length > 2) ...[
              const SizedBox(height: AppSpacing.space10),
              _HeroInfoRow(items: accountMetrics.skip(2).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: styles.onPrimaryTiny,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            item.value,
            style: styles.metricValue.copyWith(color: colors.onPrimary),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _HeroInfoRow extends StatelessWidget {
  const _HeroInfoRow({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Text(
              '${items[i].label} ${items[i].value}',
              style: styles.onPrimaryTiny,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (i < items.length - 1) const SizedBox(width: AppSpacing.space12),
        ],
      ],
    );
  }
}

class _AccountBalanceBlock extends StatelessWidget {
  const _AccountBalanceBlock({required this.account});

  final AccountView account;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final amountColor =
        account.balance.minorUnits < 0 ? colors.error : colors.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _balanceTitle(account),
                style: textStyles.detailLabel.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          account.balance.format(),
          style: textStyles.amountPrimary.copyWith(color: amountColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

String _balanceTitle(AccountView account) {
  return switch (account.kind) {
    AccountProfileKind.receivable => '当前应收',
    AccountProfileKind.payable => '当前应付',
    AccountProfileKind.credit || AccountProfileKind.loan => '当前欠款',
    AccountProfileKind.fund || AccountProfileKind.reimbursement => '当前余额',
  };
}

List<_InfoItem> _creditAccountMetrics(
  AccountView account,
  AccountCreditOverviewState creditOverview,
) {
  final loadedOverview =
      creditOverview is AccountCreditOverviewLoaded
          ? creditOverview.overview
          : null;
  final creditLimit = loadedOverview?.creditAccount.creditLimit;
  final availableCredit = loadedOverview?.availableCredit;
  final items = [
    _InfoItem(label: '信用额度', value: creditLimit?.format() ?? '-'),
    _InfoItem(label: '剩余额度', value: availableCredit?.format() ?? '-'),
  ];
  if (account.isCredit) {
    items.addAll([
      _InfoItem(label: '出账日', value: _monthlyDay(account.billingDay)),
      _InfoItem(label: '还款日', value: _monthlyDay(account.repaymentDay)),
    ]);
  }
  return items;
}

List<_InfoItem> _creditDebtMetrics(
  AccountView account,
  AccountCreditOverviewState creditOverview,
) {
  if (!account.isCreditLiability) return const [];
  final loadedOverview =
      creditOverview is AccountCreditOverviewLoaded
          ? creditOverview.overview
          : null;
  return [
    _InfoItem(label: '总欠款', value: account.balance.format()),
    _InfoItem(
      label: '账单欠款',
      value: loadedOverview?.buckets.billDebt.format() ?? '-',
    ),
    _InfoItem(
      label: '未归属欠款',
      value: loadedOverview?.buckets.unattributedDebt.format() ?? '-',
    ),
  ];
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

String _monthlyDay(int? day) {
  if (day == null) {
    return '-';
  }
  return '每月${day.toString().padLeft(2, '0')}日';
}

class _AccountActionBar extends StatelessWidget {
  const _AccountActionBar({required this.actions});

  final List<AccountDetailAction> actions;

  @override
  Widget build(BuildContext context) {
    return _ActionRow(
      children: [
        for (final action in actions)
          _ActionButton(
            iconKey: action.iconKey,
            label: action.label,
            onTap: () => context.push(action.route),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space6,
      ),
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            Expanded(child: children[index]),
            if (index < children.length - 1)
              const SizedBox(width: AppSpacing.space6),
          ],
        ],
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.iconKey,
    required this.label,
    required this.onTap,
  });

  final String iconKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space6,
          vertical: AppSpacing.space6,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            BusinessIcon(
              iconKey: iconKey,
              color: colors.primary,
              size: AppSpacing.space20,
            ),
            const SizedBox(width: AppSpacing.space6),
            Flexible(
              child: Text(
                label,
                style: textStyles.actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.title,
    required this.child,
    this.onViewAll,
  });

  final String title;
  final Widget child;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_OverviewHeader(title: title, onViewAll: onViewAll), child],
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space6,
      ),
      child: Row(
        children: [
          Text(title, style: styles.dateSectionTitle),
          const Spacer(),
          if (onViewAll != null)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看全部',
                      style: styles.listSupporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      RemixIcons.arrow_right_s_line,
                      size: AppSpacing.space16,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BillSection extends StatelessWidget {
  const _BillSection({required this.accountId, required this.bills});

  final String accountId;
  final AccountBillsState bills;

  @override
  Widget build(BuildContext context) {
    return _OverviewSection(
      title: '账单',
      onViewAll: () => context.push('/account/$accountId/bills'),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (bills) {
      AccountBillsLoaded(:final bills) => AccountBillList(bills: bills),
      AccountBillsError(:final message) => AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space12),
          child: Text(message),
        ),
      ),
      AccountBillsLoading() => const AppSurface(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      AccountBillsNotApplicable() => const SizedBox.shrink(),
    };
  }
}

class _InstallmentSection extends StatelessWidget {
  const _InstallmentSection({
    required this.contracts,
    required this.accountKind,
  });

  final AccountContractsState contracts;
  final AccountProfileKind accountKind;

  @override
  Widget build(BuildContext context) {
    return _OverviewSection(title: '分期合同', child: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    return switch (contracts) {
      AccountContractsLoaded(:final contracts) => AccountCreditSummaryList(
        items: [
          for (final contract in contracts)
            installmentAccountCreditSummary(contract, accountKind: accountKind),
        ],
        emptyMessage: '暂无分期合同',
        onTap: (summary) => context.push('/installments/${summary.id}'),
      ),
      AccountContractsError(:final message) => AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space12),
          child: Text(message),
        ),
      ),
      AccountContractsLoading() => const AppSurface(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      AccountContractsNotApplicable() => const SizedBox.shrink(),
    };
  }
}
