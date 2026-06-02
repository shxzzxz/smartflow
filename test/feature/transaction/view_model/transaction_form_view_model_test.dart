import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';

void main() {
  group('TransactionFormViewModel', () {
    test('creates daily expense command and returns success', () async {
      final fakeService = _FakeTransactionPostingAppService();
      final container = _container(fakeService);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );

      viewModel
        ..setAmountText('12.34')
        ..setNoteText(' lunch ')
        ..setOccurredAt(DateTime(2026, 1, 2, 8, 30))
        ..setExpenseCategory(rootId: 'food', categoryId: 'lunch')
        ..setFromAccountId('cash')
        ..setExcludeStats(true)
        ..setExcludeBudget(true);

      final outcome = await viewModel.submitDailyExpense(
        settlementAccounts: [_account('cash')],
      );

      expect(outcome, isA<SubmitSuccess>());
      expect(
        container.read(transactionFormViewModelProvider).submitting,
        false,
      );
      expect(fakeService.commands, hasLength(1));
      final command = fakeService.commands.single;
      expect(command.amount, const Money(minorUnits: 1234));
      expect(command.paidFromAccountId, 'cash');
      expect(command.expenseAccountId, 'lunch');
      expect(command.occurredAt, DateTime(2026, 1, 2, 8, 30));
      expect(command.note, 'lunch');
      expect(command.isExcludedFromStats, true);
      expect(command.isExcludedFromBudget, true);
    });

    test(
      'returns failure and skips service when command state is incomplete',
      () async {
        final fakeService = _FakeTransactionPostingAppService();
        final container = _container(fakeService);
        final viewModel = container.read(
          transactionFormViewModelProvider.notifier,
        );

        viewModel.setAmountText('12.00');

        final outcome = await viewModel.submitDailyExpense(
          settlementAccounts: [_account('cash')],
        );

        expect(outcome, isA<SubmitFailure>());
        final failure = outcome as SubmitFailure;
        expect(
          failure.error.code,
          LedgerErrorCode.transactionInvalidCommand.code,
        );
        expect(failure.error.message, '请选择支出分类');
        expect(fakeService.commands, isEmpty);
      },
    );

    test('maps business exceptions to submit failure', () async {
      final fakeService = _FakeTransactionPostingAppService(
        exception: BusinessException(
          LedgerErrorCode.accountInvalidRole,
          message: '账户不能用于当前交易。',
        ),
      );
      final container = _container(fakeService);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );
      _fillValidDailyExpense(viewModel);

      final outcome = await viewModel.submitDailyExpense(
        settlementAccounts: [_account('cash')],
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

    test('maps call exceptions to submit failure', () async {
      final fakeService = _FakeTransactionPostingAppService(
        exception: CallException(
          LedgerErrorCode.transactionPostingFailed,
          message: '保存失败。',
        ),
      );
      final container = _container(fakeService);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );
      _fillValidDailyExpense(viewModel);

      final outcome = await viewModel.submitDailyExpense(
        settlementAccounts: [_account('cash')],
      );

      expect(outcome, isA<SubmitFailure>());
      final failure = outcome as SubmitFailure;
      expect(failure.error.code, LedgerErrorCode.transactionPostingFailed.code);
      expect(failure.error.message, '保存失败。');
      expect(
        container.read(transactionFormViewModelProvider).submitting,
        false,
      );
    });

    test('rethrows unexpected exceptions after resetting submitting', () async {
      final unexpected = StateError('unexpected');
      final fakeService = _FakeTransactionPostingAppService(
        exception: unexpected,
      );
      final container = _container(fakeService);
      final viewModel = container.read(
        transactionFormViewModelProvider.notifier,
      );
      _fillValidDailyExpense(viewModel);

      await expectLater(
        () => viewModel.submitDailyExpense(
          settlementAccounts: [_account('cash')],
        ),
        throwsA(same(unexpected)),
      );
      expect(
        container.read(transactionFormViewModelProvider).submitting,
        false,
      );
    });
  });
}

ProviderContainer _container(TransactionPostingAppService service) {
  final container = ProviderContainer(
    overrides: [
      transactionPostingAppServiceProvider.overrideWith((ref) => service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void _fillValidDailyExpense(TransactionFormViewModel viewModel) {
  viewModel
    ..setAmountText('12.00')
    ..setExpenseCategory(rootId: 'food', categoryId: 'lunch')
    ..setFromAccountId('cash');
}

Account _account(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeTransactionPostingAppService
    implements TransactionPostingAppService {
  _FakeTransactionPostingAppService({this.exception});

  final Object? exception;
  final commands = <CreateExpenseCommand>[];

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
    commands.add(command);
    final exception = this.exception;
    if (exception != null) throw exception;
    return const PostedTransactionResult(
      transactionId: 'transaction-1',
      rootTransactionId: 'transaction-1',
    );
  }

  @override
  Future<Result<PostedTransactionResult>> adjustBalance(
    AdjustBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> closeReimbursement(
    CloseReimbursementCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createBorrowing(
    CreateBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createIncome(
    CreateIncomeCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createRefund(
    CreateRefundCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createReimbursementAdvance(
    CreateReimbursementAdvanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createReimbursementReceipt(
    CreateReimbursementReceiptCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<PostedTransactionResult>> createTransfer(
    CreateTransferCommand command,
  ) {
    throw UnimplementedError();
  }
}
