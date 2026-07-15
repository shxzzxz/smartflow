import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

class InstallmentFinancialTermsPolicy {
  const InstallmentFinancialTermsPolicy();

  void validate({
    required int totalFeeMinor,
    required InterestRatePeriod? interestRatePeriod,
    required int? interestRatePpm,
  }) {
    final ratePairIsIncomplete =
        (interestRatePeriod == null) != (interestRatePpm == null);
    if (totalFeeMinor < 0 ||
        (interestRatePpm != null && interestRatePpm < 0) ||
        ratePairIsIncomplete) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
  }
}
