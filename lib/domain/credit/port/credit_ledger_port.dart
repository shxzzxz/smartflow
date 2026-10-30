import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';

class CreditLedgerPostedTransaction {
  const CreditLedgerPostedTransaction({required this.transactionId});

  final String transactionId;
}

class CreditLedgerExpenseAllocation {
  const CreditLedgerExpenseAllocation({
    required this.accountId,
    required this.amount,
  });

  final String accountId;
  final Money amount;
}

class CreditLedgerPostExpenseCommand {
  CreditLedgerPostExpenseCommand({
    required this.amount,
    required List<CreditLedgerExpenseAllocation> categoryAllocations,
    required List<CreditLedgerExpenseAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
    this.tagIds = const {},
    this.isExcludedFromStats = false,
    this.isExcludedFromBudget = false,
    this.ownership,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final Money amount;
  final List<CreditLedgerExpenseAllocation> categoryAllocations;
  final List<CreditLedgerExpenseAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
  final Set<String> tagIds;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final CreditLedgerOwnership? ownership;
}

class CreditLedgerPostRefundCommand {
  CreditLedgerPostRefundCommand({
    required this.parentTransactionId,
    required this.amount,
    required List<CreditLedgerExpenseAllocation> categoryAllocations,
    required List<CreditLedgerExpenseAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String parentTransactionId;
  final Money amount;
  final List<CreditLedgerExpenseAllocation> categoryAllocations;
  final List<CreditLedgerExpenseAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
  final String? counterpartyId;
  final String? note;
}

class CreditLedgerEditRefundCommand {
  CreditLedgerEditRefundCommand({
    required this.transactionId,
    this.amount,
    List<CreditLedgerExpenseAllocation>? categoryAllocations,
    List<CreditLedgerExpenseAllocation>? settlementAllocations,
    this.occurredAt,
    this.postedAt,
    this.counterpartyId,
    this.note,
  }) : categoryAllocations = categoryAllocations == null
           ? null
           : List.unmodifiable(categoryAllocations),
       settlementAllocations = settlementAllocations == null
           ? null
           : List.unmodifiable(settlementAllocations);

  final String transactionId;
  final Money? amount;
  final List<CreditLedgerExpenseAllocation>? categoryAllocations;
  final List<CreditLedgerExpenseAllocation>? settlementAllocations;
  final DateTime? occurredAt;
  final DateTime? postedAt;
  final Patch<String?>? counterpartyId;
  final Patch<String?>? note;
}

class CreditLedgerAccountSnapshot {
  const CreditLedgerAccountSnapshot({
    required this.id,
    required this.balance,
    required this.isArchived,
    this.kind = CreditLedgerAccountKind.other,
  });

  final String id;
  final Money balance;
  final bool isArchived;
  final CreditLedgerAccountKind kind;
}

class CreditLedgerTransactionSnapshot {
  const CreditLedgerTransactionSnapshot({
    required this.transactionId,
    required this.occurredAt,
    this.settlementInAccountId,
    this.paidFromAccountId,
    this.hasRefundChildren = false,
  });

  final String transactionId;
  final DateTime occurredAt;
  final String? settlementInAccountId;
  final String? paidFromAccountId;
  final bool hasRefundChildren;
}

enum CreditLedgerAccountKind { asset, liability, other }

class CreditLedgerRepaymentSnapshot {
  const CreditLedgerRepaymentSnapshot({
    required this.transactionId,
    required this.isDebtRepayment,
    required this.occurredAt,
    required this.details,
    required this.entries,
    this.ownerType,
    this.note,
    this.groupId,
  });

  final String transactionId;
  final bool isDebtRepayment;
  final DateTime occurredAt;
  final String? ownerType;
  final String? note;
  final String? groupId;
  final List<CreditLedgerRepaymentDetail> details;
  final List<CreditLedgerRepaymentEntry> entries;
}

enum CreditLedgerRepaymentDetailType { principal, interest, fee, discount }

class CreditLedgerRepaymentDetail {
  const CreditLedgerRepaymentDetail({required this.type, required this.amount});

  final CreditLedgerRepaymentDetailType type;
  final Money amount;
}

enum CreditLedgerEntryDirection { debit, credit }

class CreditLedgerRepaymentEntry {
  const CreditLedgerRepaymentEntry({
    required this.accountId,
    required this.accountKind,
    required this.direction,
  });

  final String accountId;
  final CreditLedgerAccountKind accountKind;
  final CreditLedgerEntryDirection direction;
}

class CreditLedgerOwnership {
  const CreditLedgerOwnership({required this.ownerType, required this.ownerId});

  final String ownerType;
  final String ownerId;
}

class CreditLedgerCreateLiabilityAccountCommand {
  const CreditLedgerCreateLiabilityAccountCommand({
    required this.name,
    required this.kind,
    required this.openingBalance,
    this.iconKey,
    this.note,
    this.groupId,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final String name;
  final CreditLiabilityAccountKind kind;
  final Money openingBalance;
  final String? iconKey;
  final String? note;
  final String? groupId;
  final int sortOrder;
  final bool isHidden;
}

class CreditLedgerEditLiabilityAccountCommand {
  const CreditLedgerEditLiabilityAccountCommand({
    required this.accountId,
    this.name,
    this.iconKey,
    this.note,
    this.groupId,
    this.targetBalance,
  });

  final String accountId;
  final String? name;
  final Patch<String>? iconKey;
  final Patch<String>? note;
  final Patch<String>? groupId;
  final Money? targetBalance;
}

class CreditLedgerPostRepaymentCommand {
  const CreditLedgerPostRepaymentCommand({
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    required this.amount,
    this.counterpartyId,
    this.note,
    this.ownership,
    this.tagIds = const {},
  });

  final String liabilityAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final RepaymentAmountBreakdown amount;
  final String? counterpartyId;
  final String? note;
  final Set<String> tagIds;
  final CreditLedgerOwnership? ownership;
}

class CreditLedgerPostBorrowingCommand {
  const CreditLedgerPostBorrowingCommand({
    required this.liabilityAccountId,
    required this.receiveAccountId,
    required this.amount,
    required this.occurredAt,
    this.counterpartyId,
    this.note,
    this.ownership,
  });

  final String liabilityAccountId;
  final String receiveAccountId;
  final Money amount;
  final DateTime occurredAt;
  final String? counterpartyId;
  final String? note;
  final CreditLedgerOwnership? ownership;
}

class CreditLedgerEditRepaymentCommand {
  const CreditLedgerEditRepaymentCommand({
    required this.transactionId,
    this.liabilityAccountId,
    this.paidFromAccountId,
    this.occurredAt,
    this.amount,
    this.note,
    this.tagIds,
  });

  final String transactionId;
  final String? liabilityAccountId;
  final String? paidFromAccountId;
  final DateTime? occurredAt;
  final RepaymentAmountBreakdown? amount;
  final Patch<String?>? note;

  /// `null` 表示不改标签；非空集合表示整体替换。
  final Set<String>? tagIds;
}

class CreditLedgerEditBorrowingCommand {
  const CreditLedgerEditBorrowingCommand({
    required this.transactionId,
    this.receiveAccountId,
    this.occurredAt,
  });

  final String transactionId;
  final String? receiveAccountId;
  final DateTime? occurredAt;
}

class CreditLedgerUpdateBasicInfoCommand {
  const CreditLedgerUpdateBasicInfoCommand({
    required this.transactionId,
    this.occurredAt,
    this.note,
  });

  final String transactionId;
  final DateTime? occurredAt;
  final Patch<String?>? note;
}

abstract interface class CreditAccountLedgerPort {
  Future<CreditLedgerAccountSnapshot> createLiabilityAccount(
    CreditLedgerCreateLiabilityAccountCommand command,
  );

  Future<void> editLiabilityAccount(
    CreditLedgerEditLiabilityAccountCommand command,
  );

  Future<void> deleteLiabilityAccount(String accountId);
}

abstract interface class CreditLedgerPort {
  Future<CreditLedgerAccountSnapshot?> findAccount(String accountId);

  Future<CreditLedgerPostedTransaction> postExpense(
    CreditLedgerPostExpenseCommand command,
  );

  Future<CreditLedgerPostedTransaction> postRefund(
    CreditLedgerPostRefundCommand command,
  );

  Future<CreditLedgerPostedTransaction> editRefund(
    CreditLedgerEditRefundCommand command,
  );

  Future<CreditLedgerPostedTransaction> postRepayment(
    CreditLedgerPostRepaymentCommand command,
  );

  Future<CreditLedgerPostedTransaction> postBorrowing(
    CreditLedgerPostBorrowingCommand command,
  );

  Future<CreditLedgerPostedTransaction> editRepayment(
    CreditLedgerEditRepaymentCommand command,
  );

  Future<void> editBorrowing(CreditLedgerEditBorrowingCommand command);

  Future<void> updateBasicInfo(CreditLedgerUpdateBasicInfoCommand command);

  Future<void> updateOwnership({
    required String transactionId,
    required CreditLedgerOwnership ownership,
  });

  Future<void> deleteTransaction(String transactionId);

  Future<CreditLedgerTransactionSnapshot?> findParentTransaction(
    String transactionId,
  );

  Future<CreditLedgerRepaymentSnapshot?> findRepaymentTransaction(
    String transactionId,
  );
}
