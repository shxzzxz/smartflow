import '../../../core/money/money.dart';
import '../../../core/error/app_exception.dart';
import '../valobj/bill_enums.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/installment_enums.dart';

class InstallmentSchedule {
  InstallmentSchedule({
    required this.id,
    required this.contractId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required InstallmentScheduleStatus status,
    required this.createdAt,
    this.note,
  }) : _status = status;

  final String id;
  final String contractId;
  final int periodNo;
  DateTime expectedRepaymentDate;
  Money expectedPrincipal;
  Money expectedInterest;
  Money expectedFee;
  InstallmentScheduleStatus _status;
  String? note;
  final DateTime createdAt;

  InstallmentScheduleStatus get status => _status;

  void reviseExpectation({
    Money? expectedPrincipal,
    Money? expectedInterest,
    Money? expectedFee,
    DateTime? expectedRepaymentDate,
    String? note,
  }) {
    _ensurePending();
    if (expectedPrincipal != null) this.expectedPrincipal = expectedPrincipal;
    if (expectedInterest != null) this.expectedInterest = expectedInterest;
    if (expectedFee != null) this.expectedFee = expectedFee;
    if (expectedRepaymentDate != null) {
      this.expectedRepaymentDate = expectedRepaymentDate;
    }
    if (note != null) this.note = note;
  }

  void markPaid() {
    _status = InstallmentScheduleStatus.paid;
  }

  void markPending() {
    _status = InstallmentScheduleStatus.pending;
  }

  void skip() {
    _ensurePending();
    _status = InstallmentScheduleStatus.skipped;
  }

  void restore() {
    if (_status != InstallmentScheduleStatus.skipped) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Only skipped schedules can be restored.',
      );
    }
    _status = InstallmentScheduleStatus.pending;
  }

  void applyBillItemStatus(BillItemStatus status) {
    _status = switch (status) {
      BillItemStatus.paid => InstallmentScheduleStatus.paid,
      BillItemStatus.partiallyPaid => InstallmentScheduleStatus.partiallyPaid,
      BillItemStatus.pending => InstallmentScheduleStatus.pending,
      BillItemStatus.skipped => InstallmentScheduleStatus.skipped,
    };
  }

  void _ensurePending() {
    if (_status != InstallmentScheduleStatus.pending) {
      throw BusinessException(
        CreditErrorCode.scheduleNotPending,
        message: 'Only pending schedules can be edited.',
      );
    }
  }
}
