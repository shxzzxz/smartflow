import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_form_page.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

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

  testWidgets('number pad and note controller sync to view model', (
    tester,
  ) async {
    final fakeService = _FakeTransactionPostingAppService();
    await _pumpTransactionForm(tester, fakeService);

    await tester.tap(find.text('1'));
    await tester.pump();
    final noteField = find.byWidgetPredicate(
      (widget) => widget is TextField && !widget.readOnly,
    );
    await tester.enterText(noteField, '午餐');
    await tester.pump();

    final state = tester.container().read(transactionFormViewModelProvider);
    expect(state.amountText, '1');
    expect(state.noteText, '午餐');
  });
}

Future<void> _pumpTransactionForm(
  WidgetTester tester,
  _FakeTransactionPostingAppService fakeService,
) async {
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
      child: const MaterialApp(home: TransactionFormPage()),
    ),
  );
  await tester.pump();
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
    return const PostedTransactionResult(
      transactionId: 'transaction-1',
      rootTransactionId: 'transaction-1',
    );
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
