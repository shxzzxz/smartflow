import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';

class CreditLedgerPostedTransaction {
  const CreditLedgerPostedTransaction({
    required this.transactionId,
    required this.rootTransactionId,
  });

  final String transactionId;
  final String rootTransactionId;
}

class CreditLedgerAccountSnapshot {
  const CreditLedgerAccountSnapshot({
    required this.id,
    required this.balance,
    required this.isArchived,
  });

  final String id;
  final Money balance;
  final bool isArchived;
}

class CreditLedgerTransactionSnapshot {
  const CreditLedgerTransactionSnapshot({
    required this.transactionId,
    required this.occurredAt,
  });

  final String transactionId;
  final DateTime occurredAt;
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
  });

  final String transactionId;
  final bool isDebtRepayment;
  final DateTime occurredAt;
  final String? ownerType;
  final String? note;
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
  const CreditLedgerOwnership({
    required this.ownerType,
    required this.ownerId,
    required this.ownerRole,
  });

  final String ownerType;
  final String ownerId;
  final String ownerRole;
}

class CreditLedgerPostRepaymentCommand {
  const CreditLedgerPostRepaymentCommand({
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    required this.amount,
    this.counterpartyName,
    this.note,
    this.ownership,
  });

  final String liabilityAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final RepaymentAmountBreakdown amount;
  final String? counterpartyName;
  final String? note;
  final CreditLedgerOwnership? ownership;
}

class CreditLedgerPostBorrowingCommand {
  const CreditLedgerPostBorrowingCommand({
    required this.liabilityAccountId,
    required this.receiveAccountId,
    required this.amount,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
    this.ownership,
  });

  final String liabilityAccountId;
  final String receiveAccountId;
  final Money amount;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
  final CreditLedgerOwnership? ownership;
}

class CreditLedgerCorrectRepaymentCommand {
  const CreditLedgerCorrectRepaymentCommand({
    required this.transactionId,
    this.liabilityAccountId,
    this.paidFromAccountId,
    this.occurredAt,
    this.amount,
    this.note,
  });

  final String transactionId;
  final String? liabilityAccountId;
  final String? paidFromAccountId;
  final DateTime? occurredAt;
  final RepaymentAmountBreakdown? amount;
  final Patch<String?>? note;
}

class CreditLedgerCorrectBorrowingCommand {
  const CreditLedgerCorrectBorrowingCommand({
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

abstract interface class CreditLedgerPort {
  Future<CreditLedgerAccountSnapshot?> findAccount(String accountId);

  Future<CreditLedgerPostedTransaction> postRepayment(
    CreditLedgerPostRepaymentCommand command,
  );

  Future<CreditLedgerPostedTransaction> postBorrowing(
    CreditLedgerPostBorrowingCommand command,
  );

  Future<CreditLedgerPostedTransaction> correctRepayment(
    CreditLedgerCorrectRepaymentCommand command,
  );

  Future<void> correctBorrowing(CreditLedgerCorrectBorrowingCommand command);

  Future<void> updateBasicInfo(CreditLedgerUpdateBasicInfoCommand command);

  Future<void> updateOwnership({
    required String transactionId,
    required CreditLedgerOwnership ownership,
  });

  Future<void> deleteTransaction(String transactionId);

  Future<CreditLedgerTransactionSnapshot?> findCurrentParentTransactionByRoot(
    String rootTransactionId,
  );

  Future<CreditLedgerRepaymentSnapshot?> findRepaymentTransaction(
    String transactionId,
  );
}
