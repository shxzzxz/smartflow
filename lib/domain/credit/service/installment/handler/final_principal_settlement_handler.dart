import '../../../../../core/money/money.dart';
import '../calculator/repayment_method_calculator.dart';

/// 正常摊还全部算完后，将末阶段仍保留的本金追加到最后一期一次。
class FinalPrincipalSettlementHandler {
  const FinalPrincipalSettlementHandler();

  ({List<InstallmentAmountAllocation> allocations, Money remainingPrincipal})
  settle({
    required List<InstallmentAmountAllocation> allocations,
    required Money closingPrincipal,
    required bool finalStage,
  }) {
    if (!finalStage || closingPrincipal.minorUnits == 0) {
      return (allocations: allocations, remainingPrincipal: closingPrincipal);
    }
    final last = allocations.last;
    return (
      allocations: List.unmodifiable([
        ...allocations.take(allocations.length - 1),
        InstallmentAmountAllocation(
          principal: last.principal + closingPrincipal,
          interest: last.interest,
          fee: last.fee,
          interestSegments: last.interestSegments,
        ),
      ]),
      remainingPrincipal: Money.zero(),
    );
  }
}
