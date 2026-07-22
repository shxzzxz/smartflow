import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import 'bill_repayment_allocation.dart';

Money? _parseOptionalBillRepaymentMoneyText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  final money = Money.tryParse(trimmed);
  return money != null && money.minorUnits >= 0 ? money : null;
}

RepaymentAmountBreakdown? _billRepaymentAmountFromText({
  required String principalText,
  required String interestText,
  required String feeText,
  required String discountText,
}) {
  final principal = _parseOptionalBillRepaymentMoneyText(principalText);
  final interest = _parseOptionalBillRepaymentMoneyText(interestText);
  final fee = _parseOptionalBillRepaymentMoneyText(feeText);
  final discount = _parseOptionalBillRepaymentMoneyText(discountText);
  if (principal == null ||
      interest == null ||
      fee == null ||
      discount == null) {
    return null;
  }
  return RepaymentAmountBreakdown(
    principal: principal,
    interest: interest,
    fee: fee,
    discount: discount,
  );
}

BillRepaymentAllocationReview? billRepaymentManualAllocationReviewFromText({
  required List<BillRepaymentAllocationLine> lines,
  required Map<String, RepaymentAmountBreakdown> manualAllocations,
  required String principalText,
  required String interestText,
  required String feeText,
  required String discountText,
}) {
  final amount = _billRepaymentAmountFromText(
    principalText: principalText,
    interestText: interestText,
    feeText: feeText,
    discountText: discountText,
  );
  if (amount == null) return null;
  return billRepaymentManualAllocationReview(
    lines: lines,
    manualAllocations: manualAllocations,
    amount: amount,
  );
}

BillRepaymentAllocationReview billRepaymentManualAllocationReview({
  required List<BillRepaymentAllocationLine> lines,
  required Map<String, RepaymentAmountBreakdown> manualAllocations,
  required RepaymentAmountBreakdown amount,
}) {
  final allocations = <BillRepaymentAllocationDraft>[];
  for (final line in lines) {
    final manual =
        manualAllocations[line.billItemId] ?? RepaymentAmountBreakdown.zero;
    if (!_hasPositiveAmount(manual)) continue;
    allocations.add(
      BillRepaymentAllocationDraft(
        billItemId: line.billItemId,
        allocated: manual,
      ),
    );
  }
  return BillRepaymentAllocator(
    lines: lines,
  ).reviewManual(amount: amount, allocations: allocations);
}

String billRepaymentDateText(BillRepaymentReadModel repayment) {
  final prefix =
      repayment.timeSource == BillRepaymentTimeSource.transaction
          ? '还款日'
          : '记录于';
  return '$prefix ${_dateLabel(repayment.displayTime)}';
}

String billRepaymentBreakdownText(BillRepaymentReadModel repayment) {
  final amount = repayment.allocated;
  return '本 ${amount.principal.format()} '
      '息 ${amount.interest.format()} '
      '费 ${amount.fee.format()}';
}

String _dateLabel(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

bool _hasPositiveAmount(RepaymentAmountBreakdown amount) {
  return amount.principal.minorUnits > 0 ||
      amount.interest.minorUnits > 0 ||
      amount.fee.minorUnits > 0 ||
      amount.discount.minorUnits > 0;
}
