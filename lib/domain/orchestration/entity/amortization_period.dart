import '../../../core/money/money.dart';
import '../../ledger/valobj/account_amount_allocation.dart';
import '../valobj/amortization_enums.dart';

class AmortizationPeriod {
  const AmortizationPeriod({
    required this.id,
    required this.planId,
    required this.sequenceNo,
    required this.dueAt,
    required this.amount,
    required this.status,
    this.categoryAllocations = const [],
    this.transactionId,
  });

  final String id;
  final String planId;
  final int sequenceNo;
  final DateTime dueAt;
  final Money amount;
  final List<AccountAmountAllocation> categoryAllocations;
  final String? transactionId;
  final AmortizationPeriodStatus status;

  bool get isPosted => status == AmortizationPeriodStatus.posted;

  bool get isPending => status == AmortizationPeriodStatus.pending;

  bool get isZero => status == AmortizationPeriodStatus.zero;

  bool get isCanceled => status == AmortizationPeriodStatus.canceled;

  AmortizationPeriod posted(String nextTransactionId) {
    return _copyWith(
      transactionId: nextTransactionId,
      status: AmortizationPeriodStatus.posted,
    );
  }

  AmortizationPeriod canceled() {
    return _copyWith(
      transactionId: null,
      status: AmortizationPeriodStatus.canceled,
      clearTransactionId: true,
    );
  }

  AmortizationPeriod reopened() {
    return _copyWith(
      transactionId: null,
      status: amount.minorUnits == 0
          ? AmortizationPeriodStatus.zero
          : AmortizationPeriodStatus.pending,
      clearTransactionId: true,
    );
  }

  AmortizationPeriod _copyWith({
    Money? amount,
    List<AccountAmountAllocation>? categoryAllocations,
    String? transactionId,
    AmortizationPeriodStatus? status,
    bool clearTransactionId = false,
  }) {
    return AmortizationPeriod(
      id: id,
      planId: planId,
      sequenceNo: sequenceNo,
      dueAt: dueAt,
      amount: amount ?? this.amount,
      categoryAllocations: categoryAllocations ?? this.categoryAllocations,
      transactionId: clearTransactionId
          ? null
          : transactionId ?? this.transactionId,
      status: status ?? this.status,
    );
  }
}
