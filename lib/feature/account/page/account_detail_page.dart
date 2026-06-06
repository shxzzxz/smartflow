import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/transaction_list_presentation.dart';
import '../../../widget/business/transaction_row.dart';
import '../view_model/account_detail_view_model.dart';

class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDetailViewModelProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户详情'),
        actions: [
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
        ) =>
          _AccountDetailContent(
            account: account,
            transactionGroups: transactionGroups,
            contracts: contracts,
          ),
        AccountDetailNotFound() => const Center(child: Text('账户不存在')),
        AccountDetailError(:final message) => Center(child: Text(message)),
        AccountDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      },
    );
  }
}

class _AccountDetailContent extends StatelessWidget {
  const _AccountDetailContent({
    required this.account,
    required this.transactionGroups,
    required this.contracts,
  });

  final Account account;
  final List<TransactionDayGroup> transactionGroups;
  final AccountContractsState contracts;

  @override
  Widget build(BuildContext context) {
    final showInstallments = account.type == AccountType.liability;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space10,
        AppSpacing.space6,
        AppSpacing.space10,
        AppSpacing.space16,
      ),
      children: [
        _AccountInfoSection(account: account),
        const SizedBox(height: AppSpacing.space8),
        _AccountActionBar(account: account),
        const SizedBox(height: AppSpacing.space8),
        if (showInstallments) ...[
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
  const _AccountInfoSection({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rightItems = _rightInfoItems(account);
    final balanceBlock = _AccountBalanceBlock(account: account);
    final metricsBlock = _AccountMetricsBlock(items: rightItems);

    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (rightItems.isEmpty) {
              return balanceBlock;
            }

            if (constraints.maxWidth < 380) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  balanceBlock,
                  Divider(
                    height: AppSpacing.space20,
                    color: colors.outlineVariant.withValues(alpha: 0.7),
                  ),
                  metricsBlock,
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 4, child: balanceBlock),
                  const SizedBox(width: AppSpacing.space12),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(flex: 9, child: metricsBlock),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountBalanceBlock extends StatelessWidget {
  const _AccountBalanceBlock({required this.account});

  final Account account;

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

class _AccountMetricsBlock extends StatelessWidget {
  const _AccountMetricsBlock({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(child: _InfoPair(item: items[0])),
            const SizedBox(width: AppSpacing.space12),
            Expanded(child: _InfoPair(item: items[1])),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        Row(
          children: [
            Expanded(child: _InfoPair(item: items[2])),
            const SizedBox(width: AppSpacing.space12),
            Expanded(child: _InfoPair(item: items[3])),
          ],
        ),
      ],
    );
  }
}

String _balanceTitle(Account account) {
  return account.type == AccountType.liability ? '当前欠款' : '当前余额';
}

List<_InfoItem> _rightInfoItems(Account account) {
  if (account.type != AccountType.liability) {
    return const [];
  }
  final creditLimit = account.creditLimit;
  return [
    _InfoItem(label: '信用额度', value: creditLimit?.format() ?? '-'),
    _InfoItem(
      label: '剩余额度',
      value:
          creditLimit == null ? '-' : (creditLimit - account.balance).format(),
    ),
    _InfoItem(label: '出账日', value: _monthlyDay(account.billingDay)),
    _InfoItem(label: '还款日', value: _monthlyDay(account.repaymentDay)),
  ];
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

String _monthlyDay(int? day) {
  if (day == null) {
    return '-';
  }
  return '每月${day.toString().padLeft(2, '0')}日';
}

class _AccountActionBar extends StatelessWidget {
  const _AccountActionBar({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final isLiability = account.type == AccountType.liability;
    final isLoan = account.subtype == AccountSubtype.loan;
    final installmentSource = isLoan ? 'disbursement' : 'bill';

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
                  label: '还款',
                  onTap: () => context.push('/account/${account.id}/repayment'),
                ),
              ),
              const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.calendar_schedule_line,
                  label: '分期',
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
      InstallmentContractStatus.closed => ('已关闭', colors.outline),
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

void _openTransactionForm(BuildContext context, Account account) {
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
