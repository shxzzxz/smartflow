import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_form_page.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';

void main() {
  testWidgets('keeps transaction mode tabs at least 48dp tall', (tester) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    for (final label in const ['支出', '收入', '转账', '借入']) {
      final tab = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('uses standardized account roles for borrowing', (tester) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    await tester.tap(find.text('借入'));
    await tester.pumpAndSettle();

    expect(find.text('负债账户'), findsOneWidget);
    expect(find.text('收款账户'), findsOneWidget);
    expect(find.text('借出账户'), findsNothing);
    expect(find.text('借入账户'), findsNothing);
  });

  testWidgets('renders on a common Android phone with accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      themeMode: ThemeMode.dark,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(TransactionAmountInput), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(TransactionFormPage))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

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

  testWidgets(
    'places a direct fee input below transfer accounts without overlapping the amount panel',
    (tester) async {
      // Pin this geometry assertion to the target phone viewport instead of the
      // default 800x600 test view.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

      expect(find.byKey(const ValueKey('transfer-fee-input')), findsNothing);

      await tester.tap(find.text('转账'));
      await tester.pumpAndSettle();

      final feeInput = find.byKey(const ValueKey('transfer-fee-input'));
      final toAccountTile = find.byKey(
        const ValueKey('transfer-to-account-tile'),
      );
      final amountInput = find.byType(TransactionAmountInput);

      expect(feeInput, findsOneWidget);
      expect(toAccountTile, findsOneWidget);
      expect(amountInput, findsOneWidget);
      expect(find.text('手续费'), findsOneWidget);
      expect(find.text('转出账户'), findsOneWidget);
      expect(find.text('转入账户'), findsOneWidget);
      final feeIcon = tester.widget<BusinessIcon>(
        find.descendant(of: feeInput, matching: find.byType(BusinessIcon)),
      );
      expect(feeIcon.iconKey, 'swap-box-line');
      expect(feeIcon.usage, BusinessIconUsage.system);
      expect(
        find.descendant(of: feeInput, matching: find.text('0.00')),
        findsOneWidget,
      );
      expect(find.text('0.00（可选）'), findsNothing);
      final feeRect = tester.getRect(feeInput);
      final toAccountRect = tester.getRect(toAccountTile);
      final amountRect = tester.getRect(amountInput);
      expect(feeRect.top, greaterThanOrEqualTo(toAccountRect.bottom));
      expect(feeRect.bottom, lessThanOrEqualTo(amountRect.top));
      expect(
        find.descendant(of: feeInput, matching: find.text('¥')),
        findsNothing,
      );
    },
  );

  testWidgets('places the tag action on the row below other options', (
    tester,
  ) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    final dateText = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(
            r'^(今天|\d{1,2}/\d{1,2}) \d{2}:\d{2}$',
          ).hasMatch(widget.data ?? ''),
    );
    expect(dateText, findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('标签')).dy,
      greaterThan(tester.getTopLeft(dateText).dy),
    );
  });

  testWidgets('renders selected tags as badges that can be edited', (
    tester,
  ) async {
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      tags: const [
        TagView(id: 'tag-1', name: '工作', sortOrder: 0, usageCount: 1),
        TagView(id: 'tag-2', name: '旅行', sortOrder: 1, usageCount: 0),
      ],
    );

    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作'));
    await tester.tap(find.text('旅行'));
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, '工作'), findsOneWidget);
    expect(find.widgetWithText(Chip, '旅行'), findsOneWidget);
    expect(find.text('工作、旅行'), findsNothing);

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();
    expect(find.text('选择标签'), findsOneWidget);
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
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.ordinaryReceivable,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        categoryTreeProvider(
          AccountType.expense,
        ).overrideWithValue(const AsyncLoading<List<CategoryNode>>()),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWithValue(const AsyncLoading<List<CategoryNode>>()),
        tagListProvider.overrideWithValue(const AsyncLoading<List<TagView>>()),
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
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.ordinaryReceivable,
    ).overrideWithValue(const AsyncData(<Account>[])),
    categoryTreeProvider(
      AccountType.expense,
    ).overrideWithValue(AsyncData([CategoryNode(account: accounts['food']!)])),
    categoryTreeProvider(
      AccountType.income,
    ).overrideWithValue(const AsyncData(<CategoryNode>[])),
    accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
    tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
    transactionTagIdsProvider(
      'tx-1',
    ).overrideWithValue(const AsyncData(<String>{})),
    transactionTagIdsProvider(
      'tx-a',
    ).overrideWithValue(const AsyncData(<String>{})),
    transactionTagIdsProvider(
      'tx-b',
    ).overrideWithValue(const AsyncData(<String>{})),
  ];
}

Future<void> _pumpTransactionForm(
  WidgetTester tester,
  _FakeTransactionPostingAppService fakeService, {
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
  List<TagView> tags = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
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
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.ordinaryReceivable,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        categoryTreeProvider(AccountType.expense).overrideWith(
          (ref) => Stream.value([CategoryNode(account: _category('food'))]),
        ),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        tagListProvider.overrideWith((ref) => Stream.value(tags)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        routerConfig: router,
      ),
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
    lines: const [],
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
