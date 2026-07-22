import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/widget/business/account/account_endpoint.dart';

import '../presentation/transaction_detail_presentation.dart';
import 'transaction_detail_state.dart';

TransactionDetailUiState buildTransactionDetailLoadedState({
  required String transactionId,
  required TransactionDetail detail,
  required AccountLookup accountLookup,
}) {
  final behavior = _behaviorConfigFor(detail);
  return TransactionDetailUiState.loaded(
    transactionId: transactionId,
    detail: detail,
    behavior: behavior,
    hero: transactionDetailHero(detail: detail, accountLookup: accountLookup),
    occurredAtText: formatTransactionDetailDateTime(
      detail.transaction.occurredAt,
    ),
    postedAtText: formatTransactionDetailDateTime(detail.transaction.postedAt),
    createdAtText: formatTransactionDetailDateTime(detail.createdAt),
    noteText: detail.transaction.note,
    accountRows: _accountRows(detail, accountLookup, behavior),
    refund: _refundState(detail),
    reimbursement: _reimbursementState(detail),
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

  DetailAccountRow info(
    String label,
    Entry entry, {
    AccountSelectionPurpose? editPurpose,
  }) {
    return DetailAccountRow(
      label: label,
      accountId: entry.accountId,
      endpoint: accountLookup.endpointOf(entry.accountId),
      editPurpose: editPurpose,
      permission: _accountEditPermission(editPurpose, behavior),
    );
  }

  DetailAccountRow placeholder(
    String label, {
    AccountSelectionPurpose? editPurpose,
  }) {
    return DetailAccountRow(
      label: label,
      accountId: '',
      endpoint: const AccountEndpoint(label: '—', iconKey: null),
      editPurpose: editPurpose,
      permission: _accountEditPermission(editPurpose, behavior),
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
      final editPurpose =
          purpose == BusinessPurpose.dailyIncome ||
                  purpose == BusinessPurpose.borrowing
              ? purpose == BusinessPurpose.borrowing
                  ? AccountSelectionPurpose.fund
                  : AccountSelectionPurpose.settlement
              : null;
      if (settlementEntries.isEmpty) {
        return [placeholder('收支账户', editPurpose: editPurpose)];
      }
      final inAccount = settlementEntries.firstWhere(
        (entry) => entry.direction == EntryDirection.debit,
        orElse: () => settlementEntries.first,
      );
      return [info('收支账户', inAccount, editPurpose: editPurpose)];
    case BusinessPurpose.dailyExpense:
    case BusinessPurpose.debtRepayment:
      final label = purpose == BusinessPurpose.debtRepayment ? '还款账户' : '收支账户';
      final editPurpose =
          purpose == BusinessPurpose.debtRepayment
              ? AccountSelectionPurpose.repaymentSource
              : AccountSelectionPurpose.settlement;
      if (settlementEntries.isEmpty) {
        return [placeholder(label, editPurpose: editPurpose)];
      }
      final outAccount = settlementEntries.firstWhere(
        (entry) => entry.direction == EntryDirection.credit,
        orElse: () => settlementEntries.first,
      );
      return [info(label, outAccount, editPurpose: editPurpose)];
    case BusinessPurpose.reimbursementAdvance:
      if (settlementEntries.isEmpty) {
        return [
          placeholder('收支账户', editPurpose: AccountSelectionPurpose.settlement),
          placeholder(
            '报销账户',
            editPurpose: AccountSelectionPurpose.reimbursementReceivable,
          ),
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
        info('收支账户', paidFrom, editPurpose: AccountSelectionPurpose.settlement),
        info(
          '报销账户',
          receivable,
          editPurpose: AccountSelectionPurpose.reimbursementReceivable,
        ),
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
  final editLocked = _isEarlierReimbursementChildLocked(detail);
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
      enabled: behavior.editRoute != null && !editLocked,
      route: behavior.editRoute,
      deniedReason: editLocked ? _reimbursementClosedEditReason : null,
    ),
  );
  return result;
}

DetailEditPermission _accountEditPermission(
  AccountSelectionPurpose? editPurpose,
  DetailBehaviorConfig behavior,
) {
  return switch (editPurpose) {
    null => const DetailEditPermission.allowed(),
    AccountSelectionPurpose.settlement ||
    AccountSelectionPurpose.fund ||
    AccountSelectionPurpose
        .repaymentSource => behavior.canEditSettlementAccount,
    AccountSelectionPurpose.reimbursementReceivable =>
      const DetailEditPermission.allowed(),
    AccountSelectionPurpose.repaymentTarget ||
    AccountSelectionPurpose.borrowingLiability =>
      const DetailEditPermission.denied(reason: '当前账户用途不能在交易详情页编辑'),
  };
}

DetailBehaviorConfig _behaviorConfigFor(TransactionDetail detail) {
  final transaction = detail.transaction;
  const postedAtPermission = DetailEditPermission.allowed();
  final editLocked = _isEarlierReimbursementChildLocked(detail);
  if (transaction.businessPurpose == BusinessPurpose.refund ||
      transaction.businessPurpose == BusinessPurpose.reimbursementReceipt ||
      transaction.businessPurpose == BusinessPurpose.reimbursementClose) {
    final editPermission =
        editLocked
            ? const DetailEditPermission.denied(
              reason: _reimbursementClosedEditReason,
            )
            : const DetailEditPermission.allowed();
    return DetailBehaviorConfig(
      editRoute: switch (transaction.businessPurpose) {
        BusinessPurpose.refund => '/transaction/${transaction.id}/refund/edit',
        BusinessPurpose.reimbursementReceipt ||
        BusinessPurpose.reimbursementClose =>
          '/transaction/${transaction.id}/reimbursement/edit',
        _ => null,
      },
      canEditOccurredAt: editPermission,
      canEditPostedAt: editPermission,
      canEditNote: editPermission,
      canEditSettlementAccount: editPermission,
    );
  }

  final ownership = transaction.ownership;
  if (ownership == null) {
    return DetailBehaviorConfig(
      editRoute: switch (transaction.businessPurpose) {
        BusinessPurpose.dailyExpense ||
        BusinessPurpose.dailyIncome ||
        BusinessPurpose.transfer ||
        BusinessPurpose.reimbursementAdvance ||
        BusinessPurpose.borrowing => '/transaction/${transaction.id}/edit',
        BusinessPurpose.debtRepayment =>
          '/transaction/${transaction.id}/repayment/edit',
        BusinessPurpose.openingBalance ||
        BusinessPurpose.balanceAdjustment => null,
        BusinessPurpose.refund ||
        BusinessPurpose.reimbursementReceipt ||
        BusinessPurpose.reimbursementClose => null,
      },
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditPostedAt: postedAtPermission,
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: const DetailEditPermission.allowed(),
    );
  }

  if (ownership.ownerType == installmentOwnerType &&
      ownership.ownerId != null) {
    final role = InstallmentOwnerRole.fromWire(ownership.ownerRole);
    if (role != null) {
      return DetailBehaviorConfig(
        bannerText: '此为分期合同放款，金额、账户、日期等需在合同详情页内调整',
        editRoute: '/installments/${ownership.ownerId}',
        canEditOccurredAt: const DetailEditPermission.allowed(),
        canEditPostedAt: postedAtPermission,
        canEditNote: const DetailEditPermission.allowed(),
        canEditSettlementAccount: const DetailEditPermission.allowed(),
      );
    }
  }

  if (ownership.ownerType == creditRepaymentOwnerType &&
      ownership.ownerId != null) {
    final repaymentType = _repaymentTypeFromOwnerRole(ownership.ownerRole);
    if (repaymentType != null) {
      return DetailBehaviorConfig(
        bannerText: '此为信贷${repaymentType.label}交易，金额调整请在信贷页面处理',
        editRoute:
            repaymentType == RepaymentType.bill
                ? '/repayments/${ownership.ownerId}/edit'
                    '?transactionId=${transaction.id}'
                : null,
        canEditOccurredAt: const DetailEditPermission.allowed(),
        canEditPostedAt: postedAtPermission,
        canEditNote: const DetailEditPermission.allowed(),
        canEditSettlementAccount: const DetailEditPermission.allowed(),
      );
    }
  }

  return DetailBehaviorConfig(
    bannerText:
        '该交易属于当前版本未识别的业务来源：${ownership.ownerType}；'
        '仅允许修改备注和入账时间',
    canEditOccurredAt: const DetailEditPermission.denied(
      reason: '该交易属于当前版本未识别的业务来源，仅允许修改备注和入账时间',
    ),
    canEditPostedAt: postedAtPermission,
    canEditNote: const DetailEditPermission.allowed(),
    canEditSettlementAccount: const DetailEditPermission.denied(
      reason: '该交易属于当前版本未识别的业务来源，仅允许修改备注和入账时间',
    ),
  );
}

bool _isEarlierReimbursementChildLocked(TransactionDetail detail) {
  final purpose = detail.transaction.businessPurpose;
  if (purpose != BusinessPurpose.refund &&
      purpose != BusinessPurpose.reimbursementReceipt) {
    return false;
  }
  return detail.reimbursementSummary?.isClosed ?? false;
}

const String _reimbursementClosedEditReason = '报销已结束，请先删除结束报销';

RepaymentType? _repaymentTypeFromOwnerRole(String? ownerRole) {
  if (ownerRole == null) return null;
  try {
    return RepaymentType.fromCode(ownerRole);
  } on ArgumentError {
    return null;
  }
}
