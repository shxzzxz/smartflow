import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_month_picker.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/account_credit_actions.dart';
import '../view_model/account_detail_view_model.dart';
import '../view_model/account_view.dart';

class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDetailViewModelProvider(accountId));
    final loadedAccount = state is AccountDetailLoaded ? state.account : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户概览'),
        actions: [
          if (loadedAccount != null && !loadedAccount.isArchived)
            if (loadedAccount.isCreditLiability)
              IconButton(
                onPressed: () => _generateHistoricalBill(context, ref),
                icon: const Icon(RemixIcons.calendar_event_line),
                tooltip: '生成历史账单',
              ),
          if (loadedAccount != null && !loadedAccount.isArchived)
            IconButton(
              onPressed: () => context.push('/account/$accountId/edit'),
              icon: const Icon(RemixIcons.edit_line),
              tooltip: '编辑账户',
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
            onDeleteUnattributedRepayment:
                (repayment) =>
                    _deleteUnattributedRepayment(context, ref, repayment),
          ),
        AccountDetailNotFound() => const Center(child: Text('账户不存在')),
        AccountDetailError(:final message) => Center(child: Text(message)),
        AccountDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      },
    );
  }

  Future<void> _generateHistoricalBill(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selected = await showAppMonthPicker(
      context: context,
      initialMonth: DateTime.now(),
      lastYear: DateTime.now().year,
      title: '选择账单月份',
    );
    if (selected == null) return;
    final outcome = await ref
        .read(accountCreditActionsProvider(accountId).notifier)
        .generateHistoricalBill(selected);
    if (!context.mounted) return;
    _showAccountActionOutcome(context, outcome, successMessage: '账单已生成');
  }

  Future<void> _deleteUnattributedRepayment(
    BuildContext context,
    WidgetRef ref,
    CreditRepaymentRecordReadModel repayment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('删除还款记录'),
            content: const Text('删除后将回退相关信贷状态。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final outcome = await ref
        .read(accountCreditActionsProvider(accountId).notifier)
        .deleteUnattributedRepayment(repayment.id);
    if (!context.mounted) return;
    _showAccountActionOutcome(context, outcome, successMessage: '还款记录已删除');
  }
}

class _AccountDetailContent extends StatelessWidget {
  const _AccountDetailContent({
    required this.account,
    required this.transactionGroups,
    required this.contracts,
    required this.bills,
    required this.creditOverview,
    required this.onDeleteUnattributedRepayment,
  });

  final AccountView account;
  final List<TransactionDayGroup> transactionGroups;
  final AccountContractsState contracts;
  final AccountBillsState bills;
  final AccountCreditOverviewState creditOverview;
  final ValueChanged<CreditRepaymentRecordReadModel>
  onDeleteUnattributedRepayment;

  @override
  Widget build(BuildContext context) {
    final showInstallments = account.isLiability;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space12,
        AppSpacing.space8,
        AppSpacing.space12,
        AppSpacing.space20,
      ),
      children: [
        _AccountInfoSection(account: account, creditOverview: creditOverview),
        const SizedBox(height: AppSpacing.space12),
        _AccountActionBar(account: account),
        if (showInstallments) ...[
          const SizedBox(height: AppSpacing.space20),
          _BillSection(bills: bills),
          if (creditOverview case AccountCreditOverviewLoaded(
            :final overview,
          ) when overview.unattributedRepayments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space20),
            _UnattributedRepaymentSection(
              repayments: overview.unattributedRepayments,
              onDelete: onDeleteUnattributedRepayment,
            ),
          ],
          const SizedBox(height: AppSpacing.space20),
          _InstallmentSection(contracts: contracts),
          const SizedBox(height: AppSpacing.space20),
        ],
        _AccountTransactionsOverviewSection(
          accountId: account.id,
          transactionGroups: transactionGroups,
        ),
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
  return account.isLiability ? '当前欠款' : '当前余额';
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
      label: '合同未来欠款',
      value: loadedOverview?.buckets.futureContractDebt.format() ?? '-',
    ),
    _InfoItem(
      label: '未归属欠款',
      value: loadedOverview?.buckets.unattributedDebt.format() ?? '-',
    ),
  ];
}

class _UnattributedRepaymentSection extends StatelessWidget {
  const _UnattributedRepaymentSection({
    required this.repayments,
    required this.onDelete,
  });

  final List<CreditRepaymentRecordReadModel> repayments;
  final ValueChanged<CreditRepaymentRecordReadModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('未归属还款记录', style: styles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < repayments.length; i++) ...[
                ListTile(
                  title: Text(
                    repayments[i].allocated.cashPaid.format(),
                    style: styles.listTitle,
                  ),
                  subtitle: Text(
                    '${repayments[i].timeSource == CreditRepaymentTimeSource.transaction ? '还款日' : '记录于'} '
                    '${_dateText(repayments[i].displayTime)}',
                    style: styles.listSupporting,
                  ),
                  trailing: IconButton(
                    tooltip: '删除',
                    icon: Icon(
                      RemixIcons.delete_bin_line,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: () => onDelete(repayments[i]),
                  ),
                ),
                if (i < repayments.length - 1) _ListDivider(color: colors),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _dateText(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

void _showAccountActionOutcome(
  BuildContext context,
  UiActionOutcome<void> outcome, {
  required String successMessage,
}) {
  final message = switch (outcome) {
    UiActionSuccess<void>() => successMessage,
    UiActionFailure<void>(:final error) => error.message,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
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
                  label: account.isCreditLiability ? '未归属还款' : '还款',
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
                  label: account.isCredit ? '现金分期' : '贷款分期',
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
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
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
        ),
        child,
      ],
    );
  }
}

class _AccountTransactionsOverviewSection extends StatelessWidget {
  const _AccountTransactionsOverviewSection({
    required this.accountId,
    required this.transactionGroups,
  });

  final String accountId;
  final List<TransactionDayGroup> transactionGroups;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final group in transactionGroups)
        for (final row in group.rows) row,
    ];
    return _OverviewSection(
      title: '账户交易',
      onViewAll: () => context.push('/account/$accountId/transactions'),
      child:
          rows.isEmpty
              ? const _EmptyAccountTransactions()
              : AppSurface(
                child: Column(
                  children: [
                    for (var i = 0; i < rows.take(5).length; i++) ...[
                      TransactionRow(
                        presentation: rows[i],
                        onTap:
                            () => context.push(
                              '/transaction/${rows[i].transactionId}',
                            ),
                        onQuickEdit:
                            () => context.push(
                              '/transaction/${rows[i].transactionId}/edit',
                            ),
                      ),
                      if (i < rows.take(5).length - 1)
                        _ListDivider(color: Theme.of(context).colorScheme),
                    ],
                  ],
                ),
              ),
    );
  }
}

class _ListDivider extends StatelessWidget {
  const _ListDivider({required this.color});

  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
      height: 1,
      color: color.outlineVariant.withValues(alpha: 0.45),
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
            const Expanded(child: Text('暂无账户交易')),
          ],
        ),
      ),
    );
  }
}

class _BillSection extends StatelessWidget {
  const _BillSection({required this.bills});

  final AccountBillsState bills;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return _OverviewSection(title: '账单', child: _buildBody(context, styles));
  }

  Widget _buildBody(BuildContext context, AppTextStyles styles) {
    return switch (bills) {
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
                      _ListDivider(color: Theme.of(context).colorScheme),
                  ],
                ],
              ),
            ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_billTitle(bill.period), style: styles.listTitle),
                  const SizedBox(height: AppSpacing.space4),
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
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              color: colors.onSurfaceVariant,
              size: AppSpacing.space18,
            ),
          ],
        ),
      ),
    );
  }
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

class _InstallmentSection extends StatelessWidget {
  const _InstallmentSection({required this.contracts});

  final AccountContractsState contracts;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return _OverviewSection(title: '分期合同', child: _buildBody(context, styles));
  }

  Widget _buildBody(BuildContext context, AppTextStyles styles) {
    return switch (contracts) {
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
                      _ListDivider(color: Theme.of(context).colorScheme),
                  ],
                ],
              ),
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

class _ContractRow extends StatelessWidget {
  const _ContractRow({required this.contract});

  final InstallmentContractReadModel contract;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (contract.status) {
      InstallmentContractStatus.active => ('进行中', colors.primary),
      InstallmentContractStatus.settled => ('已结清', colors.tertiary),
    };
    final progress =
        contract.status == InstallmentContractStatus.settled
            ? '${contract.totalPeriods}/${contract.totalPeriods} 期'
            : '${contract.totalPeriods} 期';
    final meta = '$progress · ${_methodShort(contract.repaymentMethod)}';
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
                  Text(contract.principal.format(), style: styles.listTitle),
                  const SizedBox(height: AppSpacing.space4),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space6,
                    vertical: AppSpacing.space2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                  child: Text(
                    statusLabel,
                    style: styles.badgeLabel.copyWith(color: statusColor),
                  ),
                ),
                const SizedBox(width: AppSpacing.space4),
                Icon(
                  RemixIcons.arrow_right_s_line,
                  color: colors.onSurfaceVariant,
                  size: AppSpacing.space18,
                ),
              ],
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
