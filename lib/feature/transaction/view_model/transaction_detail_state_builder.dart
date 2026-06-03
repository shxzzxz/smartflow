import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../widget/business/account_endpoint_view.dart';
import '../../../widget/business/account_lookup.dart';
import '../presentation/transaction_detail_presentation.dart';
import 'transaction_detail_state.dart';

TransactionDetailUiState buildTransactionDetailLoadedState({
  required String transactionId,
  required TransactionDetail detail,
  required AccountLookup accountLookup,
}) {
  final behavior = _behaviorConfigFor(detail.transaction);
  return TransactionDetailUiState.loaded(
    transactionId: transactionId,
    detail: detail,
    behavior: behavior,
    hero: transactionDetailHero(detail: detail, accountLookup: accountLookup),
    occurredAtText: formatTransactionDetailDateTime(
      detail.transaction.occurredAt,
    ),
    createdAtText: formatTransactionDetailDateTime(detail.createdAt),
    noteText: detail.transaction.note,
    accountRows: _accountRows(detail, accountLookup, behavior),
    refund: _refundState(detail),
    reimbursement: _reimbursementState(detail),
    historyItems: historySheetItems(detail.history),
    showExcludeStats: canShowExcludeStats(detail.transaction),
    showExcludeBudget: canShowExcludeBudget(detail.transaction),
    excludeStats: detail.transaction.isExcludedFromStats,
    excludeBudget: detail.transaction.isExcludedFromBudget,
    actionButtons: _actionButtons(detail, behavior),
    submitting: false,
  );
}

bool canShowExcludeStats(Transaction transaction) {
  return isPlainTransaction(transaction) &&
      (transaction.businessPurpose == BusinessPurpose.dailyExpense ||
          transaction.businessPurpose == BusinessPurpose.dailyIncome);
}

bool canShowExcludeBudget(Transaction transaction) {
  return isPlainTransaction(transaction) &&
      transaction.businessPurpose == BusinessPurpose.dailyExpense;
}

bool isPlainTransaction(Transaction transaction) {
  return transaction.ownership == null;
}

List<DetailAccountRow> _accountRows(
  TransactionDetail detail,
  AccountLookup accountLookup,
  DetailBehaviorConfig behavior,
) {
  final purpose = detail.transaction.businessPurpose;
  final entries = detail.entries;
  final settlementEntries =
      entries
          .where((entry) => accountLookup.isSettlement(entry.accountId))
          .toList();

  DetailAccountRow info(String label, Entry entry, {AccountUsage? editUsage}) {
    return DetailAccountRow(
      label: label,
      accountId: entry.accountId,
      endpoint: accountLookup.endpointOf(entry.accountId),
      editUsage: editUsage,
      permission: _accountEditPermission(editUsage, behavior),
    );
  }

  DetailAccountRow placeholder(String label, {AccountUsage? editUsage}) {
    return DetailAccountRow(
      label: label,
      accountId: '',
      endpoint: const AccountEndpoint(label: '—', iconKey: null),
      editUsage: editUsage,
      permission: _accountEditPermission(editUsage, behavior),
    );
  }

  switch (purpose) {
    case BusinessPurpose.transfer:
      if (settlementEntries.isEmpty) {
        return [placeholder('转出账户'), placeholder('转入账户')];
      }
      final from = settlementEntries.firstWhere(
        (entry) => entry.direction == EntryDirection.credit,
        orElse: () => settlementEntries.first,
      );
      final to = settlementEntries.firstWhere(
        (entry) => entry.direction == EntryDirection.debit,
        orElse: () => settlementEntries.first,
      );
      return [info('转出账户', from), info('转入账户', to)];
    case BusinessPurpose.dailyIncome:
    case BusinessPurpose.refund:
    case BusinessPurpose.reimbursementReceipt:
    case BusinessPurpose.reimbursementClose:
    case BusinessPurpose.borrowing:
      final editUsage =
          purpose == BusinessPurpose.dailyIncome ||
                  purpose == BusinessPurpose.borrowing
              ? AccountUsage.settlement
              : null;
      if (settlementEntries.isEmpty) {
        return [placeholder('收支账户', editUsage: editUsage)];
      }
      final inAccount = settlementEntries.firstWhere(
        (entry) => entry.direction == EntryDirection.debit,
        orElse: () => settlementEntries.first,
      );
      return [info('收支账户', inAccount, editUsage: editUsage)];
    case BusinessPurpose.dailyExpense:
    case BusinessPurpose.debtRepayment:
      final label = purpose == BusinessPurpose.debtRepayment ? '还款账户' : '收支账户';
      if (settlementEntries.isEmpty) {
        return [placeholder(label, editUsage: AccountUsage.settlement)];
      }
      final outAccount = settlementEntries.firstWhere(
        (entry) => entry.direction == EntryDirection.credit,
        orElse: () => settlementEntries.first,
      );
      return [info(label, outAccount, editUsage: AccountUsage.settlement)];
    case BusinessPurpose.reimbursementAdvance:
      if (settlementEntries.isEmpty) {
        return [
          placeholder('收支账户', editUsage: AccountUsage.settlement),
          placeholder('报销账户', editUsage: AccountUsage.reimbursement),
        ];
      }
      final receivable = settlementEntries.firstWhere(
        (entry) =>
            entry.direction == EntryDirection.debit &&
            accountLookup.typeOf(entry.accountId) == AccountType.asset,
        orElse: () => settlementEntries.first,
      );
      final paidFrom = settlementEntries.firstWhere(
        (entry) => entry.direction == EntryDirection.credit,
        orElse: () => settlementEntries.first,
      );
      return [
        info('收支账户', paidFrom, editUsage: AccountUsage.settlement),
        info('报销账户', receivable, editUsage: AccountUsage.reimbursement),
      ];
    case BusinessPurpose.openingBalance:
    case BusinessPurpose.balanceAdjustment:
      if (settlementEntries.isEmpty) {
        return [placeholder('账户')];
      }
      return [info('账户', settlementEntries.first)];
  }
}

DetailRefund? _refundState(TransactionDetail detail) {
  if (detail.transaction.businessPurpose != BusinessPurpose.dailyExpense) {
    return null;
  }
  final refunded = detail.refundedTotal;
  final hasRefund = refunded != null && refunded.minorUnits > 0;
  return DetailRefund(
    hasRefund: hasRefund,
    refundedTotal: refunded,
    items: refundSheetItems(detail.children),
  );
}

DetailReimbursement? _reimbursementState(TransactionDetail detail) {
  if (detail.transaction.businessPurpose !=
      BusinessPurpose.reimbursementAdvance) {
    return null;
  }
  final summary = detail.reimbursementSummary;
  final hasActivity = summary != null && summary.receivedAmount.minorUnits > 0;
  final summaryText =
      summary == null
          ? '未报销'
          : summary.isClosed
          ? '已结束 · 实收 ${summary.receivedAmount.format()}'
          : hasActivity
          ? '已收 ${summary.receivedAmount.format()} / 应收 ${summary.advanceAmount.format()}'
          : '未报销';
  return DetailReimbursement(
    summaryText: summaryText,
    hasActivity: hasActivity,
    isClosed: summary?.isClosed ?? false,
    outstanding: summary?.outstanding,
    items: reimbursementSheetItems(detail.children),
  );
}

List<DetailActionButton> _actionButtons(
  TransactionDetail detail,
  DetailBehaviorConfig behavior,
) {
  final transaction = detail.transaction;
  final result = <DetailActionButton>[];
  switch (transaction.businessPurpose) {
    case BusinessPurpose.dailyExpense:
      result.add(
        DetailActionButton(
          kind: DetailActionKind.refund,
          label: '退款',
          primary: false,
          enabled: true,
          route: '/transaction/${transaction.id}/refund',
        ),
      );
    case BusinessPurpose.reimbursementAdvance:
      final closed = detail.reimbursementSummary?.isClosed ?? false;
      if (!closed) {
        result.add(
          DetailActionButton(
            kind: DetailActionKind.refund,
            label: '退款',
            primary: false,
            enabled: true,
            route: '/transaction/${transaction.id}/refund',
          ),
        );
      }
      result.add(
        DetailActionButton(
          kind: DetailActionKind.reimbursement,
          label: '报销',
          primary: false,
          enabled: !closed,
          deniedReason: closed ? '报销已结束' : null,
        ),
      );
    default:
      break;
  }

  result.add(
    DetailActionButton(
      kind: DetailActionKind.edit,
      label: '编辑',
      primary: true,
      enabled: behavior.editRoute != null,
      route: behavior.editRoute,
    ),
  );
  return result;
}

DetailEditPermission _accountEditPermission(
  AccountUsage? editUsage,
  DetailBehaviorConfig behavior,
) {
  return switch (editUsage) {
    null => const DetailEditPermission.allowed(),
    AccountUsage.settlement => behavior.canEditSettlementAccount,
    AccountUsage.reimbursement => const DetailEditPermission.allowed(),
    AccountUsage.fund ||
    AccountUsage.credit ||
    AccountUsage.loan ||
    AccountUsage.repaymentTarget ||
    AccountUsage.repaymentSource ||
    AccountUsage.borrowingLiability => const DetailEditPermission.denied(
      reason: '当前账户用途不能在交易详情页编辑',
    ),
  };
}

DetailBehaviorConfig _behaviorConfigFor(Transaction transaction) {
  final ownership = transaction.ownership;
  if (ownership == null) {
    return DetailBehaviorConfig(
      editRoute:
          transaction.businessPurpose == BusinessPurpose.debtRepayment
              ? '/transaction/${transaction.id}/repayment/edit'
              : '/transaction/${transaction.id}/edit',
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: const DetailEditPermission.denied(
        reason: '结算账户变更需要通过更正交易完成',
      ),
    );
  }

  if (ownership.ownerType == installmentOwnerType &&
      ownership.ownerId != null) {
    final role = InstallmentOwnerRole.fromWire(ownership.ownerRole);
    if (role != null) {
      return DetailBehaviorConfig(
        bannerText: switch (role) {
          InstallmentOwnerRole.disbursement => '此为分期合同放款，金额、账户、日期等需在合同详情页内调整',
          InstallmentOwnerRole.scheduledRepayment => '此为分期期次还款，撤销请在合同详情页操作',
          InstallmentOwnerRole.extraPrincipal => '此为分期提前还本，撤销请在合同详情页操作',
          InstallmentOwnerRole.earlySettlement => '此为分期提前结清，撤销请在合同详情页操作',
        },
        editRoute: '/installments/${ownership.ownerId}',
        canEditOccurredAt: const DetailEditPermission.allowed(),
        canEditNote: const DetailEditPermission.allowed(),
        canEditSettlementAccount: const DetailEditPermission.allowed(),
      );
    }
  }

  return DetailBehaviorConfig(
    bannerText: '该交易属于当前版本未识别的业务来源：${ownership.ownerType}',
    canEditOccurredAt: const DetailEditPermission.denied(
      reason: '该交易属于当前版本未识别的业务来源，仅允许修改备注',
    ),
    canEditNote: const DetailEditPermission.allowed(),
    canEditSettlementAccount: const DetailEditPermission.denied(
      reason: '该交易属于当前版本未识别的业务来源，仅允许修改备注',
    ),
  );
}
