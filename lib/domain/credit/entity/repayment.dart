import '../../../core/error/app_exception.dart';
import '../valobj/credit_error_code.dart';
import '../valobj/repayment_amount_breakdown.dart';
import '../valobj/repayment_enums.dart';

class Repayment {
  Repayment({
    required this.id,
    required this.repaymentType,
    required this.targetType,
    required this.targetId,
    required List<RepaymentItem> items,
    this.rootTransactionId,
    this.createdAt,
  }) : _items = List.unmodifiable(items) {
    _ensureValid();
  }

  final String id;
  final RepaymentType repaymentType;
  final RepaymentTargetType targetType;
  final String targetId;
  final DateTime? createdAt;
  String? rootTransactionId;
  List<RepaymentItem> _items;

  List<RepaymentItem> get items => _items;

  void validateTarget() {
    final valid = switch (repaymentType) {
      RepaymentType.bill ||
      RepaymentType.installment => targetType == RepaymentTargetType.bill,
      RepaymentType.extraPrincipal || RepaymentType.earlySettlement =>
        targetType == RepaymentTargetType.contract,
      RepaymentType.unattributed => targetType == RepaymentTargetType.account,
    };
    if (!valid) {
      throw BusinessException(
        CreditErrorCode.repaymentInvalidCommand,
        message: 'Repayment type does not match target type.',
      );
    }
  }

  RepaymentAmountBreakdown totalAllocated() {
    return _items.fold(
      RepaymentAmountBreakdown.zero,
      (sum, item) => sum + item.allocated,
    );
  }

  void validateAgainstLedgerTransaction(
    RepaymentAmountBreakdown transactionParts,
  ) {
    if (rootTransactionId == null) return;
    if (totalAllocated() != transactionParts) {
      throw BusinessException(
        CreditErrorCode.repaymentInvalidCommand,
        message: 'Repayment allocations do not match ledger transaction.',
      );
    }
  }

  void replaceItems(List<RepaymentItem> nextItems) {
    _items = List.unmodifiable(nextItems);
    _ensureItemsValid();
  }

  void _ensureValid() {
    validateTarget();
    if (repaymentType == RepaymentType.installment &&
        rootTransactionId != null) {
      throw BusinessException(
        CreditErrorCode.repaymentInvalidCommand,
        message:
            'Bill conversion installment repayment must not have ledger transaction.',
      );
    }
    _ensureItemsValid();
  }

  void _ensureItemsValid() {
    if (_items.isEmpty) {
      throw BusinessException(
        CreditErrorCode.repaymentInvalidCommand,
        message: 'Repayment must have at least one item.',
      );
    }

    for (final item in _items) {
      if (item.repaymentId != id) {
        throw BusinessException(
          CreditErrorCode.repaymentInvalidCommand,
          message: 'Repayment item belongs to another repayment.',
        );
      }
      if (item.allocated.hasNegativePart) {
        throw BusinessException(
          CreditErrorCode.repaymentInvalidCommand,
          message: 'Repayment allocation cannot be negative.',
        );
      }

      final isBillLevel =
          repaymentType == RepaymentType.bill ||
          repaymentType == RepaymentType.installment;
      final billItemValid =
          isBillLevel ? item.billItemId != null : item.billItemId == null;
      if (!billItemValid) {
        throw BusinessException(
          CreditErrorCode.repaymentInvalidCommand,
          message: 'Repayment item bill target does not match repayment type.',
        );
      }
    }
  }
}

class RepaymentItem {
  const RepaymentItem({
    required this.id,
    required this.repaymentId,
    required this.allocated,
    this.billItemId,
    this.createdAt,
  });

  final String id;
  final String repaymentId;
  final String? billItemId;
  final RepaymentAmountBreakdown allocated;
  final DateTime? createdAt;
}
