import '../../application/ledger/account/query/account_query_service.dart';
import '../../application/ledger/transaction/command/transaction_command.dart';
import '../../application/ledger/transaction/command/transaction_edit_app_service.dart';
import '../../application/ledger/transaction/command/transaction_posting_app_service.dart';
import '../../application/ledger/transaction/query/transaction_query_service.dart';
import '../../core/money/money.dart';
import '../../domain/import/port/import_ledger_port.dart';
import '../../domain/ledger/entity/account.dart';
import '../../domain/ledger/port/system_account_resolver.dart';
import '../../domain/ledger/valobj/ledger_enum.dart';

class LedgerImportPort implements ImportLedgerPort {
  const LedgerImportPort({
    required TransactionPostingAppService posting,
    required TransactionEditAppService editing,
    required TransactionQueryService transactions,
    required AccountQueryService accounts,
    required SystemAccountResolver systemAccounts,
  }) : _posting = posting,
       _editing = editing,
       _transactions = transactions,
       _accounts = accounts,
       _systemAccounts = systemAccounts;

  final TransactionPostingAppService _posting;
  final TransactionEditAppService _editing;
  final TransactionQueryService _transactions;
  final AccountQueryService _accounts;
  final SystemAccountResolver _systemAccounts;

  @override
  Future<List<ImportLedgerTarget>> listTargets() async {
    final accounts =
        await _accounts.watchAccounts(AccountType.values.toSet()).first;
    final byId = {for (final account in accounts) account.id: account};
    return [
      for (final account in accounts)
        _target(
          account,
          parentName:
              account.parentId == null ? null : byId[account.parentId]?.name,
        ),
    ];
  }

  @override
  Future<ImportLedgerTarget?> findTarget(String targetId) async {
    final account = await _accounts.findAccountById(targetId);
    if (account == null) return null;
    final parent =
        account.parentId == null
            ? null
            : await _accounts.findAccountById(account.parentId!);
    return _target(account, parentName: parent?.name);
  }

  @override
  Future<String> resolveGhostAccountId() =>
      _systemAccounts.resolveGhostAccount();

  @override
  Future<String> createExpense({
    required Money amount,
    required String paidFromAccountId,
    required String expenseCategoryId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) async {
    final result = await _posting.createExpense(
      CreateExpenseCommand(
        amount: amount,
        paidFromAccountId: paidFromAccountId,
        expenseAccountId: expenseCategoryId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        sourceKind: SourceKind.import,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> createIncome({
    required Money amount,
    required String receiveAccountId,
    required String incomeCategoryId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) async {
    final result = await _posting.createIncome(
      CreateIncomeCommand(
        amount: amount,
        receiveAccountId: receiveAccountId,
        incomeAccountId: incomeCategoryId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        sourceKind: SourceKind.import,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> createTransfer({
    required Money amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? feeAmount,
    String? note,
  }) async {
    final result = await _posting.createTransfer(
      CreateTransferCommand(
        amount: amount,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        feeAmount: feeAmount,
        note: note,
        sourceKind: SourceKind.import,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> createRefund({
    required String topLevelTransactionId,
    required Money amount,
    required String refundToAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  }) async {
    final result = await _posting.createRefund(
      CreateRefundCommand(
        amount: amount,
        parentTransactionId: topLevelTransactionId,
        refundToAccountId: refundToAccountId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      ),
    );
    return result.transactionId;
  }

  @override
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
  }) async {
    final result = await _posting.createReimbursementAdvance(
      CreateReimbursementAdvanceCommand(
        amount: amount,
        receivableAccountId: receivableAccountId,
        paidFromAccountId: paidFromAccountId,
        expenseCategoryId: expenseCategoryId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        sourceKind: SourceKind.import,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> createReimbursementReceipt({
    required String topLevelTransactionId,
    required Money amount,
    required String receivableAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  }) async {
    final result = await _posting.createReimbursementReceipt(
      CreateReimbursementReceiptCommand(
        amount: amount,
        advanceTransactionId: topLevelTransactionId,
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> closeReimbursement({
    required String topLevelTransactionId,
    required Money actualReceivedAmount,
    required String receivableAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  }) async {
    final result = await _posting.closeReimbursement(
      CloseReimbursementCommand(
        actualReceivedAmount: actualReceivedAmount,
        advanceTransactionId: topLevelTransactionId,
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> createRepayment({
    required Money principal,
    required String liabilityAccountId,
    required String paidFromAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? interest,
    Money? fee,
    String? note,
  }) async {
    final result = await _posting.createRepayment(
      CreateRepaymentCommand(
        principal: principal,
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: paidFromAccountId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        interest: interest,
        fee: fee,
        note: note,
        sourceKind: SourceKind.import,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> createInterestExpense({
    required Money amount,
    required String paidFromAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  }) async {
    final categoryId = await _systemAccounts.resolveInterestExpense();
    return createExpense(
      amount: amount,
      paidFromAccountId: paidFromAccountId,
      expenseCategoryId: categoryId,
      occurredAt: occurredAt,
      postedAt: postedAt,
      note: note,
    );
  }

  @override
  Future<String> createBorrowing({
    required Money amount,
    required String liabilityAccountId,
    required String receiveAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  }) async {
    final result = await _posting.createBorrowing(
      CreateBorrowingCommand(
        amount: amount,
        liabilityAccountId: liabilityAccountId,
        receiveAccountId: receiveAccountId,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        sourceKind: SourceKind.import,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> createOpeningBalance({
    required Money amount,
    required String accountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    String? note,
  }) async {
    final result = await _posting.createOpeningBalance(
      CreateOpeningBalanceCommand(
        accountId: accountId,
        amount: amount,
        occurredAt: occurredAt,
        postedAt: postedAt,
        note: note,
        sourceKind: SourceKind.import,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<bool> transactionExists(String topLevelTransactionId) async {
    final transaction = await _transactions.findTransactionById(
      topLevelTransactionId,
    );
    return transaction != null && transaction.parentTransactionId == null;
  }

  @override
  Future<void> deleteTopLevelTransaction(String topLevelTransactionId) {
    return _editing.deleteTransaction(
      DeleteTransactionCommand(transactionId: topLevelTransactionId),
    );
  }

  ImportLedgerTarget _target(Account account, {String? parentName}) {
    final kind = switch ((account.type, account.subtype, account.systemKey)) {
      (_, _, SystemKey.ghostAccount) => ImportLedgerTargetKind.ghost,
      (AccountType.asset, AccountSubtype.reimbursement, _) =>
        ImportLedgerTargetKind.reimbursement,
      (AccountType.asset, _, _) => ImportLedgerTargetKind.asset,
      (AccountType.liability, _, _) => ImportLedgerTargetKind.liability,
      (AccountType.income, _, _) => ImportLedgerTargetKind.incomeCategory,
      (AccountType.expense, _, _) => ImportLedgerTargetKind.expenseCategory,
      _ => ImportLedgerTargetKind.unsupported,
    };
    return ImportLedgerTarget(
      id: account.id,
      name: account.name,
      displayPath:
          parentName == null ? account.name : '$parentName / ${account.name}',
      kind: kind,
      isArchived: account.isArchived,
    );
  }
}
