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
