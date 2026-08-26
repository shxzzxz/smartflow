import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_presentation.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  group('TransactionFormViewModel', () {
    test('initializes a borrowing form with its liability account', () {
      final container = _container(
        liabilityAccounts: [_account('payable', type: AccountType.liability)],
      );

      final state = container
          .read(
            transactionFormViewModelProvider(
              initialMode: TransactionFormMode.borrowing,
              initialLiabilityAccountId: 'payable',
            ),
          )
          .requireValue!;

      expect(state.liabilityAccountId, 'payable');
      expect(state.toAccountId, isNull);
    });

    test('maps edit loading, data, and not-found snapshots', () {
      final detail = _transactionDetail();
      final accounts = {
        'cash': _account('cash'),
        'food': _account('food', type: AccountType.expense),
      };
      final commonOverrides = [
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
        categoryTreeProvider(AccountType.expense).overrideWithValue(
          AsyncData([CategoryNode(account: accounts['food']!)]),
        ),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWithValue(const AsyncData(<CategoryNode>[])),
        accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
        tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
        transactionTagIdsProvider(
          'tx-1',
        ).overrideWithValue(const AsyncData(<String>{})),
      ];

      final loading = ProviderContainer(
        overrides: [
          ...commonOverrides,
          transactionDetailProvider(
            'tx-1',
          ).overrideWithValue(AsyncData(detail)),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.settlement,
          ).overrideWithValue(const AsyncLoading()),
        ],
      );
      addTearDown(loading.dispose);
      expect(
        loading.read(
          transactionFormViewModelProvider(editTransactionId: 'tx-1'),
        ),
        isA<AsyncLoading<TransactionFormState?>>(),
      );

      final loaded = ProviderContainer(
        overrides: [
          ...commonOverrides,
          transactionDetailProvider(
            'tx-1',
          ).overrideWithValue(AsyncData(detail)),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.settlement,
          ).overrideWithValue(AsyncData([accounts['cash']!])),
        ],
      );
      addTearDown(loaded.dispose);
      final loadedState = loaded
          .read(transactionFormViewModelProvider(editTransactionId: 'tx-1'))
          .requireValue!;
      expect(loadedState.initialValues.amount, '12.34');
      expect(loadedState.initialValues.note, 'note');
      expect(loadedState.mode, TransactionFormMode.expense);
      expect(loadedState.expenseCategoryId, 'food');
      expect(loadedState.fromAccountId, 'cash');

      final missing = ProviderContainer(
        overrides: [
          ...commonOverrides,
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.settlement,
          ).overrideWithValue(AsyncData([accounts['cash']!])),
          transactionDetailProvider(
            'tx-1',
          ).overrideWithValue(const AsyncData(null)),
        ],
      );
      addTearDown(missing.dispose);
      expect(
        missing
            .read(transactionFormViewModelProvider(editTransactionId: 'tx-1'))
            .requireValue,
        isNull,
      );
    });

    test('rejects child transaction types in the generic edit form', () {
      final detail = TransactionDetail(
        transaction: Transaction(
          id: 'refund',
          parentTransactionId: 'parent',
          businessPurpose: BusinessPurpose.refund,
          occurredAt: DateTime(2026, 7, 23),
          primaryAmount: const Money(minorUnits: 1000),
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          sourceKind: SourceKind.manual,
        ),
        createdAt: DateTime(2026, 7, 23),
        lines: const [],
        entries: const [],
      );
      final container = _container(
        editTransactionId: 'refund',
        editDetail: detail,
      );

      expect(
        container
            .read(transactionFormViewModelProvider(editTransactionId: 'refund'))
            .requireValue,
        isNull,
      );
    });

    test('creates daily expense command and returns success', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(
        postingService: posting,
        settlementAccounts: [_account('cash')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setOccurredAt(DateTime(2026, 1, 2, 8, 30))
        ..setExpenseCategory(rootId: 'food', categoryId: 'lunch')
        ..setFromAccountId('cash')
        ..setExcludeStats(true)
        ..setExcludeBudget(true);

      final outcome = await viewModel.submit(
        amountText: '12.34',
        noteText: ' lunch ',
      );

      expect(outcome, isA<SubmitSuccess>());
      expect(container.read(_provider()).requireValue!.submitting, false);
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
      'defaults expense account from the selected category history',
      () async {
        final transactionQuery = _FakeTransactionQueryService({
          'lunch': 'bank',
        });
        final container = _container(
          transactionQueryService: transactionQuery,
          settlementAccounts: [_account('cash'), _account('bank')],
        );
        final viewModel = container.read(_provider().notifier);
        viewModel.setFromAccountId('cash');

        await viewModel.setExpenseCategory(rootId: 'food', categoryId: 'lunch');

        expect(transactionQuery.categoryIds, ['lunch']);
        expect(container.read(_provider()).requireValue!.fromAccountId, 'bank');
      },
    );

    test('does not replace an account selected while history loads', () async {
      final historyResult = Completer<String?>();
      final transactionQuery = _FakeTransactionQueryService.withLookup(
        (_) => historyResult.future,
      );
      final container = _container(
        transactionQueryService: transactionQuery,
        settlementAccounts: [_account('cash'), _account('bank')],
      );
      final viewModel = container.read(_provider().notifier);

      final defaultLookup = viewModel.setExpenseCategory(
        rootId: 'food',
        categoryId: 'lunch',
      );
      viewModel.setFromAccountId('cash');
      historyResult.complete('bank');
      await defaultLookup;

      expect(container.read(_provider()).requireValue!.fromAccountId, 'cash');
    });

    test('preserves the current account without usable history', () async {
      for (final historicalAccountId in <String?>[null, 'unavailable']) {
        final container = _container(
          transactionQueryService: _FakeTransactionQueryService({
            'lunch': historicalAccountId,
          }),
          settlementAccounts: [_account('cash')],
        );
        final viewModel = container.read(_provider().notifier);
        viewModel.setFromAccountId('cash');

        await viewModel.setExpenseCategory(rootId: 'food', categoryId: 'lunch');

        expect(container.read(_provider()).requireValue!.fromAccountId, 'cash');
      }
    });

    test('ignores a stale category history response', () async {
      final lunchResult = Completer<String?>();
      final travelResult = Completer<String?>();
      final transactionQuery = _FakeTransactionQueryService.withLookup(
        (categoryId) => switch (categoryId) {
          'lunch' => lunchResult.future,
          'travel' => travelResult.future,
          _ => Future<String?>.value(),
        },
      );
      final container = _container(
        transactionQueryService: transactionQuery,
        settlementAccounts: [_account('cash'), _account('bank')],
      );
      final viewModel = container.read(_provider().notifier);

      final lunchLookup = viewModel.setExpenseCategory(
        rootId: 'food',
        categoryId: 'lunch',
      );
      final travelLookup = viewModel.setExpenseCategory(
        rootId: 'travel',
        categoryId: 'travel',
      );
      travelResult.complete('bank');
      await travelLookup;
      lunchResult.complete('cash');
      await lunchLookup;

      final state = container.read(_provider()).requireValue!;
      expect(state.expenseCategoryId, 'travel');
      expect(state.fromAccountId, 'bank');
    });

    test(
      'creates reimbursement advance command when account is selected',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final container = _container(
          postingService: posting,
          settlementAccounts: [_account('cash')],
          reimbursementAccounts: [_account('company')],
        );
        final viewModel = container.read(_provider().notifier);

        viewModel
          ..setExpenseCategory(rootId: 'travel', categoryId: 'taxi')
          ..setFromAccountId('cash')
          ..setReimbursementAccountId('company');

        final outcome = await viewModel.submit(amountText: '20', noteText: '');

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
      final container = _container(
        postingService: posting,
        settlementAccounts: [_account('bank')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setMode(TransactionFormMode.income)
        ..setIncomeCategory(rootId: 'salary', categoryId: 'salary')
        ..setToAccountId('bank')
        ..setExcludeStats(true);

      final outcome = await viewModel.submit(amountText: '88', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = posting.incomeCommands.single;
      expect(command.amount, const Money(minorUnits: 8800));
      expect(command.receiveAccountId, 'bank');
      expect(command.incomeAccountId, 'salary');
      expect(command.isExcludedFromStats, true);
    });

    test(
      'defaults income account from the selected category history',
      () async {
        final transactionQuery = _FakeTransactionQueryService({
          'salary': 'bank',
        });
        final container = _container(
          transactionQueryService: transactionQuery,
          settlementAccounts: [_account('cash'), _account('bank')],
        );
        final viewModel = container.read(_provider().notifier);
        viewModel
          ..setMode(TransactionFormMode.income)
          ..setToAccountId('cash');

        await viewModel.setIncomeCategory(
          rootId: 'salary',
          categoryId: 'salary',
        );

        expect(transactionQuery.categoryIds, ['salary']);
        expect(container.read(_provider()).requireValue!.toAccountId, 'bank');
      },
    );

    test('creates transfer command', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(
        postingService: posting,
        settlementAccounts: [_account('cash'), _account('bank')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setMode(TransactionFormMode.transfer)
        ..setFromAccountId('cash')
        ..setToAccountId('bank');

      final outcome = await viewModel.submit(
        amountText: '50',
        feeText: '3',
        noteText: '',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = posting.transferCommands.single;
      expect(command.fromAccountId, 'cash');
      expect(command.toAccountId, 'bank');
      expect(command.feeAmount, const Money(minorUnits: 300));
    });

    test('loads and clears a transfer fee while editing', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(
        editService: editService,
        editTransactionId: 'transfer-1',
        editDetail: _transferTransactionDetail(),
        accountsById: {'cash': _account('cash'), 'bank': _account('bank')},
        settlementAccounts: [_account('cash'), _account('bank')],
      );
      final provider = _provider(editTransactionId: 'transfer-1');

      final state = container.read(provider).requireValue!;
      expect(state.initialValues.fee, '3');

      final outcome = await container
          .read(provider.notifier)
          .submit(amountText: '20', feeText: '', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.transferCommands.single;
      expect(command.feeAmount, Money.zero());
    });

    test('sets a transfer fee while editing', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(
        editService: editService,
        editTransactionId: 'transfer-1',
        editDetail: _transferTransactionDetail(),
        accountsById: {'cash': _account('cash'), 'bank': _account('bank')},
        settlementAccounts: [_account('cash'), _account('bank')],
      );

      final outcome = await container
          .read(_provider(editTransactionId: 'transfer-1').notifier)
          .submit(amountText: '20', feeText: '5', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      expect(
        editService.transferCommands.single.feeAmount,
        const Money(minorUnits: 500),
      );
    });

    test('does not modify a transfer fee when fee text is omitted', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(
        editService: editService,
        editTransactionId: 'transfer-1',
        editDetail: _transferTransactionDetail(),
        accountsById: {'cash': _account('cash'), 'bank': _account('bank')},
        settlementAccounts: [_account('cash'), _account('bank')],
      );

      final outcome = await container
          .read(_provider(editTransactionId: 'transfer-1').notifier)
          .submit(amountText: '20', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      expect(editService.transferCommands.single.feeAmount, isNull);
    });

    test('rejects a negative transfer fee before posting', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(
        postingService: posting,
        settlementAccounts: [_account('cash'), _account('bank')],
      );
      final viewModel = container.read(_provider().notifier);
      viewModel
        ..setMode(TransactionFormMode.transfer)
        ..setFromAccountId('cash')
        ..setToAccountId('bank');

      final outcome = await viewModel.submit(
        amountText: '50',
        feeText: '-1',
        noteText: '',
      );

      expect(outcome, isA<SubmitFailure>());
      expect(posting.transferCommands, isEmpty);
    });

    test('creates borrowing command', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(
        postingService: posting,
        fundAccounts: [_account('bank')],
        liabilityAccounts: [_account('loan', type: AccountType.liability)],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setMode(TransactionFormMode.borrowing)
        ..setLiabilityAccountId('loan')
        ..setToAccountId('bank');

      final outcome = await viewModel.submit(amountText: '100', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = posting.borrowingCommands.single;
      expect(command.liabilityAccountId, 'loan');
      expect(command.receiveAccountId, 'bank');
    });

    test(
      'creates lending with a fund and ordinary receivable account',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final container = _container(
          postingService: posting,
          fundAccounts: [_account('cash')],
          reimbursementAccounts: [_account('reimbursement')],
          ordinaryReceivableAccounts: [_account('receivable')],
        );
        final viewModel = container.read(_provider().notifier);

        viewModel
          ..setMode(TransactionFormMode.lending)
          ..setFromAccountId('cash')
          ..setOrdinaryReceivableAccountId('receivable');

        final outcome = await viewModel.submit(amountText: '100', noteText: '');

        expect(outcome, isA<SubmitSuccess>());
        final command = posting.lendingCommands.single;
        expect(command.paidFromAccountId, 'cash');
        expect(command.receivableAccountId, 'receivable');
      },
    );

    test('loads and submits a lending edit', () async {
      final editService = _FakeTransactionEditAppService();
      final detail = _lendingTransactionDetail();
      final container = _container(
        editService: editService,
        editTransactionId: 'lending-1',
        editDetail: detail,
        accountsById: {
          'cash': _account('cash'),
          'receivable': _account('receivable'),
        },
        fundAccounts: [_account('cash')],
        ordinaryReceivableAccounts: [_account('receivable')],
      );
      final provider = _provider(editTransactionId: 'lending-1');

      final state = container.read(provider).requireValue!;
      expect(state.mode, TransactionFormMode.lending);
      expect(state.fromAccountId, 'cash');
      expect(state.ordinaryReceivableAccountId, 'receivable');

      final outcome = await container
          .read(provider.notifier)
          .submit(amountText: '50', noteText: 'loan note');

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.lendingCommands.single;
      expect(command.transactionId, 'lending-1');
      expect(command.amount, const Money(minorUnits: 5000));
      expect(command.paidFromAccountId, 'cash');
      expect(command.receivableAccountId, 'receivable');
      expect(command.note, isA<PatchSet<String?>>());
      expect((command.note as PatchSet<String?>).value, 'loan note');
    });

    test(
      'returns failure and skips service when command state is incomplete',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final container = _container(
          postingService: posting,
          settlementAccounts: [_account('cash')],
        );
        final viewModel = container.read(_provider().notifier);

        final outcome = await viewModel.submit(
          amountText: '12.00',
          noteText: '',
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
      final container = _container(
        postingService: posting,
        settlementAccounts: [_account('cash')],
      );
      final viewModel = container.read(_provider().notifier);
      _fillValidDailyExpense(viewModel);

      final outcome = await viewModel.submit(amountText: '12.00', noteText: '');

      expect(outcome, isA<SubmitFailure>());
      final failure = outcome as SubmitFailure;
      expect(failure.error.code, LedgerErrorCode.accountInvalidRole.code);
      expect(failure.error.message, '账户不能用于当前交易。');
      expect(container.read(_provider()).requireValue!.submitting, false);
    });

    test('rethrows unexpected exceptions after resetting submitting', () async {
      final unexpected = StateError('unexpected');
      final posting = _FakeTransactionPostingAppService(exception: unexpected);
      final container = _container(
        postingService: posting,
        settlementAccounts: [_account('cash')],
      );
      final viewModel = container.read(_provider().notifier);
      _fillValidDailyExpense(viewModel);

      await expectLater(
        () => viewModel.submit(amountText: '12.00', noteText: ''),
        throwsA(same(unexpected)),
      );
      expect(container.read(_provider()).requireValue!.submitting, false);
    });

    test('keeps the loaded edit snapshot while choices change', () {
      final detail = _transactionDetail();
      final container = _container(
        editTransactionId: 'tx-1',
        editDetail: detail,
        accountsById: {
          'cash': _account('cash'),
          'food': _account('food', type: AccountType.expense),
        },
        settlementAccounts: [_account('cash')],
      );
      final viewModel = container.read(
        _provider(editTransactionId: 'tx-1').notifier,
      );

      viewModel.setToAccountId('cash');

      final state = container
          .read(_provider(editTransactionId: 'tx-1'))
          .requireValue!;
      expect(state.initialValues.amount, '12.34');
      expect(state.expenseCategoryId, 'food');
      expect(state.toAccountId, 'cash');
    });

    test('does not load a category account default while editing', () async {
      final transactionQuery = _FakeTransactionQueryService({'food': 'bank'});
      final container = _container(
        transactionQueryService: transactionQuery,
        editTransactionId: 'tx-1',
        editDetail: _transactionDetail(),
        accountsById: {
          'cash': _account('cash'),
          'food': _account('food', type: AccountType.expense),
        },
        settlementAccounts: [_account('cash'), _account('bank')],
      );
      final viewModel = container.read(
        _provider(editTransactionId: 'tx-1').notifier,
      );

      await viewModel.setExpenseCategory(rootId: 'food', categoryId: 'food');

      expect(transactionQuery.categoryIds, isEmpty);
      expect(
        container
            .read(_provider(editTransactionId: 'tx-1'))
            .requireValue!
            .fromAccountId,
        'cash',
      );
    });

    test('submits reimbursement advance edit for edited advance', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(
        editService: editService,
        editTransactionId: 'tx-1',
        editDetail: _transactionDetail(),
        accountsById: {
          'cash': _account('cash'),
          'food': _account('food', type: AccountType.expense),
          'company': _account('company'),
        },
        settlementAccounts: [_account('cash')],
        reimbursementAccounts: [_account('company')],
      );
      final viewModel = container.read(
        _provider(editTransactionId: 'tx-1').notifier,
      );

      viewModel
        ..setExpenseCategory(rootId: 'travel', categoryId: 'hotel')
        ..setFromAccountId('cash')
        ..setReimbursementAccountId('company');

      final outcome = await viewModel.submit(amountText: '30', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.reimbursementAdvanceCommands.single;
      expect(command.transactionId, 'tx-1');
      expect(command.receivableAccountId, 'company');
      expect(command.expenseCategoryId, 'hotel');
    });

    test('saves a loaded daily expense without changing its fields', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(
        editService: editService,
        editTransactionId: 'tx-1',
        editDetail: _transactionDetail(),
        accountsById: {
          'cash': _account('cash'),
          'food': _account('food', type: AccountType.expense),
        },
        settlementAccounts: [_account('cash')],
      );
      final viewModel = container.read(
        _provider(editTransactionId: 'tx-1').notifier,
      );

      final outcome = await viewModel.submit(
        amountText: '12.34',
        noteText: 'note',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = editService.expenseCommands.single;
      expect(command.transactionId, 'tx-1');
      expect(command.amount, const Money(minorUnits: 1234));
      expect(command.paidFromAccountId, 'cash');
      expect(command.expenseAccountId, 'food');
      expect(command.note, isA<PatchSet<String?>>());
      expect((command.note as PatchSet<String?>).value, 'note');
    });

    test('deletes transaction through action outcome', () async {
      final editService = _FakeTransactionEditAppService();
      final container = _container(editService: editService);
      final viewModel = container.read(_provider().notifier);

      final outcome = await viewModel.deleteTransaction('tx-1');

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(editService.deletedTransactionIds, ['tx-1']);
      expect(container.read(_provider()).requireValue!.submitting, false);
    });
  });
}

TransactionFormViewModelProvider _provider({String? editTransactionId}) {
  return transactionFormViewModelProvider(editTransactionId: editTransactionId);
}

ProviderContainer _container({
  TransactionPostingAppService? postingService,
  TransactionEditAppService? editService,
  TransactionQueryService? transactionQueryService,
  String? editTransactionId,
  TransactionDetail? editDetail,
  Map<String, Account> accountsById = const {},
  List<Account> settlementAccounts = const [],
  List<Account> fundAccounts = const [],
  List<Account> liabilityAccounts = const [],
  List<Account> reimbursementAccounts = const [],
  List<Account> ordinaryReceivableAccounts = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      transactionPostingAppServiceProvider.overrideWith(
        (ref) => postingService ?? _FakeTransactionPostingAppService(),
      ),
      transactionEditAppServiceProvider.overrideWith(
        (ref) => editService ?? _FakeTransactionEditAppService(),
      ),
      transactionQueryServiceProvider.overrideWithValue(
        transactionQueryService ?? _FakeTransactionQueryService(),
      ),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWithValue(AsyncData(settlementAccounts)),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.fund,
      ).overrideWithValue(AsyncData(fundAccounts)),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.borrowingLiability,
      ).overrideWithValue(AsyncData(liabilityAccounts)),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.reimbursementReceivable,
      ).overrideWithValue(AsyncData(reimbursementAccounts)),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.ordinaryReceivable,
      ).overrideWithValue(AsyncData(ordinaryReceivableAccounts)),
      categoryTreeProvider(
        AccountType.expense,
      ).overrideWithValue(const AsyncData(<CategoryNode>[])),
      categoryTreeProvider(
        AccountType.income,
      ).overrideWithValue(const AsyncData(<CategoryNode>[])),
      accountsByIdProvider.overrideWithValue(AsyncData(accountsById)),
      tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
      if (editTransactionId != null) ...[
        transactionDetailProvider(
          editTransactionId,
        ).overrideWithValue(AsyncValue.data(editDetail)),
        transactionTagIdsProvider(
          editTransactionId,
        ).overrideWithValue(const AsyncData(<String>{})),
      ],
    ],
  );
  addTearDown(container.dispose);
  return container;
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

TransactionDetail _transactionDetail() {
  final entries = [
    _entry('food', EntryDirection.debit),
    _entry('cash', EntryDirection.credit),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: 'tx-1',
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 2, 8, 30),
      primaryAmount: const Money(minorUnits: 1234),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      note: 'note',
      entries: entries,
    ),
    createdAt: DateTime(2026, 1, 2, 8, 30),
    lines: const [],
    entries: entries,
  );
}

TransactionDetail _lendingTransactionDetail() {
  final entries = [
    _entry('receivable', EntryDirection.debit),
    _entry('cash', EntryDirection.credit),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: 'lending-1',
      businessPurpose: BusinessPurpose.lending,
      occurredAt: DateTime(2026, 8, 21),
      primaryAmount: const Money(minorUnits: 5000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      entries: entries,
    ),
    createdAt: DateTime(2026, 8, 21),
    lines: const [],
    entries: entries,
  );
}

TransactionDetail _transferTransactionDetail() {
  const amount = Money(minorUnits: 2000);
  const fee = Money(minorUnits: 300);
  const lines = [
    TransactionLine(
      id: 'transfer-out',
      transactionId: 'transfer-1',
      lineNo: 1,
      role: TransactionRole.settlementOut,
      accountId: 'cash',
      amount: amount,
    ),
    TransactionLine(
      id: 'transfer-in',
      transactionId: 'transfer-1',
      lineNo: 2,
      role: TransactionRole.settlementIn,
      accountId: 'bank',
      amount: amount,
    ),
    TransactionLine(
      id: 'transfer-fee',
      transactionId: 'transfer-1',
      lineNo: 3,
      role: TransactionRole.fee,
      amount: fee,
    ),
  ];
  const entries = [
    Entry(
      id: 'transfer-to',
      transactionId: 'transfer-1',
      accountId: 'bank',
      direction: EntryDirection.debit,
      amount: amount,
    ),
    Entry(
      id: 'transfer-from',
      transactionId: 'transfer-1',
      accountId: 'cash',
      direction: EntryDirection.credit,
      amount: Money(minorUnits: 2300),
    ),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: 'transfer-1',
      businessPurpose: BusinessPurpose.transfer,
      occurredAt: DateTime(2026, 8, 22),
      primaryAmount: amount,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      lines: lines,
      entries: entries,
    ),
    createdAt: DateTime(2026, 8, 22),
    lines: lines,
    entries: entries,
  );
}

Entry _entry(String accountId, EntryDirection direction) {
  return Entry(
    id: 'entry-$accountId',
    transactionId: 'tx-1',
    accountId: accountId,
    direction: direction,
    amount: const Money(minorUnits: 1234),
  );
}

class _FakeTransactionQueryService implements TransactionQueryService {
  _FakeTransactionQueryService([
    this._accountIdByCategory = const <String, String?>{},
  ]) : lookup = null;

  _FakeTransactionQueryService.withLookup(this.lookup)
    : _accountIdByCategory = const <String, String?>{};

  final Map<String, String?> _accountIdByCategory;
  final Future<String?> Function(String categoryId)? lookup;
  final categoryIds = <String>[];

  @override
  Future<String?> findLastUsedSettlementAccountId(String categoryId) async {
    categoryIds.add(categoryId);
    if (lookup case final lookup?) return lookup(categoryId);
    return _accountIdByCategory[categoryId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTransactionPostingAppService
    implements
        TransactionPostingAppService,
        ReceivableTransactionPostingAppService {
  _FakeTransactionPostingAppService({this.exception});

  final Object? exception;
  final expenseCommands = <CreateExpenseCommand>[];
  final incomeCommands = <CreateIncomeCommand>[];
  final transferCommands = <CreateTransferCommand>[];
  final reimbursementAdvanceCommands = <CreateReimbursementAdvanceCommand>[];
  final borrowingCommands = <CreateBorrowingCommand>[];
  final lendingCommands = <CreateLendingCommand>[];

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

  @override
  Future<PostedTransactionResult> createLending(
    CreateLendingCommand command,
  ) async {
    lendingCommands.add(command);
    return _postedResult();
  }

  @override
  Future<PostedTransactionResult> createReceivableCollection(
    CreateReceivableCollectionCommand command,
  ) async => _postedResult();

  @override
  Future<PostedTransactionResult> createBadDebt(
    CreateBadDebtCommand command,
  ) async => _postedResult();

  @override
  Future<PostedTransactionResult> createDebtRelief(
    CreateDebtReliefCommand command,
  ) async => _postedResult();

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

class _FakeTransactionEditAppService
    implements TransactionEditAppService, ReceivableTransactionEditAppService {
  final expenseCommands = <EditExpenseCommand>[];
  final reimbursementAdvanceCommands = <EditReimbursementAdvanceCommand>[];
  final transferCommands = <EditTransferCommand>[];
  final lendingCommands = <EditLendingCommand>[];
  final deletedTransactionIds = <String>[];

  @override
  Future<PostedTransactionResult> editExpense(
    EditExpenseCommand command,
  ) async {
    expenseCommands.add(command);
    return const PostedTransactionResult(transactionId: 'transaction-1');
  }

  @override
  Future<PostedTransactionResult> editIncome(EditIncomeCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editTransfer(
    EditTransferCommand command,
  ) async {
    transferCommands.add(command);
    return const PostedTransactionResult(transactionId: 'transfer-1');
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
  Future<PostedTransactionResult> editLending(
    EditLendingCommand command,
  ) async {
    lendingCommands.add(command);
    return const PostedTransactionResult(transactionId: 'lending-1');
  }

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    deletedTransactionIds.add(command.transactionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
