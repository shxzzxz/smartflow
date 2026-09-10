import '../../../core/error/app_exception.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/floating_rate.dart';
import '../valobj/installment_enums.dart';

class InstallmentRepricing {
  InstallmentRepricing({
    required this.id,
    required this.contractId,
    required this.stageId,
    required this.change,
    InstallmentRepricingStatus status = InstallmentRepricingStatus.pending,
  }) : _status = status;
  final String id;
  final String contractId;
  final String stageId;
  final RateChange change;
  InstallmentRepricingStatus _status;
  InstallmentRepricingStatus get status => _status;
  bool get applied => status != InstallmentRepricingStatus.pending;

  void markApplied() {
    if (_status == InstallmentRepricingStatus.pending) {
      _status = InstallmentRepricingStatus.applied;
    }
  }

  void confirm() {
    if (!applied) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '重定价尚未应用，不能确认',
      );
    }
    _status = InstallmentRepricingStatus.userConfirmed;
  }
}
