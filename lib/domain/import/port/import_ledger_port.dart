import '../../../core/money/money.dart';

enum ImportLedgerTargetKind {
  asset,
  liability,
  reimbursement,
  incomeCategory,
  expenseCategory,
  ghost,
  unsupported,
}

class ImportLedgerTarget {
  const ImportLedgerTarget({
    required this.id,
    required this.name,
    required this.displayPath,
    required this.kind,
    required this.isArchived,
  });

  final String id;
  final String name;
  final String displayPath;
  final ImportLedgerTargetKind kind;
  final bool isArchived;
}

class ImportLedgerTargetCreation {
  const ImportLedgerTargetCreation({required this.name, required this.kind});

  final String name;
  final ImportLedgerTargetKind kind;
}

/// Import-owned port into the ledger application facade.
///
/// It deliberately exposes import vocabulary and primitive posting operations
/// instead of leaking ledger repositories or commands into the import domain.
abstract interface class ImportLedgerPort {
  Future<List<ImportLedgerTarget>> listTargets();

  Future<ImportLedgerTarget?> findTarget(String targetId);

  Future<String> createTarget(ImportLedgerTargetCreation creation);

  Future<String> resolveGhostAccountId();

  Future<String> createExpense({
    required Money amount,
    required String paidFromAccountId,
    required String expenseCategoryId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  });

  Future<String> createIncome({
    required Money amount,
    required String receiveAccountId,
    required String incomeCategoryId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  });

  Future<String> createTransfer({
    required Money amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? feeAmount,
    String? note,
  });

  Future<String> createRefund({
    required String topLevelTransactionId,
    required Money amount,
    required String refundToAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createReimbursementAdvance({
    required Money amount,
    required String receivableAccountId,
    required String paidFromAccountId,
    required String expenseCategoryId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  });

  Future<String> createReimbursementReceipt({
    required String topLevelTransactionId,
    required Money amount,
    required String receivableAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> closeReimbursement({
    required String topLevelTransactionId,
    required Money actualReceivedAmount,
    required String receivableAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createRepayment({
    required Money principal,
    required String liabilityAccountId,
    required String paidFromAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? interest,
    Money? fee,
    String? note,
  });

  Future<String> createInterestExpense({
    required Money amount,
    required String paidFromAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createBorrowing({
    required Money amount,
    required String liabilityAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createOpeningBalance({
    required Money amount,
    required String accountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<bool> transactionExists(String topLevelTransactionId);

  Future<void> deleteTopLevelTransaction(String topLevelTransactionId);
}
