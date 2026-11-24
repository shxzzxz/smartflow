import '../../../../core/money/money.dart';
import '../import_models.dart';

class ImportLedgerTarget {
  const ImportLedgerTarget({
    required this.id,
    required this.name,
    required this.displayPath,
    required this.descriptor,
    required this.isArchived,
    this.iconKey,
    this.parentId,
  });

  final String id;
  final String name;
  final String displayPath;
  final ImportTargetDescriptor descriptor;
  final bool isArchived;
  final String? iconKey;
  final String? parentId;
}

class ImportLedgerTargetCreation {
  const ImportLedgerTargetCreation({
    required this.name,
    required this.descriptor,
    this.pathSegments = const [],
    this.parentTargetId,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext = true,
  });

  final String name;
  final ImportTargetDescriptor descriptor;
  final List<String> pathSegments;
  final String? parentTargetId;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
}

/// Import-owned port into the ledger application facade.
///
/// It deliberately exposes import vocabulary and primitive posting operations
/// instead of leaking ledger repositories or commands into the intake import capability.
abstract interface class ImportLedgerPort {
  Future<List<ImportLedgerTarget>> listTargets();

  Future<ImportLedgerTarget?> findTarget(String targetId);

  Future<String> createTarget(ImportLedgerTargetCreation creation);

  Future<String> resolveGhostAccountId();

  Future<String> createExpense({
    String? bookId,
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
    String? bookId,
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
    String? bookId,
    required Money amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? feeAmount,
    String? note,
  });

  Future<String> createRefund({
    String? bookId,
    required String topLevelTransactionId,
    required Money amount,
    required String refundToAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createAdvance({
    String? bookId,
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

  Future<String> createAdvanceCollection({
    String? bookId,
    required String topLevelTransactionId,
    required Money amount,
    required String receivableAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> settleAdvance({
    String? bookId,
    required String topLevelTransactionId,
    required Money actualReceivedAmount,
    required String receivableAccountId,
    required String receiveAccountId,

    /// The source category to use for an imported shortfall, when the source
    /// explicitly defines one. The ledger adapter resolves the amount from
    /// the transaction group's current outstanding balance.
    String? gapExpenseCategoryId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createRepayment({
    String? bookId,
    required Money principal,
    required String liabilityAccountId,
    required String paidFromAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? interest,
    Money? fee,
    Money? discount,
    String? note,
  });

  Future<String> createInterestExpense({
    String? bookId,
    required Money amount,
    required String paidFromAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createBorrowing({
    String? bookId,
    required Money amount,
    required String liabilityAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createLending({
    String? bookId,
    required Money amount,
    required String receivableAccountId,
    required String paidFromAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<String> createReceivableCollection({
    String? bookId,
    required Money principal,
    required String receivableAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? interest,
    String? note,
  });

  Future<String> createOpeningBalance({
    String? bookId,
    required Money amount,
    required String accountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  });

  Future<bool> transactionExists(String topLevelTransactionId);

  Future<void> deleteTopLevelTransaction(String topLevelTransactionId);
}
