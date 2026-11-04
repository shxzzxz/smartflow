part of 'transaction_detail_state_builder.dart';

({
  DetailHero hero,
  List<DetailAllocationBreakdown> allocationBreakdowns,
  List<DetailAccountRow> accountRows,
  DetailRefund? refund,
})
_buildTransactionDetailLedger(
  TransactionDetailContext context,
  AccountLookup accountLookup,
  DetailBehaviorConfig behavior,
) {
  final detail = context.transaction;
  final List<AccountAmountAllocation> categoryAllocations =
      switch (context.businessItem) {
        AmortizationBusinessActivityItem(:final localCategoryAllocations) =>
          localCategoryAllocations,
        _ => const <AccountAmountAllocation>[],
      };
  final isActivityEntry = switch (context.businessItem) {
    AdvanceBusinessActivityItem(:final factKind) =>
      factKind == AdvanceTransactionFactKind.advance,
    InstallmentBusinessActivityItem(:final factKind) =>
      factKind == InstallmentTransactionFactKind.purchase ||
          factKind == InstallmentTransactionFactKind.disbursement,
    RepaymentBusinessActivityItem() => true,
    AmortizationBusinessActivityItem(:final factKind) =>
      factKind == AmortizationTransactionFactKind.initial,
    UnknownBusinessActivityItem() || null => false,
  };
  final isNonEntry =
      isKnownBusinessActivityItem(context.businessItem) && !isActivityEntry;
  final categoryAccountIds = isActivityEntry
      ? switch (context.businessItem) {
          AmortizationBusinessActivityItem(:final localCategoryAllocations) =>
            localCategoryAllocations.map((allocation) => allocation.accountId),
          _ => const <String>[],
        }
      : const <String>[];
  return (
    hero: transactionDetailHero(
      detail: detail,
      accountLookup: accountLookup,
      categoryAccountIds: categoryAccountIds,
      titleOverride: isNonEntry
          ? nonEntryBusinessActivityItemTitle(context.businessItem, detail)
          : null,
      useCategoryIdentity: !isNonEntry,
      avatarKind: isNonEntry
          ? businessActivityItemAvatarKind(context.businessItem)
          : null,
    ),
    allocationBreakdowns: transactionDetailAllocationBreakdowns(
      detail: detail,
      accountLookup: accountLookup,
      categoryAllocations: categoryAllocations,
    ),
    accountRows: _accountRows(context, accountLookup, behavior),
    refund: _refundState(detail),
  );
}

List<DetailAccountRow> _accountRows(
  TransactionDetailContext context,
  AccountLookup accountLookup,
  DetailBehaviorConfig behavior,
) {
  final detail = context.transaction;
  final purpose = detail.businessPurpose;
  final advance = context.businessItem;

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
          : AccountSelectionPurpose.expenseSettlement;
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
        advance is AdvanceBusinessActivityItem ? advance.scenario : null,
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
