import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart' as credit_command;
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/shared/app_task.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';
import '../../credit/provider/bill_query_providers.dart';
import '../../credit/provider/credit_account_query_providers.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../view_model/account_detail_view_model.dart';
import '../view_model/account_view.dart';
import '../view_model/account_views_provider.dart';

class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDetailViewModelProvider(accountId));
    final loadedAccount = state is AccountDetailLoaded ? state.account : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户详情'),
        actions: [
          if (loadedAccount != null && !loadedAccount.isArchived)
            IconButton(
              onPressed: () => context.push('/account/$accountId/edit'),
              icon: const Icon(RemixIcons.edit_line),
              tooltip: '编辑账户',
            ),
          if (loadedAccount != null && loadedAccount.isCreditLiability)
            PopupMenuButton<_AccountMenuAction>(
              onSelected:
                  (action) => _handleMenuAction(context, ref, loadedAccount),
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: _AccountMenuAction.archiveToggle,
                      child: Text(loadedAccount.isArchived ? '取消归档' : '归档账户'),
                    ),
                  ],
            ),
        ],
      ),
      body: switch (state) {
        AccountDetailLoaded(
          :final account,
          :final transactionGroups,
          :final contracts,
          :final bills,
          :final creditOverview,
        ) =>
          _AccountDetailContent(
            account: account,
            transactionGroups: transactionGroups,
            contracts: contracts,
            bills: bills,
            creditOverview: creditOverview,
          ),
        AccountDetailNotFound() => const Center(child: Text('账户不存在')),
        AccountDetailError(:final message) => Center(child: Text(message)),
        AccountDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      },
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    AccountView account,
  ) async {
    if (account.isArchived) {
      await ref
          .read(accountAppServiceProvider)
          .unarchiveAccount(UnarchiveAccountCommand(id: account.id));
      await ref
          .read(pullTaskSchedulerProvider)
          .trigger(trigger: TaskTrigger.beforeCreditWrite, force: true);
      ref.invalidate(accountViewsProvider);
      ref.invalidate(accountByIdProvider(account.id));
      ref.invalidate(billSummariesByAccountProvider(account.id));
      return;
    }

    final hasUnsettled = await ref
        .read(billQueryServiceProvider)
        .hasUnsettledObligations(account.id);
    if (!context.mounted) return;
    if (hasUnsettled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('归档账户'),
              content: const Text('该账户仍有未结清账单或计划。归档后不会继续生成新账单。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('归档'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(accountAppServiceProvider)
        .archiveAccount(ArchiveAccountCommand(id: account.id));
    ref.invalidate(accountViewsProvider);
    ref.invalidate(accountByIdProvider(account.id));
    ref.invalidate(billSummariesByAccountProvider(account.id));
  }
}

enum _AccountMenuAction { archiveToggle }

class _AccountDetailContent extends StatelessWidget {
  const _AccountDetailContent({
    required this.account,
    required this.transactionGroups,
    required this.contracts,
    required this.bills,
    required this.creditOverview,
  });

  final AccountView account;
  final List<TransactionDayGroup> transactionGroups;
  final AccountContractsState contracts;
  final AccountBillsState bills;
  final AccountCreditOverviewState creditOverview;

  @override
  Widget build(BuildContext context) {
    final showInstallments = account.isLiability;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space10,
        AppSpacing.space6,
        AppSpacing.space10,
        AppSpacing.space16,
      ),
      children: [
        _AccountInfoSection(account: account, creditOverview: creditOverview),
        const SizedBox(height: AppSpacing.space8),
        _AccountActionBar(account: account),
        if (_hasUnattributedRepayments(creditOverview)) ...[
          const SizedBox(height: AppSpacing.space8),
          _UnattributedRepaymentSection(
            accountId: account.id,
            overview: creditOverview,
          ),
        ],
        if (showInstallments) ...[
          _BillSection(bills: bills),
          const SizedBox(height: AppSpacing.space8),
          _InstallmentSection(contracts: contracts),
          const SizedBox(height: AppSpacing.space8),
        ],
        if (transactionGroups.isEmpty)
          const _EmptyAccountTransactions()
        else
          for (final group in transactionGroups) ...[
            _AccountTransactionDaySection(group: group),
            const SizedBox(height: AppSpacing.space8),
          ],
      ],
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
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child:
            account.isCreditLiability
                ? _CreditInfoBlock(
                  account: account,
                  creditOverview: creditOverview,
                )
                : _AccountBalanceBlock(account: account),
      ),
    );
  }
}

class _CreditInfoBlock extends StatelessWidget {
  const _CreditInfoBlock({required this.account, required this.creditOverview});

  final AccountView account;
  final AccountCreditOverviewState creditOverview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopMetricRow(items: _creditDebtMetrics(account, creditOverview)),
        Divider(
          height: AppSpacing.space24,
          color: colors.outlineVariant.withValues(alpha: 0.7),
        ),
        _AccountMetricsBlock(
          items: _creditAccountMetrics(account, creditOverview),
        ),
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
  return account.isLiability ? '当前欠款' : '当前余额';
}

class _AccountMetricsBlock extends StatelessWidget {
  const _AccountMetricsBlock({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          Row(
            children: [
              Expanded(child: _InfoPair(item: items[i])),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child:
                    i + 1 < items.length
                        ? _InfoPair(item: items[i + 1])
                        : const SizedBox.shrink(),
              ),
            ],
          ),
          if (i + 2 < items.length) const SizedBox(height: AppSpacing.space12),
        ],
      ],
    );
  }
}

List<_InfoItem> _creditAccountMetrics(
  AccountView account,
  AccountCreditOverviewState creditOverview,
) {
  final loadedOverview =
      creditOverview is AccountCreditOverviewLoaded
          ? creditOverview.overview
          : null;
  final creditLimit =
      loadedOverview?.creditAccount.creditLimit ?? account.creditLimit;
  final availableCredit =
      loadedOverview?.availableCredit ??
      (creditLimit == null ? null : creditLimit - account.balance);
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

bool _hasUnattributedRepayments(AccountCreditOverviewState overview) {
  return overview is AccountCreditOverviewLoaded &&
      overview.overview.unattributedRepayments.isNotEmpty;
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Row(
      children: [
        Text(
          item.label,
          style: textStyles.formLabel.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: AppSpacing.space4),
        Flexible(
          child: Text(
            item.value,
            style: textStyles.formLabel.copyWith(color: colors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TopMetricRow extends StatelessWidget {
  const _TopMetricRow({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space4,
                ),
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            Expanded(child: _TopMetric(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  const _TopMetric({required this.item});

  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: styles.metricLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(item.value, style: styles.metricValue, maxLines: 1),
        ),
      ],
    );
  }
}

class _UnattributedRepaymentSection extends ConsumerWidget {
  const _UnattributedRepaymentSection({
    required this.accountId,
    required this.overview,
  });

  final String accountId;
  final AccountCreditOverviewState overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (overview) {
      AccountCreditOverviewLoaded(:final overview) => AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('账单外还款记录', style: context.appTextStyles.dateSectionTitle),
              const SizedBox(height: AppSpacing.space8),
              for (final repayment in overview.unattributedRepayments)
                _UnattributedRepaymentRow(
                  repayment: repayment,
                  onDelete:
                      () =>
                          _deleteUnattributedRepayment(context, ref, repayment),
                ),
            ],
          ),
        ),
      ),
      AccountCreditOverviewError(:final message) => AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space12),
          child: Text('账单外还款记录加载失败：$message'),
        ),
      ),
      AccountCreditOverviewLoading() => const AppSurface(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      AccountCreditOverviewNotApplicable() => const SizedBox.shrink(),
    };
  }

  Future<void> _deleteUnattributedRepayment(
    BuildContext context,
    WidgetRef ref,
    CreditRepaymentRecordReadModel repayment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除账单外还款'),
            content: const Text('将删除该还款记录；若有关联流水，也会一并冲销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(repaymentServiceProvider)
          .deleteRepayment(
            credit_command.DeleteCreditRepaymentCommand(
              repaymentId: repayment.id,
            ),
          );
      ref.invalidate(creditAccountOverviewProvider(accountId));
      ref.invalidate(transactionListProvider(accountId: accountId));
      ref.invalidate(accountsByIdProvider);
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _UnattributedRepaymentRow extends StatelessWidget {
  const _UnattributedRepaymentRow({
    required this.repayment,
    required this.onDelete,
  });

  final CreditRepaymentRecordReadModel repayment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
      child: Row(
        children: [
          Icon(
            RemixIcons.refund_2_line,
            size: AppSpacing.space18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              _repaymentTimeText(repayment.displayTime),
              style: styles.listSupporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            repayment.allocated.principal.format(),
            style: styles.amountList.copyWith(color: colors.onSurface),
          ),
          IconButton(
            tooltip: '删除',
            icon: Icon(
              RemixIcons.delete_bin_line,
              color: colors.onSurfaceVariant,
              size: AppSpacing.space20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

String _monthlyDay(int? day) {
  if (day == null) {
    return '-';
  }
  return '每月${day.toString().padLeft(2, '0')}日';
}

class _AccountActionBar extends StatelessWidget {
  const _AccountActionBar({required this.account});

  final AccountView account;

  @override
  Widget build(BuildContext context) {
    final isLiability = account.isLiability;
    const installmentSource = 'disbursement';

    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space8,
          vertical: AppSpacing.space6,
        ),
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: RemixIcons.add_circle_line,
                label: '记账',
                onTap: () => _openTransactionForm(context, account),
              ),
            ),
            if (isLiability) ...[
              const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.bank_card_line,
                  label: account.isCreditLiability ? '账单外还款' : '还款',
                  onTap:
                      () => context.push(
                        account.isCreditLiability
                            ? '/account/${account.id}/unattributed-repayment'
                            : '/account/${account.id}/repayment',
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.calendar_schedule_line,
                  label: account.isCredit ? '现金分期' : '分期',
                  onTap:
                      () => context.push(
                        '/account/${account.id}/installments/new'
                        '?source=$installmentSource',
                      ),
                ),
              ),
            ] else ...[
              const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.arrow_left_right_line,
                  label: '转账',
                  onTap:
                      () => context.push(
                        '/transaction/new?mode=transfer&fromAccountId=${account.id}',
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
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
            Icon(icon, color: colors.primary, size: AppSpacing.space20),
            const SizedBox(width: AppSpacing.space6),
            Flexible(
              child: Text(
                label,
                style: textStyles.formLabel,
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

class _AccountTransactionDaySection extends StatelessWidget {
  const _AccountTransactionDaySection({required this.group});

  final TransactionDayGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dividerColor = colors.outlineVariant.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            0,
            AppSpacing.space4,
            AppSpacing.space4,
          ),
          child: Row(
            children: [
              Text(
                '${group.date.month}月${group.date.day}日',
                style: context.appTextStyles.dateSectionTitle,
              ),
              const SizedBox(width: AppSpacing.space8),
              Text(
                weekdayLabel(group.date),
                style: context.appTextStyles.listSupporting,
              ),
            ],
          ),
        ),
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < group.rows.length; i++) ...[
                TransactionRow(
                  presentation: group.rows[i],
                  onTap:
                      () => context.push(
                        '/transaction/${group.rows[i].transactionId}',
                      ),
                  onQuickEdit:
                      () => context.push(
                        '/transaction/${group.rows[i].transactionId}/edit',
                      ),
                ),
                if (i < group.rows.length - 1)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    height: 1,
                    color: dividerColor,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyAccountTransactions extends StatelessWidget {
  const _EmptyAccountTransactions();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Row(
          children: [
            Icon(
              RemixIcons.file_list_3_line,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.space10),
            const Expanded(child: Text('暂无账户流水')),
          ],
        ),
      ),
    );
  }
}

class _BillSection extends StatefulWidget {
  const _BillSection({required this.bills});

  final AccountBillsState bills;

  @override
  State<_BillSection> createState() => _BillSectionState();
}

class _BillSectionState extends State<_BillSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              AppSpacing.space2,
              AppSpacing.space4,
              AppSpacing.space4,
            ),
            child: Row(
              children: [
                Text('账单', style: styles.dateSectionTitle),
                const Spacer(),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: _expanded ? 0.5 : 0,
                  child: Icon(
                    RemixIcons.arrow_down_s_line,
                    color: colors.onSurfaceVariant,
                    size: AppSpacing.space20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOut,
          child:
              _expanded
                  ? _buildBody(context, styles)
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AppTextStyles styles) {
    return switch (widget.bills) {
      AccountBillsLoaded(:final bills) =>
        bills.isEmpty
            ? AppSurface(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space20),
                child: Text(
                  '暂无账单',
                  style: styles.formLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
            : AppSurface(
              child: Column(
                children: [
                  for (var i = 0; i < bills.length; i++) ...[
                    _BillRow(bill: bills[i]),
                    if (i < bills.length - 1)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              ),
            ),
      AccountBillsError(:final message) => AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space12),
          child: Text('账单加载失败：$message'),
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

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final BillSummaryReadModel bill;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final pendingColor =
        bill.pendingPrincipal.minorUnits > 0 ? colors.error : colors.onSurface;
    return InkWell(
      onTap: () => context.push('/bills/${bill.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Icon(
              _billIcon(bill.status),
              color: _billColor(context, bill.status),
              size: AppSpacing.space20,
            ),
            const SizedBox(width: AppSpacing.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_billTitle(bill.period), style: styles.formLabel),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    _billSubtitle(bill),
                    style: styles.listSupporting.copyWith(
                      color:
                          bill.overdueItemCount > 0
                              ? colors.error
                              : colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bill.pendingPrincipal.format(),
                  style: styles.amountList.copyWith(color: pendingColor),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  _billStatusLabel(bill.status),
                  style: styles.listSupporting.copyWith(
                    color: _billColor(context, bill.status),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _billIcon(BillStatus status) {
  return switch (status) {
    BillStatus.open => RemixIcons.time_line,
    BillStatus.billed => RemixIcons.bill_line,
    BillStatus.settled => RemixIcons.checkbox_circle_line,
  };
}

Color _billColor(BuildContext context, BillStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    BillStatus.open => colors.primary,
    BillStatus.billed => colors.error,
    BillStatus.settled => colors.tertiary,
  };
}

String _billTitle(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月';
}

String _billSubtitle(BillSummaryReadModel bill) {
  final due =
      bill.dueDate == null ? '无到期日' : '到期 ${_formatBillDate(bill.dueDate!)}';
  if (bill.overdueItemCount > 0) {
    return '$due · ${bill.overdueItemCount} 条逾期';
  }
  return '$due · ${bill.itemCount} 条明细';
}

String _repaymentTimeText(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _billStatusLabel(BillStatus status) {
  return switch (status) {
    BillStatus.open => '累积中',
    BillStatus.billed => '已出账',
    BillStatus.settled => '已了结',
  };
}

String _formatBillDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _InstallmentSection extends StatefulWidget {
  const _InstallmentSection({required this.contracts});

  final AccountContractsState contracts;

  @override
  State<_InstallmentSection> createState() => _InstallmentSectionState();
}

class _InstallmentSectionState extends State<_InstallmentSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              AppSpacing.space2,
              AppSpacing.space4,
              AppSpacing.space4,
            ),
            child: Row(
              children: [
                Text('分期合同', style: styles.dateSectionTitle),
                const Spacer(),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: _expanded ? 0.5 : 0,
                  child: Icon(
                    RemixIcons.arrow_down_s_line,
                    color: colors.onSurfaceVariant,
                    size: AppSpacing.space20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOut,
          child:
              _expanded
                  ? _buildBody(context, styles)
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AppTextStyles styles) {
    return switch (widget.contracts) {
      AccountContractsLoaded(:final contracts) =>
        contracts.isEmpty
            ? AppSurface(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space20),
                child: Text(
                  '暂无分期合同',
                  style: styles.formLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
            : AppSurface(
              child: Column(
                children: [
                  for (var i = 0; i < contracts.length; i++) ...[
                    _ContractRow(contract: contracts[i]),
                    if (i < contracts.length - 1)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space16,
                        ),
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                  ],
                ],
              ),
            ),
      AccountContractsError(:final message) => AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space12),
          child: Text('合同加载失败：$message'),
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

class _ContractRow extends StatelessWidget {
  const _ContractRow({required this.contract});

  final InstallmentContract contract;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (contract.status) {
      InstallmentContractStatus.active => ('进行中', colors.primary),
      InstallmentContractStatus.settled => ('已结清', colors.tertiary),
    };
    final meta =
        '${_formatContractDate(contract.borrowingDate)} · '
        '${contract.totalPeriods} 期 · '
        '${_methodShort(contract.repaymentMethod)} · '
        '${_accrualLabel(contract.interestAccrualMethod)}';
    return InkWell(
      onTap: () => context.push('/installments/${contract.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contract.principal.format(), style: styles.formLabel),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    meta,
                    style: styles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space6,
                vertical: AppSpacing.space2,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusLabel,
                style: styles.listSupporting.copyWith(color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _methodShort(InstallmentRepaymentMethod method) {
  return switch (method) {
    InstallmentRepaymentMethod.equalInstallment => '等额本息',
    InstallmentRepaymentMethod.equalPrincipal => '等额本金',
    InstallmentRepaymentMethod.interestFirst => '先息后本',
    InstallmentRepaymentMethod.flatFee => '一次性手续费',
    InstallmentRepaymentMethod.custom => '自定义',
  };
}

String _accrualLabel(InterestAccrualMethod accrual) {
  return switch (accrual) {
    InterestAccrualMethod.daily => '按日计息',
    InterestAccrualMethod.monthly => '按月计息',
  };
}

String _formatContractDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

void _openTransactionForm(BuildContext context, AccountView account) {
  final query =
      Uri(
        path: '/transaction/new',
        queryParameters: {
          'fromAccountId': account.id.toString(),
          'toAccountId': account.id.toString(),
        },
      ).toString();
  context.push(query);
}
