import '../../../core/money/money.dart';
import '../enums/installment_enums.dart';

class InstallmentSchedule {
  const InstallmentSchedule({
    required this.id,
    required this.contractId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.status,
    required this.createdAt,
    this.note,
  });

  final int id;
  final int contractId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final InstallmentScheduleStatus status;
  final String? note;
  final DateTime createdAt;
}
