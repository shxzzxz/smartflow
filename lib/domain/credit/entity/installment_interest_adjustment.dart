import '../valobj/installment_plan_operation.dart';

class InstallmentInterestAdjustment {
  const InstallmentInterestAdjustment({
    required this.id,
    required this.contractId,
    required this.adjustment,
  });

  final String id, contractId;
  final InterestAdjustment adjustment;
}
