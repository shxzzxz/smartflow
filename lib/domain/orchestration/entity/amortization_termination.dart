import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../ledger/valobj/account_amount_allocation.dart';
import '../valobj/amortization_error_code.dart';

class AmortizationTermination {
  AmortizationTermination({
    required this.id,
    required this.planId,
    required this.terminatedAt,
    required Iterable<AccountAmountAllocation> categoryReturnAllocations,
    required Iterable<AccountAmountAllocation> settlementAllocations,
    this.recognitionTransactionId,
    this.returnTransactionId,
  }) : categoryReturnAllocations = List.unmodifiable(categoryReturnAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations) {
    _validate();
  }

  final String id;
  final String planId;
  final DateTime terminatedAt;
  final List<AccountAmountAllocation> categoryReturnAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final String? recognitionTransactionId;
  final String? returnTransactionId;

  Money get returnAmount => sumAllocations(categoryReturnAllocations);

  void _validate() {
    if (id.trim().isEmpty || planId.trim().isEmpty) {
      throw _invalid('Termination identity is required.');
    }
    _validateAllocations(categoryReturnAllocations);
    _validateAllocations(settlementAllocations);
    if (sumAllocations(categoryReturnAllocations) !=
        sumAllocations(settlementAllocations)) {
      throw _invalid('Termination category and settlement totals must match.');
    }
    if (returnAmount.minorUnits > 0 && returnTransactionId == null) {
      throw _invalid('Termination return transaction is required.');
    }
    if (recognitionTransactionId == null && returnTransactionId == null) {
      throw _invalid('Termination requires a recognition or return fact.');
    }
  }

  static void _validateAllocations(
    Iterable<AccountAmountAllocation> allocations,
  ) {
    final accountIds = <String>{};
    for (final allocation in allocations) {
      if (allocation.amount.minorUnits <= 0 ||
          !accountIds.add(allocation.accountId)) {
        throw _invalid(
          'Termination allocations must be positive and unique by account.',
        );
      }
    }
  }

  static BusinessException _invalid(String message) {
    return BusinessException(
      AmortizationErrorCode.invalidCommand,
      message: message,
    );
  }
}
