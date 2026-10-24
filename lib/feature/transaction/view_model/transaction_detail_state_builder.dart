import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/widget/business/account/account_endpoint.dart';

import '../presentation/transaction_detail_presentation.dart';
import 'transaction_detail_state.dart';

TransactionDetailUiState buildTransactionDetailLoadedState({
  required String transactionId,
  required TransactionReadModel detail,
  TransactionReadModel? parentDetail,
  required AccountLookup accountLookup,
}) {
  final behavior = _behaviorConfigFor(
    detail,
  ).copyWith(deleteMessage: _transactionDetailDeleteMessage(detail));
  return TransactionDetailUiState.loaded(
    transactionId: transactionId,
    detail: detail,
    behavior: behavior,
    hero: transactionDetailHero(detail: detail, accountLookup: accountLookup),
    allocationBreakdowns: transactionDetailAllocationBreakdowns(
      detail: detail,
      accountLookup: accountLookup,
    ),
    occurredAtText: formatTransactionDetailDateTime(detail.occurredAt),
    postedAtText: formatTransactionDetailDateTime(detail.postedAt),
    createdAtText: formatTransactionDetailDateTime(
      detail.createdAt ?? detail.occurredAt,
    ),
    noteText: detail.note,
    accountRows: _accountRows(detail, accountLookup, behavior),
    refund: _refundState(detail),
    advance: _advanceState(detail),
    canEditReportingFlags: detail.parentTransactionId == null,
    showExcludeStats: true,
    showExcludeBudget: true,
    excludeStats:
        parentDetail?.isExcludedFromStats ?? detail.isExcludedFromStats,
    excludeBudget:
        parentDetail?.isExcludedFromBudget ?? detail.isExcludedFromBudget,
    actionButtons: _actionButtons(detail, parentDetail, behavior),
    submitting: false,
  );
}

List<DetailAccountRow> _accountRows(
  TransactionReadModel detail,
  AccountLookup accountLookup,
  DetailBehaviorConfig behavior,
) {
  final purpose = detail.businessPurpose;

  DetailAccountRow info(
    String label,
    TransactionLine line, {
    AccountSelectionPurpose? editPurpose,
  }) {
    return DetailAccountRow(
      label: label,
      accountId: line.accountId!,
      endpoint: accountLookup.endpointOf(line.accountId!),
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

  List<DetailAccountRow> counterpartRows(String label, TransactionRole role) {
    final lines = detail.linesOf(role).toList();
    return lines.isEmpty
        ? [placeholder(label)]
        : [for (final line in lines) info(label, line)];
  }

  switch (purpose) {
    case BusinessPurpose.transfer:
      final out = detail.linesOf(TransactionRole.settlementOut).toList();
      final incoming = detail.linesOf(TransactionRole.settlementIn).toList();
      return [
        if (out.isEmpty)
          placeholder('转出账户', editPurpose: AccountSelectionPurpose.settlement)
        else
          for (final line in out)
            info('转出账户', line, editPurpose: AccountSelectionPurpose.settlement),
        if (incoming.isEmpty)
          placeholder('转入账户', editPurpose: AccountSelectionPurpose.settlement)
        else
          for (final line in incoming)
            info('转入账户', line, editPurpose: AccountSelectionPurpose.settlement),
      ];
    case BusinessPurpose.dailyIncome:
    case BusinessPurpose.refund:
    case BusinessPurpose.advanceCollection:
    case BusinessPurpose.advanceSettlement:
    case BusinessPurpose.borrowing:
    case BusinessPurpose.receivableCollection:
      final editPurpose = purpose == BusinessPurpose.borrowing
          ? AccountSelectionPurpose.fund
          : AccountSelectionPurpose.settlement;
      final incoming = detail.linesOf(TransactionRole.settlementIn).toList();
      final usesBreakdown =
          incoming.length > 1 &&
          (purpose == BusinessPurpose.dailyIncome ||
              purpose == BusinessPurpose.refund ||
              purpose == BusinessPurpose.advanceCollection ||
              purpose == BusinessPurpose.advanceSettlement);
      if (usesBreakdown) return const [];
      return [
        if (purpose == BusinessPurpose.borrowing)
          ...counterpartRows('负债账户', TransactionRole.liability),
        if (purpose == BusinessPurpose.receivableCollection)
          ...counterpartRows('应收账户', TransactionRole.receivable),
        if (incoming.isEmpty)
          placeholder('收支账户', editPurpose: editPurpose)
        else
          for (final line in incoming)
            info('收支账户', line, editPurpose: editPurpose),
      ];
    case BusinessPurpose.dailyExpense:
    case BusinessPurpose.debtRepayment:
    case BusinessPurpose.lending:
      final label = purpose == BusinessPurpose.debtRepayment
          ? '还款账户'
          : purpose == BusinessPurpose.lending
          ? '付款账户'
          : '收支账户';
      final editPurpose = purpose == BusinessPurpose.debtRepayment
          ? AccountSelectionPurpose.repaymentSource
          : purpose == BusinessPurpose.lending
          ? AccountSelectionPurpose.fund
          : AccountSelectionPurpose.settlement;
      final outgoing = detail.linesOf(TransactionRole.settlementOut).toList();
      if (purpose == BusinessPurpose.dailyExpense && outgoing.length > 1) {
        return const [];
      }
      return [
        if (outgoing.isEmpty)
          placeholder(label, editPurpose: editPurpose)
        else
          for (final line in outgoing)
            info(label, line, editPurpose: editPurpose),
        if (purpose == BusinessPurpose.lending)
          ...counterpartRows('应收账户', TransactionRole.receivable),
        if (purpose == BusinessPurpose.debtRepayment)
          ...counterpartRows('负债账户', TransactionRole.liability),
      ];
    case BusinessPurpose.advance:
      final outgoing = detail.linesOf(TransactionRole.settlementOut).toList();
      final receivables = detail.linesOf(TransactionRole.receivable).toList();
      final receivableLabel = _advanceReceivableAccountLabel(
        detail.ownership?.advanceScenario,
      );
      return [
        if (outgoing.length > 1)
          ...const []
        else if (outgoing.isEmpty)
          placeholder('收支账户', editPurpose: AccountSelectionPurpose.settlement)
        else
          for (final line in outgoing)
            info('收支账户', line, editPurpose: AccountSelectionPurpose.settlement),
        if (receivables.isEmpty)
          placeholder(
            receivableLabel,
            editPurpose: AccountSelectionPurpose.advanceReceivable,
          )
        else
          for (final line in receivables)
            info(
              receivableLabel,
              line,
              editPurpose: AccountSelectionPurpose.advanceReceivable,
            ),
      ];
    case BusinessPurpose.openingBalance:
      final lines = detail.linesOf(TransactionRole.openingBalance).toList();
      return lines.isEmpty
          ? [placeholder('账户')]
          : [for (final line in lines) info('账户', line)];
    case BusinessPurpose.balanceAdjustment:
      final lines = detail.linesOf(TransactionRole.balanceAdjustment).toList();
      return lines.isEmpty
          ? [placeholder('账户')]
          : [for (final line in lines) info('账户', line)];
    case BusinessPurpose.badDebt:
      final lines = detail.linesOf(TransactionRole.receivable).toList();
      return lines.isEmpty
          ? [placeholder('账户')]
          : [for (final line in lines) info('账户', line)];
    case BusinessPurpose.debtRelief:
      final lines = detail.linesOf(TransactionRole.liability).toList();
      return lines.isEmpty
          ? [placeholder('账户')]
          : [for (final line in lines) info('账户', line)];
  }
}

DetailRefund? _refundState(TransactionReadModel detail) {
  final purpose = detail.businessPurpose;
  if (purpose != BusinessPurpose.dailyExpense &&
      purpose != BusinessPurpose.advance) {
    return null;
  }
  final refunded = detail.refundSummary?.refundedTotal ?? Money.zero();
  final hasRefund = refunded.minorUnits > 0;
  if (purpose == BusinessPurpose.advance && !hasRefund) {
    return null;
  }
  return DetailRefund(
    hasRefund: hasRefund,
    refundedTotal: refunded,
    items: refundSheetItems(detail.children),
  );
}

DetailAdvance? _advanceState(TransactionReadModel detail) {
  if (detail.businessPurpose != BusinessPurpose.advance ||
      _advanceManagement(detail) != AdvanceManagement.itemized) {
    return null;
  }
  final summary = detail.advanceSummary;
  final items = advanceSheetItems(detail.children);
  final hasActivity = items.isNotEmpty;
  final summaryText = summary == null
      ? '未收回'
      : summary.isClosed
      ? '已结清 · 实收 ${summary.receivedAmount.format()}'
      : hasActivity
      ? '已收 ${summary.receivedAmount.format()} / 应收 ${summary.advanceAmount.format()}'
      : '未收回';
  return DetailAdvance(
    summaryText: summaryText,
    hasActivity: hasActivity,
    isClosed: summary?.isClosed ?? false,
    outstanding: summary?.outstanding,
    items: items,
  );
}

List<DetailActionButton> _actionButtons(
  TransactionReadModel detail,
  TransactionReadModel? parentDetail,
  DetailBehaviorConfig behavior,
) {
  final transaction = detail;
  final editLocked = _isEarlierAdvanceChildLocked(detail, parentDetail);
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
    case BusinessPurpose.advance:
      final closed = detail.advanceSummary?.isClosed ?? false;
      if (_advanceManagement(detail) == AdvanceManagement.itemized) {
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
            kind: DetailActionKind.advance,
            label: _advanceActionLabel(transaction.ownership?.advanceScenario),
            primary: false,
            enabled: !closed,
            route: '/transaction/${transaction.id}/advance',
            deniedReason: closed ? '垫付已结清' : null,
          ),
        );
      } else {
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
      deniedReason: editLocked ? _advanceSettledEditReason : null,
    ),
  );
  return result;
}

AdvanceManagement _advanceManagement(TransactionReadModel detail) {
  return detail.ownership?.advanceManagement ?? AdvanceManagement.itemized;
}

String _advanceActionLabel(AdvanceScenario? scenario) {
  return switch (scenario) {
    AdvanceScenario.aa => 'AA收回',
    AdvanceScenario.onBehalf => '代付收回',
    AdvanceScenario.reimbursement => '报销',
    null => '垫付',
  };
}

String _advanceReceivableAccountLabel(AdvanceScenario? scenario) {
  return scenario == AdvanceScenario.reimbursement ? '报销账户' : '应收账户';
}

DetailEditPermission _accountEditPermission(
  AccountSelectionPurpose? editPurpose,
  DetailBehaviorConfig behavior,
) {
  return switch (editPurpose) {
    null => const DetailEditPermission.allowed(),
    AccountSelectionPurpose.settlement ||
    AccountSelectionPurpose.fund ||
    AccountSelectionPurpose.repaymentSource =>
      behavior.canEditSettlementAccount,
    AccountSelectionPurpose.advanceReceivable =>
      const DetailEditPermission.allowed(),
    AccountSelectionPurpose.ordinaryReceivable ||
    AccountSelectionPurpose.receivable => const DetailEditPermission.denied(
      reason: '当前账户用途不能在交易详情页编辑',
    ),
    AccountSelectionPurpose.repaymentTarget ||
    AccountSelectionPurpose.borrowingLiability =>
      const DetailEditPermission.denied(reason: '当前账户用途不能在交易详情页编辑'),
  };
}

DetailBehaviorConfig _behaviorConfigFor(TransactionReadModel detail) {
  final transaction = detail;
  const postedAtPermission = DetailEditPermission.allowed();
  if (transaction.businessPurpose == BusinessPurpose.refund ||
      transaction.businessPurpose == BusinessPurpose.advanceCollection ||
      transaction.businessPurpose == BusinessPurpose.advanceSettlement) {
    return DetailBehaviorConfig(
      editRoute: switch (transaction.businessPurpose) {
        BusinessPurpose.refund => '/transaction/${transaction.id}/refund/edit',
        BusinessPurpose.advanceCollection ||
        BusinessPurpose.advanceSettlement =>
          '/transaction/${transaction.id}/advance/edit',
        _ => null,
      },
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditPostedAt: const DetailEditPermission.allowed(),
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: const DetailEditPermission.allowed(),
      canEditTags: _tagEditPermissionFor(transaction),
    );
  }

  if (transaction.businessPurpose == BusinessPurpose.advance) {
    return DetailBehaviorConfig(
      editRoute: '/transaction/${transaction.id}/edit',
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditPostedAt: postedAtPermission,
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: const DetailEditPermission.allowed(),
      canEditTags: _tagEditPermissionFor(transaction),
    );
  }

  final ownership = transaction.ownership;
  if (ownership == null) {
    return DetailBehaviorConfig(
      editRoute: switch (transaction.businessPurpose) {
        BusinessPurpose.dailyExpense ||
        BusinessPurpose.dailyIncome ||
        BusinessPurpose.transfer ||
        BusinessPurpose.advance ||
        BusinessPurpose.borrowing => '/transaction/${transaction.id}/edit',
        BusinessPurpose.lending => '/transaction/${transaction.id}/edit',
        BusinessPurpose.receivableCollection =>
          '/transaction/${transaction.id}/receivable-collection/edit',
        BusinessPurpose.badDebt =>
          '/transaction/${transaction.id}/bad-debt/edit',
        BusinessPurpose.debtRelief =>
          '/transaction/${transaction.id}/debt-relief/edit',
        BusinessPurpose.debtRepayment =>
          '/transaction/${transaction.id}/repayment/edit',
        BusinessPurpose.openingBalance ||
        BusinessPurpose.balanceAdjustment => null,
        BusinessPurpose.refund ||
        BusinessPurpose.advanceCollection ||
        BusinessPurpose.advanceSettlement => null,
      },
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditPostedAt: postedAtPermission,
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: const DetailEditPermission.allowed(),
      canEditTags: _tagEditPermissionFor(transaction),
    );
  }

  if (ownership.ownerType == installmentOwnerType &&
      ownership.ownerId != null) {
    final role = InstallmentOwnerRole.fromWire(ownership.ownerRole);
    if (role != null) {
      return DetailBehaviorConfig(
        editRoute: '/installments/${ownership.ownerId}',
        canEditOccurredAt: const DetailEditPermission.allowed(),
        canEditPostedAt: postedAtPermission,
        canEditNote: const DetailEditPermission.allowed(),
        canEditSettlementAccount: const DetailEditPermission.allowed(),
        canEditTags: _tagEditPermissionFor(transaction),
      );
    }
  }

  if (ownership.ownerType == creditRepaymentOwnerType &&
      ownership.ownerId != null) {
    final repaymentType = _repaymentTypeFromOwnerRole(ownership.ownerRole);
    if (repaymentType != null) {
      return DetailBehaviorConfig(
        editRoute: repaymentType == RepaymentType.bill
            ? '/repayments/${ownership.ownerId}/edit'
                  '?transactionId=${transaction.id}'
            : null,
        canEditOccurredAt: const DetailEditPermission.allowed(),
        canEditPostedAt: postedAtPermission,
        canEditNote: const DetailEditPermission.allowed(),
        canEditSettlementAccount: const DetailEditPermission.allowed(),
        canEditTags: _tagEditPermissionFor(transaction),
      );
    }
  }

  return DetailBehaviorConfig(
    canEditOccurredAt: const DetailEditPermission.denied(
      reason: '未识别的业务来源不支持修改交易时间或账户',
    ),
    canEditPostedAt: postedAtPermission,
    canEditNote: const DetailEditPermission.allowed(),
    canEditSettlementAccount: const DetailEditPermission.denied(
      reason: '未识别的业务来源不支持修改交易时间或账户',
    ),
    canEditTags: _tagEditPermissionFor(transaction),
  );
}

DetailEditPermission _tagEditPermissionFor(TransactionReadModel transaction) {
  return transaction.parentTransactionId == null
      ? const DetailEditPermission.allowed()
      : const DetailEditPermission.denied(reason: '跟随所属交易组标签，请在顶层交易修改');
}

bool _isEarlierAdvanceChildLocked(
  TransactionReadModel detail,
  TransactionReadModel? parentDetail,
) {
  final purpose = detail.businessPurpose;
  if (purpose != BusinessPurpose.refund &&
      purpose != BusinessPurpose.advanceCollection) {
    return false;
  }
  return parentDetail?.advanceSummary?.isClosed ?? false;
}

const String _advanceSettledEditReason = '垫付已结清，请先删除垫付结清';

RepaymentType? _repaymentTypeFromOwnerRole(String? ownerRole) {
  if (ownerRole == null) return null;
  try {
    return RepaymentType.fromCode(ownerRole);
  } on ArgumentError {
    return null;
  }
}

String _transactionDetailDeleteMessage(TransactionReadModel detail) {
  final owner = detail.ownership;
  if (owner?.ownerType == installmentOwnerType &&
      owner?.ownerId != null &&
      InstallmentOwnerRole.fromWire(owner?.ownerRole) != null) {
    return '此操作将删除关联分期合同、还款计划及其关联账务记录，无法恢复。';
  }
  if (owner?.ownerType == creditRepaymentOwnerType && owner?.ownerId != null) {
    return '此操作将删除还款记录及其关联交易，并重新计算相关账单与合同的还款状态，无法恢复。';
  }
  return detail.parentTransactionId == null
      ? '此操作将删除整个交易组及其账务记录（包括退款、垫付等子交易），无法恢复。'
      : '此操作仅删除当前子交易及其账务记录，无法恢复。';
}
