import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_form_page.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';

void main() {
  testWidgets('form validator blocks invalid daily expense submit', (
    tester,
  ) async {
    final fakeService = _FakeTransactionPostingAppService();
    await _pumpTransactionForm(tester, fakeService);

    await tester.tap(find.text('完成'));
    await tester.pump();

    expect(find.text('请输入有效金额'), findsOneWidget);
    expect(fakeService.commands, isEmpty);
  });

  testWidgets('submits the latest view-owned amount and note text', (
    tester,
  ) async {
    final fakeService = _FakeTransactionPostingAppService();
    await _pumpTransactionForm(tester, fakeService);

    await tester.tap(find.text('food'));
    await tester.tap(find.text('1'));
    await tester.pump();
    final noteField = find.byWidgetPredicate(
      (widget) => widget is TextField && !widget.readOnly,
    );
    await tester.enterText(noteField, '午餐');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final command = fakeService.commands.single;
    expect(command.amount, const Money(minorUnits: 100));
    expect(command.note, '午餐');
  });

  testWidgets('uses the shared transaction amount input', (tester) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    expect(find.byType(TransactionAmountInput), findsOneWidget);
  });

  testWidgets('new form renders while option queries are loading', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.settlement,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.fund,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.borrowingLiability,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.reimbursementReceivable,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        categoryTreeProvider(
          AccountType.expense,
        ).overrideWithValue(const AsyncLoading<List<CategoryNode>>()),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWithValue(const AsyncLoading<List<CategoryNode>>()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TransactionFormPage()),
      ),
    );

    expect(find.byType(TransactionAmountInput), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'shows edit loading, initializes controllers, and preserves edited text',
    (tester) async {
      final details = StreamController<TransactionDetail?>();
      addTearDown(details.close);
      final accounts = {'cash': _account('cash'), 'food': _category('food')};
      final container = ProviderContainer(
        overrides: [
          ..._editQueryOverrides(accounts),
          transactionDetailProvider(
            'tx-1',
          ).overrideWith((ref) => details.stream),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransactionFormPage(editTransactionId: 'tx-1'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      details.add(_transactionDetail('tx-1', note: '原始备注'));
      await tester.pumpAndSettle();

      var input = tester.widget<TransactionAmountInput>(
        find.byType(TransactionAmountInput),
      );
      expect(input.amountController.text, '12.34');
      expect(input.noteController.text, '原始备注');

      input.amountController.text = '99.99';
      input.noteController.text = '用户正在编辑';
      container
          .read(
            transactionFormViewModelProvider(
              editTransactionId: 'tx-1',
            ).notifier,
          )
          .setExcludeStats(true);
      await tester.pump();

      input = tester.widget<TransactionAmountInput>(
        find.byType(TransactionAmountInput),
      );
      expect(input.amountController.text, '99.99');
      expect(input.noteController.text, '用户正在编辑');
    },
  );

  testWidgets('does not reuse controllers between transaction ids', (
    tester,
  ) async {
    final accounts = {'cash': _account('cash'), 'food': _category('food')};
    final container = ProviderContainer(
      overrides: [
        ..._editQueryOverrides(accounts),
        transactionDetailProvider('tx-a').overrideWithValue(
          AsyncData(_transactionDetail('tx-a', note: '交易 A')),
        ),
        transactionDetailProvider('tx-b').overrideWithValue(
          AsyncData(
            _transactionDetail(
              'tx-b',
              amount: const Money(minorUnits: 5678),
              note: '交易 B',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    var activeId = 'tx-a';
    late StateSetter setPage;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setPage = setState;
              return TransactionFormPage(editTransactionId: activeId);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    var input = tester.widget<TransactionAmountInput>(
      find.byType(TransactionAmountInput),
    );
    input.amountController.text = '88.88';
    input.noteController.text = '交易 A 的临时修改';

    setPage(() => activeId = 'tx-b');
    await tester.pump();

    input = tester.widget<TransactionAmountInput>(
      find.byType(TransactionAmountInput),
    );
    expect(input.amountController.text, '56.78');
    expect(input.noteController.text, '交易 B');
  });
}

List<dynamic> _editQueryOverrides(Map<String, Account> accounts) {
  return [
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.settlement,
    ).overrideWithValue(AsyncData([accounts['cash']!])),
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.fund,
    ).overrideWithValue(const AsyncData(<Account>[])),
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.borrowingLiability,
    ).overrideWithValue(const AsyncData(<Account>[])),
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.reimbursementReceivable,
    ).overrideWithValue(const AsyncData(<Account>[])),
    categoryTreeProvider(
      AccountType.expense,
    ).overrideWithValue(AsyncData([CategoryNode(account: accounts['food']!)])),
    categoryTreeProvider(
      AccountType.income,
    ).overrideWithValue(const AsyncData(<CategoryNode>[])),
    accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
  ];
}

Future<void> _pumpTransactionForm(
  WidgetTester tester,
  _FakeTransactionPostingAppService fakeService,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder:
            (context, state) => Scaffold(
              body: TextButton(
                key: const ValueKey('open-transaction-form'),
                onPressed: () => context.push('/form'),
                child: const Text('打开表单'),
              ),
            ),
      ),
      GoRoute(
        path: '/form',
        builder: (context, state) => const TransactionFormPage(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionPostingAppServiceProvider.overrideWithValue(fakeService),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.settlement,
        ).overrideWith((ref) => Stream.value([_account('cash')])),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.fund,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.borrowingLiability,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.reimbursementReceivable,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        categoryTreeProvider(AccountType.expense).overrideWith(
          (ref) => Stream.value([CategoryNode(account: _category('food'))]),
        ),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-transaction-form')));
  await tester.pumpAndSettle();
}

Account _account(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}

Account _category(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.expense,
    balance: const Money(minorUnits: 0),
  );
}

TransactionDetail _transactionDetail(
  String id, {
  Money amount = const Money(minorUnits: 1234),
  String note = 'note',
}) {
  final entries = [
    Entry(
      id: '$id-food',
      transactionId: id,
      accountId: 'food',
      direction: EntryDirection.debit,
      amount: amount,
    ),
    Entry(
      id: '$id-cash',
      transactionId: id,
      accountId: 'cash',
      direction: EntryDirection.credit,
      amount: amount,
    ),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: id,
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 2, 8, 30),
      primaryAmount: amount,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      note: note,
      entries: entries,
    ),
    createdAt: DateTime(2026, 1, 2, 8, 30),
    details: const [],
    entries: entries,
  );
}

class _FakeTransactionPostingAppService
    implements TransactionPostingAppService {
  final commands = <CreateExpenseCommand>[];

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
    commands.add(command);
    return const PostedTransactionResult(transactionId: 'transaction-1');
  }

  @override
  Future<PostedTransactionResult> adjustBalance(AdjustBalanceCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> closeReimbursement(
    CloseReimbursementCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createIncome(CreateIncomeCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRefund(CreateRefundCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createTransfer(
    CreateTransferCommand command,
  ) {
    throw UnimplementedError();
  }
}
