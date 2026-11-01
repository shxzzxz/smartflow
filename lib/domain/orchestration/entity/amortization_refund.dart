import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../ledger/valobj/account_amount_allocation.dart';
import '../valobj/amortization_error_code.dart';

class AmortizationRefund {
  AmortizationRefund({
    required this.id,
    required this.planId,
    required Iterable<AccountAmountAllocation> categoryAllocations,
    required Iterable<AccountAmountAllocation> settlementAllocations,
    required this.transferTransactionId,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations) {
    _validate();
  }

  final String id;
  final String planId;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final String transferTransactionId;

  Money get amount => sumAllocations(categoryAllocations);

  void _validate() {
    if (id.trim().isEmpty ||
        planId.trim().isEmpty ||
        transferTransactionId.trim().isEmpty) {
      throw _invalid('Refund identity is required.');
    }
    _validateAllocations(categoryAllocations);
    _validateAllocations(settlementAllocations);
    if (sumAllocations(categoryAllocations) !=
        sumAllocations(settlementAllocations)) {
      throw _invalid('Refund category and settlement totals must match.');
    }
  }

  static void _validateAllocations(
    Iterable<AccountAmountAllocation> allocations,
  ) {
    if (allocations.isEmpty) {
      throw _invalid('Refund allocations cannot be empty.');
    }
    final accountIds = <String>{};
    for (final allocation in allocations) {
      if (allocation.amount.minorUnits <= 0 ||
          !accountIds.add(allocation.accountId)) {
        throw _invalid(
          'Refund allocations must be positive and unique by account.',
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
