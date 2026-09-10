import '../valobj/floating_rate.dart';
import '../valobj/installment_enums.dart';

class InstallmentRepricing {
  const InstallmentRepricing({
    required this.id,
    required this.contractId,
    required this.stageId,
    required this.change,
    this.status = InstallmentRepricingStatus.pending,
  });
  final String id;
  final String contractId;
  final String stageId;
  final RateChange change;
  final InstallmentRepricingStatus status;
  bool get applied => status != InstallmentRepricingStatus.pending;
}
