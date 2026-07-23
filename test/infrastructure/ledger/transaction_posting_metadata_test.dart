import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_command.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_posting_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  test('creation commands persist import source and posted time', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertAccount(database, 'cash', AccountType.asset);
    await _insertAccount(database, 'food', AccountType.expense);
    await _insertAccount(database, 'loan', AccountType.liability);

    final ids = SequentialIdGenerator(prefix: 'posting');
    final accounts = DriftAccountRepository(database);
    final postings = DriftPostingRepository(database);
    final writer = TransactionLedgerWriter(
      transactionRunner: DriftTransactionRunner(database),
      transactionRepository: postings,
      transactionGroupRepository: postings,
      accountRepository: accounts,
    );
    final service = TransactionPostingAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: postings,
      systemAccountResolver: DriftSystemAccountResolver(database),
      ledgerWriter: writer,
      idGenerator: ids,
    );

    final expense = await service.createExpense(
      CreateExpenseCommand(
        amount: Money.parse('25.00'),
        paidFromAccountId: 'cash',
        expenseAccountId: 'food',
        occurredAt: DateTime(2026, 4, 1, 9),
        postedAt: DateTime(2026, 4, 2, 18),
        sourceKind: SourceKind.import,
      ),
    );
    final opening = await service.createOpeningBalance(
      CreateOpeningBalanceCommand(
        accountId: 'loan',
        amount: Money.parse('100.00'),
        occurredAt: DateTime(2026, 3, 1),
        postedAt: DateTime(2026, 3, 2),
        sourceKind: SourceKind.import,
      ),
    );

    final expenseTransaction = await postings.findById(expense.transactionId);
    final openingTransaction = await postings.findById(opening.transactionId);
    expect(expenseTransaction!.sourceKind, SourceKind.import);
    expect(expenseTransaction.postedAt, DateTime(2026, 4, 2, 18));
    expect(openingTransaction!.sourceKind, SourceKind.import);
    expect(openingTransaction.postedAt, DateTime(2026, 3, 2));
  });
}

Future<void> _insertAccount(
  AppDatabase database,
  String id,
  AccountType type,
) async {
  await database
      .into(database.accounts)
      .insert(AccountsCompanion.insert(id: id, name: id, accountType: type));
}
