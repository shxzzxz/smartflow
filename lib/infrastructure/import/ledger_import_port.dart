import '../../application/ledger/account/command/account_app_service.dart';
import '../../application/ledger/account/command/account_command.dart';
import '../../application/ledger/account/query/account_query_service.dart';
import '../../application/ledger/category/command/category_app_service.dart';
import '../../application/ledger/category/command/category_command.dart';
import '../../application/ledger/transaction/command/transaction_command.dart';
import '../../application/ledger/transaction/command/transaction_edit_app_service.dart';
import '../../application/ledger/transaction/command/transaction_posting_app_service.dart';
import '../../application/ledger/transaction/query/transaction_query_service.dart';
import '../../core/money/money.dart';
import '../../application/credit/account/command/credit_account_app_service.dart';
import '../../application/credit/account/command/credit_account_command.dart';
import '../../domain/import/port/import_ledger_port.dart';
import '../../domain/import/import_models.dart';
import '../../domain/ledger/entity/account.dart';
import '../../domain/ledger/port/system_account_resolver.dart';
import '../../domain/ledger/valobj/ledger_enum.dart';
import '../../domain/credit/valobj/credit_account_enums.dart';
import '../../shared/account_profile/account_profile_kind.dart';

class LedgerImportPort implements ImportLedgerPort {
  const LedgerImportPort({
    required TransactionPostingAppService posting,
    required TransactionEditAppService editing,
    required TransactionQueryService transactions,
    required AccountQueryService accounts,
    required AccountAppService accountCommands,
    required CategoryAppService categoryCommands,
    required SystemAccountResolver systemAccounts,
    CreditAccountAppService? creditAccounts,
  }) : _posting = posting,
       _editing = editing,
       _transactions = transactions,
       _accounts = accounts,
       _accountCommands = accountCommands,
       _categoryCommands = categoryCommands,
       _systemAccounts = systemAccounts,
       _creditAccounts = creditAccounts;

  final TransactionPostingAppService _posting;
  final TransactionEditAppService _editing;
  final TransactionQueryService _transactions;
  final AccountQueryService _accounts;
  final AccountAppService _accountCommands;
  final CategoryAppService _categoryCommands;
  final SystemAccountResolver _systemAccounts;
  final CreditAccountAppService? _creditAccounts;

  @override
  Future<List<ImportLedgerTarget>> listTargets() async {
    final accounts =
        await _accounts.watchAccounts(AccountType.values.toSet()).first;
    final byId = {for (final account in accounts) account.id: account};
    return [
      for (final account in accounts)
        _target(account, parentName: _parentPath(account, byId)),
    ];
  }

  @override
  Future<ImportLedgerTarget?> findTarget(String targetId) async {
    final account = await _accounts.findAccountById(targetId);
    if (account == null) return null;
    final all = await _accounts.watchAccounts(AccountType.values.toSet()).first;
    final byId = {for (final item in all) item.id: item};
    return _target(account, parentName: _parentPath(account, byId));
  }

  @override
  Future<String> createTarget(ImportLedgerTargetCreation creation) async {
    return switch (creation.effectiveDescriptor) {
      ImportTargetDescriptor.fundAccount =>
        (await _accountCommands.createAccount(
          CreateAccountCommand(
            name: creation.name,
            type: AccountType.asset,
            subtype: AccountSubtype.fund,
            profileKey: AccountProfileKind.fund.key,
          ),
        )).id,
      ImportTargetDescriptor.reimbursementAccount =>
        (await _accountCommands.createAccount(
          CreateAccountCommand(
            name: creation.name,
            type: AccountType.asset,
            subtype: AccountSubtype.receivable,
            profileKey: AccountProfileKind.reimbursement.key,
          ),
        )).id,
      ImportTargetDescriptor.creditAccount => _createCreditTarget(
        creation,
        CreditLiabilityAccountKind.credit,
      ),
      ImportTargetDescriptor.loanAccount => _createCreditTarget(
        creation,
        CreditLiabilityAccountKind.loan,
      ),
      ImportTargetDescriptor.incomeCategory =>
        (await _categoryCommands.createCategory(
          CreateCategoryCommand(
            name: creation.name,
            type: AccountType.income,
            parentId: creation.parentTargetId,
          ),
        )).id,
      ImportTargetDescriptor.expenseCategory =>
        (await _categoryCommands.createCategory(
          CreateCategoryCommand(
            name: creation.name,
            type: AccountType.expense,
            parentId: creation.parentTargetId,
          ),
        )).id,
      ImportTargetDescriptor.ghostAccount ||
      ImportTargetDescriptor.unsupported =>
        throw ArgumentError.value(
          creation.kind,
          'creation.kind',
          'The requested mapping target kind cannot be created.',
        ),
    };
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
    Money? discount,
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
        discount: discount,
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
      (AccountType.asset, AccountSubtype.receivable, _) =>
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
      descriptor: _descriptorForAccount(account),
    );
  }

  Future<String> _createCreditTarget(
    ImportLedgerTargetCreation creation,
    CreditLiabilityAccountKind kind,
  ) async {
    final creditAccounts = _creditAccounts;
    if (creditAccounts == null) {
      throw StateError(
        'Credit account application is not configured for import.',
      );
    }
    final snapshot = await creditAccounts.createAccount(
      CreateCreditLiabilityAccountCommand(
        name: creation.name,
        kind: kind,
        billingDay:
            kind == CreditLiabilityAccountKind.credit
                ? creation.billingDay
                : null,
        repaymentDay:
            kind == CreditLiabilityAccountKind.credit
                ? creation.repaymentDay
                : null,
        billingDayToNext: creation.billingDayToNext,
      ),
    );
    return snapshot.id;
  }

  String? _parentPath(Account account, Map<String, Account> byId) {
    final parts = <String>[];
    var parentId = account.parentId;
    while (parentId != null) {
      final parent = byId[parentId];
      if (parent == null) break;
      parts.insert(0, parent.name);
      parentId = parent.parentId;
    }
    return parts.isEmpty ? null : parts.join(' / ');
  }

  ImportTargetDescriptor _descriptorForAccount(Account account) {
    final profile = AccountProfileKind.fromKey(account.profileKey);
    if (profile != null) {
      return switch (profile) {
        AccountProfileKind.fund => ImportTargetDescriptor.fundAccount,
        AccountProfileKind.reimbursement =>
          ImportTargetDescriptor.reimbursementAccount,
        AccountProfileKind.receivable => ImportTargetDescriptor.fundAccount,
        AccountProfileKind.payable => ImportTargetDescriptor.creditAccount,
        AccountProfileKind.credit => ImportTargetDescriptor.creditAccount,
        AccountProfileKind.loan => ImportTargetDescriptor.loanAccount,
      };
    }
    return switch ((account.type, account.subtype, account.systemKey)) {
      (_, _, SystemKey.ghostAccount) => ImportTargetDescriptor.ghostAccount,
      (AccountType.asset, AccountSubtype.receivable, _) =>
        ImportTargetDescriptor.reimbursementAccount,
      (AccountType.asset, _, _) => ImportTargetDescriptor.fundAccount,
      // AccountType.liability alone does not identify a credit card versus a
      // loan.  The import mapping must rely on an explicit account profile.
      (AccountType.liability, _, _) => ImportTargetDescriptor.unsupported,
      (AccountType.income, _, _) => ImportTargetDescriptor.incomeCategory,
      (AccountType.expense, _, _) => ImportTargetDescriptor.expenseCategory,
      _ => ImportTargetDescriptor.unsupported,
    };
  }
}
