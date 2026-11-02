import '../../../../../domain/credit/valobj/repayment_amount_breakdown.dart';

abstract interface class InstallmentProgressSource {
  Future<Map<String, List<InstallmentRepaymentAllocationFact>>>
  findRepaymentFacts(Set<String> contractIds);
}

final class InstallmentRepaymentAllocationFact {
  const InstallmentRepaymentAllocationFact({
    required this.contractId,
    required this.allocated,
    this.scheduleId,
  });

  final String contractId;
  final String? scheduleId;
  final RepaymentAmountBreakdown allocated;
}
