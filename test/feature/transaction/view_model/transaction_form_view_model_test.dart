import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_presentation.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';

void main() {
  group('TransactionFormViewModel', () {
    test('creates daily expense command and returns success', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(postingService: posting);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      viewModel
        ..setOccurredAt(DateTime(2026, 1, 2, 8, 30))
        ..setExpenseCategory(rootId: 'food', categoryId: 'lunch')
        ..setFromAccountId('cash')
        ..setExcludeStats(true)
        ..setExcludeBudget(true);

      final outcome = await viewModel.submit(
        _options(
          amountText: '12.34',
          noteText: ' lunch ',
          settlementAccounts: [_account('cash')],
        ),
      );

      expect(outcome, isA<SubmitSuccess>());
      expect(
        container.read(transactionFormViewModelProvider).submitting,
        false,
      );
      final command = posting.expenseCommands.single;
      expect(command.amount, const Money(minorUnits: 1234));
      expect(command.paidFromAccountId, 'cash');
      expect(command.expenseAccountId, 'lunch');
      expect(command.occurredAt, DateTime(2026, 1, 2, 8, 30));
      expect(command.note, 'lunch');
      expect(command.isExcludedFromStats, true);
      expect(command.isExcludedFromBudget, true);
    });

    test(
      'creates reimbursement advance command when account is selected',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final container = _container(postingService: posting);
        final viewModel = container.read(
          transactionFormViewModelProvider.notifier,
        );

        viewModel
          ..setExpenseCategory(rootId: 'travel', categoryId: 'taxi')
          ..setFromAccountId('cash')
          ..setReimbursementAccountId('company');

        final outcome = await viewModel.submit(
          _options(
            amountText: '20',
            settlementAccounts: [_account('cash')],
            reimbursementAccounts: [_account('company')],
          ),
        );

        expect(outcome, isA<SubmitSuccess>());
        final command = posting.reimbursementAdvanceCommands.single;
        expect(command.amount, const Money(minorUnits: 2000));
        expect(command.paidFromAccountId, 'cash');
        expect(command.receivableAccountId, 'company');
        expect(command.expenseCategoryId, 'taxi');
      },
    );

    test('creates income command', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(postingService: posting);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      viewModel
        ..setMode(TransactionFormMode.income)
        ..setIncomeCategory(rootId: 'salary', categoryId: 'salary')
        ..setToAccountId('bank')
        ..setExcludeStats(true);

      final outcome = await viewModel.submit(
        _options(amountText: '88', settlementAccounts: [_account('bank')]),
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = posting.incomeCommands.single;
      expect(command.amount, const Money(minorUnits: 8800));
      expect(command.receiveAccountId, 'bank');
      expect(command.incomeAccountId, 'salary');
      expect(command.isExcludedFromStats, true);
    });

    test('creates transfer command', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(postingService: posting);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      viewModel
        ..setMode(TransactionFormMode.transfer)
        ..setFromAccountId('cash')
        ..setToAccountId('bank');

      final outcome = await viewModel.submit(
        _options(
          amountText: '50',
          settlementAccounts: [_account('cash'), _account('bank')],
        ),
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = posting.transferCommands.single;
      expect(command.fromAccountId, 'cash');
      expect(command.toAccountId, 'bank');
    });

    test('creates borrowing command', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(postingService: posting);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      viewModel
        ..setMode(TransactionFormMode.borrowing)
        ..setLiabilityAccountId('loan')
        ..setToAccountId('bank');

      final outcome = await viewModel.submit(
        _options(
          amountText: '100',
          fundAccounts: [_account('bank')],
          liabilityAccounts: [_account('loan', type: AccountType.liability)],
        ),
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = posting.borrowingCommands.single;
      expect(command.liabilityAccountId, 'loan');
      expect(command.receiveAccountId, 'bank');
    });

    test(
      'returns failure and skips service when command state is incomplete',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final container = _container(postingService: posting);
        final viewModel = container.read(
          transactionFormViewModelProvider.notifier,
        );

        final outcome = await viewModel.submit(
          _options(settlementAccounts: [_account('cash')]),
        );

        expect(outcome, isA<SubmitFailure>());
        final failure = outcome as SubmitFailure;
        expect(
          failure.error.code,
          LedgerErrorCode.transactionInvalidCommand.code,
        );
        expect(failure.error.message, '请选择支出分类');
        expect(posting.expenseCommands, isEmpty);
      },
    );

    test('maps business exceptions to submit failure', () async {
      final posting = _FakeTransactionPostingAppService(
        exception: BusinessException(
          LedgerErrorCode.accountInvalidRole,
          message: '账户不能用于当前交易。',
        ),
      );
      final container = _container(postingService: posting);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );
      _fillValidDailyExpense(viewModel);

      final outcome = await viewModel.submit(
        _options(settlementAccounts: [_account('cash')]),
      );

      expect(outcome, isA<SubmitFailure>());
      final failure = outcome as SubmitFailure;
      expect(failure.error.code, LedgerErrorCode.accountInvalidRole.code);
      expect(failure.error.message, '账户不能用于当前交易。');
      expect(
        container.read(transactionFormViewModelProvider).submitting,
        false,
      );
    });

    test('rethrows unexpected exceptions after resetting submitting', () async {
      final unexpected = StateError('unexpected');
      final posting = _FakeTransactionPostingAppService(exception: unexpected);
      final container = _container(postingService: posting);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );
      _fillValidDailyExpense(viewModel);

      await expectLater(
        () =>
            viewModel.submit(_options(settlementAccounts: [_account('cash')])),
        throwsA(same(unexpected)),
      );
      expect(
        container.read(transactionFormViewModelProvider).submitting,
        false,
      );
    });

    test('initializes edit state idempotently', () {
      final container = _container();
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      viewModel.initializeForEdit(
        transactionId: 'tx-1',
        snapshot: TransactionFormEditSnapshot(
          mode: TransactionFormMode.income,
          amountText: '10.00',
          noteText: 'salary',
          occurredAt: DateTime(2026, 2, 3),
          excludeStats: true,
          excludeBudget: false,
          incomeCategoryId: 'salary',
          incomeRootId: 'salary',
          toAccountId: 'bank',
        ),
      );
      viewModel.setToAccountId('cash');
      viewModel.initializeForEdit(
        transactionId: 'tx-1',
        snapshot: TransactionFormEditSnapshot(
          mode: TransactionFormMode.income,
          amountText: '10.00',
          noteText: 'salary',
          occurredAt: DateTime(2026, 2, 3),
          excludeStats: true,
          excludeBudget: false,
        ),
      );

      final state = container.read(transactionFormViewModelProvider);
      expect(state.mode, TransactionFormMode.income);
      expect(state.incomeCategoryId, 'salary');
      expect(state.toAccountId, 'cash');
    });

    test('submits reimbursement advance edit for edited advance', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(editService: editService);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      viewModel
        ..setExpenseCategory(rootId: 'travel', categoryId: 'hotel')
        ..setFromAccountId('cash')
        ..setReimbursementAccountId('company');

      final outcome = await viewModel.submit(
        _options(
          amountText: '30',
          editTransactionId: 'tx-1',
          settlementAccounts: [_account('cash')],
          reimbursementAccounts: [_account('company')],
        ),
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.reimbursementAdvanceCommands.single;
      expect(command.transactionId, 'tx-1');
      expect(command.receivableAccountId, 'company');
      expect(command.expenseCategoryId, 'hotel');
    });

    test('deletes transaction through action outcome', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(editService: editService);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      final outcome = await viewModel.deleteTransaction('tx-1');

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(editService.deletedTransactionIds, ['tx-1']);
      expect(
        container.read(transactionFormViewModelProvider).submitting,
        false,
      );
    });
  });
}

ProviderContainer _container({
  TransactionPostingAppService? postingService,
  TransactionEditAppService? editService,
}) {
  final container = ProviderContainer(
    overrides: [
      transactionPostingAppServiceProvider.overrideWith(
        (ref) => postingService ?? _FakeTransactionPostingAppService(),
      ),
      transactionEditAppServiceProvider.overrideWith(
        (ref) => editService ?? _FakeTransactionEditAppService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

TransactionFormSubmitOptions _options({
  String amountText = '12.00',
  String noteText = '',
  String? editTransactionId,
  List<Account> settlementAccounts = const [],
  List<Account> fundAccounts = const [],
  List<Account> liabilityAccounts = const [],
  List<Account> reimbursementAccounts = const [],
}) {
  return TransactionFormSubmitOptions(
    amountText: amountText,
    noteText: noteText,
    editTransactionId: editTransactionId,
    settlementAccounts: settlementAccounts,
    fundAccounts: fundAccounts,
    liabilityAccounts: liabilityAccounts,
    reimbursementAccounts: reimbursementAccounts,
  );
}

void _fillValidDailyExpense(TransactionFormViewModel viewModel) {
  viewModel
    ..setExpenseCategory(rootId: 'food', categoryId: 'lunch')
    ..setFromAccountId('cash');
}

Account _account(String id, {AccountType type = AccountType.asset}) {
  return Account(
    id: id,
    name: id,
    type: type,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeTransactionPostingAppService
    implements TransactionPostingAppService {
  _FakeTransactionPostingAppService({this.exception});

  final Object? exception;
  final expenseCommands = <CreateExpenseCommand>[];
  final incomeCommands = <CreateIncomeCommand>[];
  final transferCommands = <CreateTransferCommand>[];
  final reimbursementAdvanceCommands = <CreateReimbursementAdvanceCommand>[];
  final borrowingCommands = <CreateBorrowingCommand>[];

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
    expenseCommands.add(command);
    return _postedResult();
  }

  @override
  Future<PostedTransactionResult> createIncome(
    CreateIncomeCommand command,
  ) async {
    incomeCommands.add(command);
    return _postedResult();
  }

  @override
  Future<PostedTransactionResult> createTransfer(
    CreateTransferCommand command,
  ) async {
    transferCommands.add(command);
    return _postedResult();
  }

  @override
  Future<PostedTransactionResult> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) async {
    reimbursementAdvanceCommands.add(command);
    return _postedResult();
  }

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) async {
    borrowingCommands.add(command);
    return _postedResult();
  }

  PostedTransactionResult _postedResult() {
    final exception = this.exception;
    if (exception != null) throw exception;
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
}

class _FakeTransactionEditAppService implements TransactionEditAppService {
  final reimbursementAdvanceCommands = <EditReimbursementAdvanceCommand>[];
  final deletedTransactionIds = <String>[];

  @override
  Future<PostedTransactionResult> editExpense(EditExpenseCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editIncome(EditIncomeCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editTransfer(EditTransferCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editReimbursementAdvance(
    EditReimbursementAdvanceCommand command,
  ) async {
    reimbursementAdvanceCommands.add(command);
    return const PostedTransactionResult(transactionId: 'transaction-1');
  }

  @override
  Future<PostedTransactionResult> editBorrowing(EditBorrowingCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    deletedTransactionIds.add(command.transactionId);
  }

  @override
  Future<PostedTransactionResult> editRefund(EditRefundCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editReimbursementClose(
    EditReimbursementCloseCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editReimbursementReceipt(
    EditReimbursementReceiptCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editRepayment(EditRepaymentCommand command) {
    throw UnimplementedError();
  }
}
