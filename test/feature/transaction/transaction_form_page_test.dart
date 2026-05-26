import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/database_provider.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/feature/transaction/page/transaction_form_page.dart';

import '../../helper/test_app_database.dart';

void main() {
  testWidgets('renders seeded expense transaction form content', (
    tester,
  ) async {
    await _pumpTransactionForm(tester);

    expect(find.text('支出'), findsOneWidget);
    expect(find.text('食品餐饮'), findsOneWidget);
    expect(find.text('点击填写备注'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('transfer mode moves account pickers to main content', (
    tester,
  ) async {
    await _pumpTransactionForm(tester);

    await tester.tap(find.text('转账'));
    await tester.pump();

    expect(find.text('转出账户'), findsOneWidget);
    expect(find.text('转入账户'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(find.text('不计收支'), findsNothing);
    expect(find.textContaining('报销账户'), findsNothing);
  });

  testWidgets('borrowing mode shows fund account picker in main content', (
    tester,
  ) async {
    await _pumpTransactionForm(tester);

    await tester.tap(find.text('借入'));
    await tester.pump();

    expect(find.text('借入账户'), findsOneWidget);
    expect(find.text('借出账户'), findsOneWidget);
    expect(find.textContaining('负债账户'), findsNothing);
    expect(find.text('不计收支'), findsNothing);
    expect(find.textContaining('报销账户'), findsNothing);
  });

  testWidgets('expense account picker excludes loan account', (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final walletId = await _insertAccount(
      database,
      name: '钱包',
      type: AccountType.asset,
      subtype: AccountSubtype.cash,
    );
    await _insertAccount(
      database,
      name: '花呗',
      type: AccountType.liability,
      subtype: AccountSubtype.consumerCredit,
    );
    await _insertAccount(
      database,
      name: '借呗',
      type: AccountType.liability,
      subtype: AccountSubtype.loan,
    );

    await _pumpTransactionForm(
      tester,
      database: database,
      initialFromAccountId: walletId,
    );

    await tester.tap(find.text('钱包').last);
    await tester.pumpAndSettle();

    expect(find.text('花呗'), findsWidgets);
    expect(find.text('借呗'), findsNothing);
  });

  testWidgets('transfer account pickers exclude loan account', (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final walletId = await _insertAccount(
      database,
      name: '钱包',
      type: AccountType.asset,
      subtype: AccountSubtype.cash,
    );
    final creditId = await _insertAccount(
      database,
      name: '花呗',
      type: AccountType.liability,
      subtype: AccountSubtype.consumerCredit,
    );
    await _insertAccount(
      database,
      name: '借呗',
      type: AccountType.liability,
      subtype: AccountSubtype.loan,
    );

    await _pumpTransactionForm(
      tester,
      database: database,
      initialFromAccountId: walletId,
      initialToAccountId: creditId,
    );

    await tester.tap(find.text('转账'));
    await tester.pump();
    await tester.tap(find.text('转出账户'));
    await tester.pumpAndSettle();

    expect(find.text('花呗'), findsWidgets);
    expect(find.text('借呗'), findsNothing);
  });

  testWidgets('expense submit keeps default reimbursement as none', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertAccount(
      database,
      name: '钱包',
      type: AccountType.asset,
      subtype: AccountSubtype.cash,
    );
    await _insertAccount(
      database,
      name: '公司报销',
      type: AccountType.asset,
      subtype: AccountSubtype.reimbursement,
    );
    final transactionService = _CapturingTransactionService();

    await _pumpTransactionForm(
      tester,
      database: database,
      transactionService: transactionService,
    );

    await tester.tap(find.text('食品餐饮'));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pump();

    expect(transactionService.expenseCommand, isNotNull);
    expect(transactionService.reimbursementAdvanceCommand, isNull);
  });
}

Future<void> _pumpTransactionForm(
  WidgetTester tester, {
  AppDatabase? database,
  TransactionService? transactionService,
  int? initialFromAccountId,
  int? initialToAccountId,
}) async {
  final appDatabase = database ?? createTestDatabase();
  if (database == null) {
    addTearDown(appDatabase.close);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDatabase),
        if (transactionService != null)
          transactionServiceProvider.overrideWithValue(transactionService),
      ],
      child: MaterialApp(
        home: TransactionFormPage(
          initialFromAccountId: initialFromAccountId,
          initialToAccountId: initialToAccountId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<int> _insertAccount(
  AppDatabase database, {
  required String name,
  required AccountType type,
  AccountSubtype? subtype,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          name: name,
          accountType: type,
          accountSubtype: Value(subtype),
        ),
      );
}

class _CapturingTransactionService implements TransactionService {
  CreateExpenseCommand? expenseCommand;
  CreateReimbursementAdvanceCommand? reimbursementAdvanceCommand;

  @override
  Future<Result<CreatedTransactionResult>> createExpense(
    CreateExpenseCommand command,
  ) async {
    expenseCommand = command;
    return const Result.failure(Failure(message: 'captured'));
  }

  @override
  Future<Result<CreatedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) async {
    reimbursementAdvanceCommand = command;
    return const Result.failure(Failure(message: 'captured'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
