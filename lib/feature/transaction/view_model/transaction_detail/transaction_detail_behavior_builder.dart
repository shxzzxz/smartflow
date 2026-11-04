part of 'transaction_detail_state_builder.dart';

DetailBehaviorConfig _buildTransactionDetailBehavior(
  TransactionDetailContext context,
) {
  final transaction = context.transaction;
  final item = context.businessItem;
  const postedAtPermission = DetailEditPermission.allowed();
  if (item is AmortizationBusinessActivityItem) {
    switch (item.factKind) {
      case AmortizationTransactionFactKind.refund:
        return DetailBehaviorConfig(
          editRoute: '/transaction/${transaction.id}/refund/edit',
          canEditOccurredAt: const DetailEditPermission.allowed(),
          canEditPostedAt: postedAtPermission,
          canEditNote: const DetailEditPermission.allowed(),
          canEditSettlementAccount: const DetailEditPermission.allowed(),
          canEditTags: _tagEditPermissionFor(transaction),
          deletePermission: const DetailEditPermission.allowed(),
        );
      case AmortizationTransactionFactKind.terminationRecognition:
      case AmortizationTransactionFactKind.terminationReturn:
        return DetailBehaviorConfig(
          editRoute:
              '/transaction/${transaction.id}/amortization-terminate/edit',
          canEditOccurredAt: const DetailEditPermission.allowed(),
          canEditPostedAt: postedAtPermission,
          canEditNote: const DetailEditPermission.allowed(),
          canEditSettlementAccount: const DetailEditPermission.allowed(),
          canEditTags: _tagEditPermissionFor(transaction),
          deletePermission: const DetailEditPermission.allowed(),
        );
      case AmortizationTransactionFactKind.initial:
      case AmortizationTransactionFactKind.recognition:
        break;
    }
  }
  if (transaction.businessPurpose == BusinessPurpose.refund ||
      transaction.businessPurpose == BusinessPurpose.advanceCollection ||
      transaction.businessPurpose == BusinessPurpose.advanceSettlement) {
    final installmentRefund =
        item is InstallmentBusinessActivityItem &&
        item.factKind == InstallmentTransactionFactKind.refund;
    return DetailBehaviorConfig(
      editRoute: switch (transaction.businessPurpose) {
        BusinessPurpose.refund => '/transaction/${transaction.id}/refund/edit',
        BusinessPurpose.advanceCollection ||
        BusinessPurpose.advanceSettlement =>
          '/transaction/${transaction.id}/advance/edit',
        _ => null,
      },
      canEditOccurredAt: installmentRefund
          ? const DetailEditPermission.denied(reason: '请在退款编辑页修改退款时间')
          : const DetailEditPermission.allowed(),
      canEditPostedAt: postedAtPermission,
      canEditNote: installmentRefund
          ? const DetailEditPermission.denied(reason: '请在退款编辑页修改备注')
          : const DetailEditPermission.allowed(),
      canEditSettlementAccount: installmentRefund
          ? const DetailEditPermission.denied(reason: '请在退款编辑页修改到账分配')
          : const DetailEditPermission.allowed(),
      canEditTags: _tagEditPermissionFor(transaction),
      deletePermission: _deletePermissionFor(item),
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
      deletePermission: _deletePermissionFor(item),
    );
  }

  if (item == null) {
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

  if (item is InstallmentBusinessActivityItem) {
    final purchase = item.factKind == InstallmentTransactionFactKind.purchase;
    return DetailBehaviorConfig(
      editRoute: '/installments/${item.ownerId}',
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditPostedAt: postedAtPermission,
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: purchase
          ? const DetailEditPermission.denied(reason: '消费分期的成交价和结算分配不能直接修改')
          : const DetailEditPermission.allowed(),
      canEditTags: _tagEditPermissionFor(transaction),
      deletePermission: _deletePermissionFor(item),
    );
  }

  if (item is AmortizationBusinessActivityItem) {
    return DetailBehaviorConfig(
      editRoute: '/transaction/${transaction.id}/edit',
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditPostedAt: const DetailEditPermission.allowed(),
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: const DetailEditPermission.denied(
        reason: '摊销计划账户由计划控制',
      ),
      canEditTags: _tagEditPermissionFor(transaction),
      deletePermission: _deletePermissionFor(item),
    );
  }

  if (item is RepaymentBusinessActivityItem) {
    return DetailBehaviorConfig(
      editRoute: item.repaymentType == RepaymentType.bill
          ? '/repayments/${item.ownerId}/edit'
                '?transactionId=${transaction.id}'
          : null,
      canEditOccurredAt: const DetailEditPermission.allowed(),
      canEditPostedAt: postedAtPermission,
      canEditNote: const DetailEditPermission.allowed(),
      canEditSettlementAccount: const DetailEditPermission.allowed(),
      canEditTags: _tagEditPermissionFor(transaction),
      deletePermission: _deletePermissionFor(item),
    );
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
    deletePermission: _deletePermissionFor(item),
  );
}

DetailEditPermission _deletePermissionFor(BusinessActivityItem? item) {
  return switch (item) {
    UnknownBusinessActivityItem() => const DetailEditPermission.denied(
      reason: '未识别的业务来源不支持删除',
    ),
    _ => const DetailEditPermission.allowed(),
  };
}

List<DetailActionButton> _buildTransactionDetailActionButtons(
  TransactionDetailContext context,
  DetailBehaviorConfig behavior,
  BusinessActivityReadModel? businessActivity,
) {
  final transaction = context.transaction;
  final item = context.businessItem;
  final editLocked = _isEarlierAdvanceChildLocked(context);
  final result = <DetailActionButton>[];
  switch (transaction.businessPurpose) {
    case BusinessPurpose.dailyExpense:
      if (item is! AmortizationBusinessActivityItem) {
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
    case BusinessPurpose.advance:
      final advance = item is AdvanceBusinessActivityItem ? item : null;
      final advanceSummary =
          businessActivity?.summary is AdvanceBusinessActivitySummary
          ? businessActivity!.summary as AdvanceBusinessActivitySummary
          : null;
      if (advance != null &&
          advance.trackingMode == AdvanceTrackingMode.itemized) {
        final isClosed = advanceSummary?.isClosed ?? false;
        result.add(
          DetailActionButton(
            kind: DetailActionKind.refund,
            label: '退款',
            primary: false,
            enabled: !isClosed,
            route: '/transaction/${transaction.id}/refund',
            deniedReason: isClosed ? '垫付已结清' : null,
          ),
        );
        result.add(
          DetailActionButton(
            kind: DetailActionKind.advance,
            label: _advanceActionLabel(advance.scenario),
            primary: false,
            enabled: !isClosed,
            route: '/transaction/${transaction.id}/advance',
            deniedReason: isClosed ? '垫付已结清' : null,
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

  if (item is AmortizationBusinessActivityItem) {
    final summary = businessActivity?.summary;
    final showsPlanActions =
        item.factKind == AmortizationTransactionFactKind.initial;
    if (showsPlanActions) {
      final amortizationSummary = summary is AmortizationBusinessActivitySummary
          ? summary
          : null;
      final canRefund =
          amortizationSummary != null &&
          amortizationSummary.status != AmortizationStatus.terminated &&
          amortizationSummary.remainingAmount.minorUnits > 0;
      result.add(
        DetailActionButton(
          kind: DetailActionKind.refund,
          label: '退款',
          primary: false,
          enabled: canRefund,
          route: '/transaction/${transaction.id}/refund',
          deniedReason: _amortizationRefundDeniedReason(
            amortizationSummary?.status,
          ),
        ),
      );
      result.add(
        DetailActionButton(
          kind: DetailActionKind.amortizationTermination,
          label: '终止',
          primary: false,
          enabled: canRefund,
          route: '/transaction/${transaction.id}/amortization-terminate',
          deniedReason: _amortizationTerminationDeniedReason(
            amortizationSummary?.status,
          ),
        ),
      );
    }
  }

  result.add(
    DetailActionButton(
      kind: DetailActionKind.edit,
      label: '编辑',
      primary: true,
      enabled:
          behavior.editRoute != null &&
          !editLocked &&
          !(item is AmortizationBusinessActivityItem &&
              context.isAmortizationTerminated &&
              item.factKind !=
                  AmortizationTransactionFactKind.terminationRecognition &&
              item.factKind !=
                  AmortizationTransactionFactKind.terminationReturn),
      route: behavior.editRoute,
      deniedReason: editLocked
          ? _advanceSettledEditReason
          : item is AmortizationBusinessActivityItem &&
                context.isAmortizationTerminated &&
                item.factKind !=
                    AmortizationTransactionFactKind.terminationRecognition &&
                item.factKind !=
                    AmortizationTransactionFactKind.terminationReturn
          ? '请先删除摊销终止'
          : null,
    ),
  );
  return result;
}

bool _isEarlierAdvanceChildLocked(TransactionDetailContext context) {
  final purpose = context.transaction.businessPurpose;
  if (purpose != BusinessPurpose.refund &&
      purpose != BusinessPurpose.advanceCollection) {
    return false;
  }
  return context.parentFacts?.isAdvanceClosed ?? false;
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

String? _amortizationRefundDeniedReason(AmortizationStatus? status) {
  return status == AmortizationStatus.terminated ? '摊销计划已终止' : '当前没有可退款金额';
}

String? _amortizationTerminationDeniedReason(AmortizationStatus? status) {
  return status == AmortizationStatus.terminated ? '摊销计划已终止' : '当前没有可终止余额';
}

DetailEditPermission _accountEditPermission(
  AccountSelectionPurpose? editPurpose,
  DetailBehaviorConfig behavior,
) {
  return switch (editPurpose) {
    null => const DetailEditPermission.allowed(),
    AccountSelectionPurpose.settlement ||
    AccountSelectionPurpose.expenseSettlement ||
    AccountSelectionPurpose.fund ||
    AccountSelectionPurpose.repaymentSource =>
      behavior.canEditSettlementAccount,
    AccountSelectionPurpose.advanceReceivable =>
      const DetailEditPermission.allowed(),
    AccountSelectionPurpose.ordinaryReceivable ||
    AccountSelectionPurpose.receivable ||
    AccountSelectionPurpose.prepaidExpense ||
    AccountSelectionPurpose.deferredIncome => const DetailEditPermission.denied(
      reason: '当前账户用途不能在交易详情页编辑',
    ),
    AccountSelectionPurpose.repaymentTarget ||
    AccountSelectionPurpose.borrowingLiability =>
      const DetailEditPermission.denied(reason: '当前账户用途不能在交易详情页编辑'),
  };
}

DetailEditPermission _tagEditPermissionFor(TransactionReadModel transaction) {
  return transaction.parentTransactionId == null
      ? const DetailEditPermission.allowed()
      : const DetailEditPermission.denied(reason: '跟随所属交易组标签，请在顶层交易修改');
}

const String _advanceSettledEditReason = '垫付已结清，请先删除垫付结清';

String _transactionDetailDeleteMessage(TransactionDetailContext context) {
  final detail = context.transaction;
  return switch (context.businessItem) {
    InstallmentBusinessActivityItem()
        when detail.businessPurpose == BusinessPurpose.refund =>
      '此操作将删除退款交易、撤销退款还本并重新计算分期计划，无法恢复。',
    InstallmentBusinessActivityItem() => '此操作将删除关联分期、还款计划及其关联账务记录，无法恢复。',
    RepaymentBusinessActivityItem() =>
      '此操作将删除还款记录及其关联交易，并重新计算相关账单与分期的还款状态，无法恢复。',
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.refund,
    ) =>
      '此操作将删除这笔摊销退款及其转账交易，并按剩余净额重算摊销期次，无法恢复。',
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.terminationRecognition ||
          AmortizationTransactionFactKind.terminationReturn,
    ) =>
      '此操作将删除该笔摊销终止及其关联交易，恢复并补齐摊销期次，无法恢复。',
    AmortizationBusinessActivityItem() => '此操作将删除整个摊销计划及其全部关联账务交易，无法恢复。',
    _ =>
      detail.parentTransactionId == null
          ? '此操作将删除整个交易组及其账务记录（包括退款、垫付等子交易），无法恢复。'
          : '此操作仅删除当前子交易及其账务记录，无法恢复。',
  };
}
