import '../valobj/floating_rate.dart';

class InstallmentRepricing {
  const InstallmentRepricing({
    required this.id,
    required this.contractId,
    required this.stageId,
    required this.change,
    this.applied = false,
  });
  final String id;
  final String contractId;
  final String stageId;
  final RateChange change;
  final bool applied;
}
