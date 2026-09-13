import '../../../../../core/error/app_exception.dart';
import '../../../../../core/money/money.dart';
import '../../../valobj/credit_error_code.dart';
import '../../../valobj/interest_rate.dart';
import 'base_plan_generation_handler.dart';
import 'installment_stage_context.dart';

/// 按整期口径扣减本金、封顶阶段期末本金，并重新求解剩余期限。
class PrincipalReductionHandler {
  const PrincipalReductionHandler(this._generation);

  final BasePlanGenerationHandler _generation;

  Money deduct(Money principal, int reductionMinor) {
    if (reductionMinor > principal.minorUnits) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '本金扣减超过该计息位置的可用本金',
      );
    }
    return principal - Money(minorUnits: reductionMinor);
  }

  ({Money principal, Money endPrincipal, InstallmentStageProjection projection})
  recalculate(
    InstallmentStageContext context, {
    required int periodIndex,
    required Money openingPrincipal,
    required Money endPrincipal,
    required int reductionMinor,
    required InterestRate? rate,
  }) {
    final principal = deduct(openingPrincipal, reductionMinor);
    final target = endPrincipal.minorUnits > principal.minorUnits
        ? principal
        : endPrincipal;
    return (
      principal: principal,
      endPrincipal: target,
      projection: _generation.generate(
        context,
        periodIndex: periodIndex,
        openingPrincipal: principal,
        endPrincipal: target,
        rate: rate,
      ),
    );
  }
}
