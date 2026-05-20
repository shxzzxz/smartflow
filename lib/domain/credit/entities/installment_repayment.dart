import '../enums/installment_enums.dart';

class InstallmentRepayment {
  const InstallmentRepayment({
    required this.id,
    required this.contractId,
    required this.repaymentType,
    required this.transactionId,
    required this.createdAt,
    this.scheduleId,
  });

  final int id;
  final int contractId;
  final InstallmentRepaymentType repaymentType;
  final int? scheduleId;
  final int transactionId;
  final DateTime createdAt;
}
