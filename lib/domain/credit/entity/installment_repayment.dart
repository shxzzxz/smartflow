import '../valobj/installment_enums.dart';

class InstallmentRepayment {
  const InstallmentRepayment({
    required this.id,
    required this.contractId,
    required this.repaymentType,
    required this.transactionId,
    required this.createdAt,
    this.scheduleId,
  });

  final String id;
  final String contractId;
  final InstallmentRepaymentType repaymentType;
  final String? scheduleId;
  final String transactionId;
  final DateTime createdAt;
}
