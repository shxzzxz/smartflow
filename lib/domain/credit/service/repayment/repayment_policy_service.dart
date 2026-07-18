import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';

class BillRepaymentAllocationDraft {
  const BillRepaymentAllocationDraft({
    required this.billItemId,
    required this.allocated,
  });

  final String billItemId;
  final RepaymentAmountBreakdown allocated;
}

class RepaymentPolicyService {
  const RepaymentPolicyService();

  void validateBillRepayment({
    required Bill bill,
    required List<BillRepaymentAllocationDraft> allocations,
    bool allowSettled = false,
  }) {
    if ((!allowSettled && bill.status == BillStatus.settled) ||
        allocations.isEmpty) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }

    final billItemsById = {for (final item in bill.items) item.id: item};
    final seen = <String>{};
    for (final allocation in allocations) {
      final item = billItemsById[allocation.billItemId];
      if (item == null || !seen.add(allocation.billItemId)) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (item.status == BillItemStatus.skipped) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (bill.status == BillStatus.open &&
          item.itemType != BillItemType.consumption) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (allocation.allocated.hasNegativePart) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
    }

    if (total(allocations).cashPaid.minorUnits <= 0) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }
  }

  void validateBillConversionInstallment({
    required Bill bill,
    required List<BillRepaymentAllocationDraft> allocations,
    required int totalPeriods,
    required DateTime? firstRepaymentDate,
    required DateTime? lastRepaymentDate,
    required InterestRatePeriod? interestRatePeriod,
    required int? interestRatePpm,
    required int totalFeeMinor,
    required int? equalInstallmentOverrideMinor,
  }) {
    if (bill.status != BillStatus.billed || allocations.isEmpty) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }

    final billItemsById = {for (final item in bill.items) item.id: item};
    final seen = <String>{};
    for (final allocation in allocations) {
      final item = billItemsById[allocation.billItemId];
      if (item == null || !seen.add(allocation.billItemId)) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (item.itemType != BillItemType.consumption ||
          (item.status != BillItemStatus.pending &&
              item.status != BillItemStatus.partiallyPaid) ||
          allocation.allocated.hasNegativePart ||
          allocation.allocated.interest.minorUnits != 0 ||
          allocation.allocated.fee.minorUnits != 0 ||
          allocation.allocated.discount.minorUnits != 0) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
    }

    final principal = total(allocations).principal;
    if (principal.minorUnits <= 0) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }
    validateInstallmentTerms(
      principal: principal,
      totalPeriods: totalPeriods,
      firstRepaymentDate: firstRepaymentDate,
      lastRepaymentDate: lastRepaymentDate,
      interestRatePeriod: interestRatePeriod,
      interestRatePpm: interestRatePpm,
      totalFeeMinor: totalFeeMinor,
      equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
    );
  }

  void validateActiveContractRepayment({
    required InstallmentContract contract,
    required RepaymentAmountBreakdown total,
  }) {
    if (contract.status != InstallmentContractStatus.active) {
      throw BusinessException(
        CreditErrorCode.contractNotActive,
        message: 'Only active contracts allow contract-side repayment.',
      );
    }
    if (total.hasNegativePart || total.cashPaid.minorUnits <= 0) {
      throw BusinessException(CreditErrorCode.repaymentInvalidCommand);
    }
  }

  void validateUnattributedRepayment({
    required RepaymentAmountBreakdown total,
    required Money availableDebt,
  }) {
    validatePositiveCashRepayment(total);
    if (total.principal.minorUnits > availableDebt.minorUnits) {
      throw BusinessException(CreditErrorCode.repaymentExceedsAvailable);
    }
  }

  void validatePositiveCashRepayment(RepaymentAmountBreakdown total) {
    if (total.principal.minorUnits <= 0 ||
        total.hasNegativePart ||
        total.cashPaid.minorUnits <= 0) {
      throw BusinessException(CreditErrorCode.repaymentInvalidCommand);
    }
  }

  void validateInstallmentTerms({
    required Money principal,
    required int totalPeriods,
    required DateTime? firstRepaymentDate,
    required DateTime? lastRepaymentDate,
    required InterestRatePeriod? interestRatePeriod,
    required int? interestRatePpm,
    required int totalFeeMinor,
    required int? equalInstallmentOverrideMinor,
  }) {
    if (principal.minorUnits <= 0 ||
        totalPeriods <= 0 ||
        totalFeeMinor < 0 ||
        (equalInstallmentOverrideMinor ?? 0) < 0 ||
        (interestRatePpm ?? 0) < 0 ||
        (interestRatePeriod == null) != (interestRatePpm == null)) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
    if (firstRepaymentDate != null &&
        lastRepaymentDate != null &&
        totalPeriods > 1 &&
        !lastRepaymentDate.isAfter(firstRepaymentDate)) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
  }

  RepaymentAmountBreakdown total(
    Iterable<BillRepaymentAllocationDraft> allocations,
  ) {
    return allocations.fold(
      RepaymentAmountBreakdown.zero,
      (sum, allocation) => sum + allocation.allocated,
    );
  }

  List<BillRepaymentAllocationDraft> allocationsFromItems(
    List<RepaymentItem> items,
  ) {
    return [
      for (final item in items)
        if (item.billItemId != null)
          BillRepaymentAllocationDraft(
            billItemId: item.billItemId!,
            allocated: item.allocated,
          ),
    ];
  }
}
