part of 'transaction_detail_state_builder.dart';

({DetailAdvance? advance, List<DetailBusinessModule> modules})
_buildTransactionDetailBusiness(TransactionDetailContext context) {
  final transaction = context.transaction;
  final owner = context.owner;
  final advance = owner is AdvanceTransactionDetailOwnerContext
      ? _advanceState(transaction, owner)
      : null;
  return (
    advance: advance,
    modules: switch (owner) {
      InstallmentTransactionDetailOwnerContext() => [_installmentModule(owner)],
      RepaymentTransactionDetailOwnerContext() => [
        _repaymentModule(context, owner),
      ],
      AmortizationTransactionDetailOwnerContext() => [
        _amortizationModule(owner),
      ],
      _ => const <DetailBusinessModule>[],
    },
  );
}

DetailAdvance? _advanceState(
  TransactionReadModel detail,
  AdvanceTransactionDetailOwnerContext owner,
) {
  if (detail.businessPurpose != BusinessPurpose.advance ||
      owner.trackingMode != AdvanceTrackingMode.itemized) {
    return null;
  }
  final items = advanceSheetItems(detail.children);
  final hasActivity = items.isNotEmpty;
  final summaryText = owner.isClosed
      ? '已结清 · 实收 ${owner.receivedAmount.format()}'
      : hasActivity
      ? '已收 ${owner.receivedAmount.format()} / 应收 ${owner.advanceAmount.format()}'
      : '未收回';
  return DetailAdvance(
    summaryText: summaryText,
    hasActivity: hasActivity,
    isClosed: owner.isClosed,
    outstanding: owner.outstanding,
    items: items,
  );
}

DetailBusinessModule _installmentModule(
  InstallmentTransactionDetailOwnerContext owner,
) {
  final type = switch (owner.installmentType) {
    InstallmentType.disbursement => '放款分期',
    InstallmentType.billConversion => '账单分期',
    InstallmentType.purchase => '消费分期',
  };
  return DetailBusinessModule.link(
    key: 'installment',
    title: '分期合同',
    summary:
        '$type · 已还 ${owner.paidPeriodCount}/${owner.totalPeriodCount} · '
        '剩余本金 ${owner.remainingPrincipal.format()}',
    route: '/installments/${owner.ownerId}',
  );
}

DetailBusinessModule _repaymentModule(
  TransactionDetailContext context,
  RepaymentTransactionDetailOwnerContext owner,
) {
  final route = switch (owner.targetType) {
    RepaymentTargetType.bill => '/bills/${owner.targetId}',
    RepaymentTargetType.contract => '/installments/${owner.targetId}',
    RepaymentTargetType.account => '/account/${owner.targetId}',
  };
  return DetailBusinessModule.link(
    key: 'credit-repayment',
    title: '还款归属',
    summary: '${owner.repaymentType.label} · ${owner.targetType.label}',
    route: route,
  );
}

DetailBusinessModule _amortizationModule(
  AmortizationTransactionDetailOwnerContext owner,
) {
  final type = switch (owner.kind) {
    AmortizationKind.prepaidExpense => '预付费用',
    AmortizationKind.deferredIncome => '递延收入',
  };
  final status = switch (owner.status) {
    AmortizationStatus.active => '进行中',
    AmortizationStatus.completed => '已完成',
    AmortizationStatus.terminated => '已终止',
  };
  return DetailBusinessModule.link(
    key: 'amortization',
    title: '摊销计划',
    summary:
        '$type · $status · 已确认 '
        '${owner.postedPeriodCount}/${owner.totalPeriodCount}',
    route: '/amortizations/${owner.ownerId}',
  );
}
