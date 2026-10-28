import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/provider/counterparty_providers.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_presentation.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import '../../../helper/advance_ownership_fixtures.dart';
import '../../../helper/fake_advance_case_repository.dart';

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
          AccountSelectionPurpose.advanceReceivable,
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
        counterpartyListProvider.overrideWithValue(
          const AsyncData(<CounterpartyView>[]),
        ),
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
      final detail = TransactionReadModel.fromTransaction(
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

    test('loads multi-category and multi-account income in allocated mode', () {
      final detail = TransactionReadModel.fromTransaction(
        transaction: Transaction(
          id: 'income-1',
          businessPurpose: BusinessPurpose.dailyIncome,
          occurredAt: DateTime(2026, 1, 2),
          primaryAmount: const Money(minorUnits: 1000),
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          sourceKind: SourceKind.manual,
        ),
        createdAt: DateTime(2026, 1, 2),
        lines: const [
          TransactionLine(
            id: 'salary',
            transactionId: 'income-1',
            lineNo: 1,
            role: TransactionRole.category,
            accountId: 'salary',
            amount: Money(minorUnits: 700),
          ),
          TransactionLine(
            id: 'bonus',
            transactionId: 'income-1',
            lineNo: 2,
            role: TransactionRole.category,
            accountId: 'bonus',
            amount: Money(minorUnits: 300),
          ),
          TransactionLine(
            id: 'bank',
            transactionId: 'income-1',
            lineNo: 3,
            role: TransactionRole.settlementIn,
            accountId: 'bank',
            amount: Money(minorUnits: 600),
          ),
          TransactionLine(
            id: 'cash',
            transactionId: 'income-1',
            lineNo: 4,
            role: TransactionRole.settlementIn,
            accountId: 'cash',
            amount: Money(minorUnits: 400),
          ),
        ],
      );
      final container = _container(
        editTransactionId: 'income-1',
        editDetail: detail,
        accountsById: {
          'salary': _account('salary', type: AccountType.income),
          'bonus': _account('bonus', type: AccountType.income),
          'bank': _account('bank'),
          'cash': _account('cash'),
        },
      );

      final state = container
          .read(transactionFormViewModelProvider(editTransactionId: 'income-1'))
          .requireValue!;

      expect(state.mode, TransactionFormMode.income);
      expect(state.entryMode, TransactionEntryMode.allocated);
      expect(state.categoryAllocations.map((item) => item.accountId), [
        'salary',
        'bonus',
      ]);
      expect(state.settlementAllocations.map((item) => item.accountId), [
        'bank',
        'cash',
      ]);
    });

    test('creates daily expense command and returns success', () async {
      final posting = _FakeTransactionPostingAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        postingService: posting,
        advanceOrchestrationService: orchestration,
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
      final command = orchestration.createSceneCommands.single;
      expect(command.target, isA<OrdinaryExpenseSceneTarget>());
      expect(command.amount, const Money(minorUnits: 1234));
      expect(command.settlementAllocations.single.accountId, 'cash');
      expect(command.categoryAllocations.single.accountId, 'lunch');
      expect(command.occurredAt, DateTime(2026, 1, 2, 8, 30));
      expect(command.note, 'lunch');
      expect(command.isExcludedFromStats, true);
      expect(command.isExcludedFromBudget, true);
    });

    test('creates a transaction with the selected counterparty id', () async {
      final posting = _FakeTransactionPostingAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        postingService: posting,
        advanceOrchestrationService: orchestration,
        settlementAccounts: [_account('cash')],
        counterparties: const [CounterpartyView(id: 'cp-ziroom', name: '自如')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setExpenseCategory(rootId: 'food', categoryId: 'lunch')
        ..setFromAccountId('cash')
        ..setCounterpartyId('cp-ziroom');

      final outcome = await viewModel.submit(amountText: '12.34', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      expect(
        orchestration.createSceneCommands.single.counterpartyId,
        'cp-ziroom',
      );
    });

    test('uses explicit category-led allocations in allocated mode', () async {
      final posting = _FakeTransactionPostingAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        postingService: posting,
        advanceOrchestrationService: orchestration,
        settlementAccounts: [_account('cash'), _account('bank')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setExpenseCategory(rootId: 'food', categoryId: 'food')
        ..setFromAccountId('cash')
        ..useAllocatedEntry(const Money(minorUnits: 1000))
        ..setCategoryAllocations(const [
          AccountAmountAllocation(
            accountId: 'food',
            amount: Money(minorUnits: 800),
          ),
          AccountAmountAllocation(
            accountId: 'travel',
            amount: Money(minorUnits: 700),
          ),
        ])
        ..setSettlementAllocations(const [
          AccountAmountAllocation(
            accountId: 'cash',
            amount: Money(minorUnits: 900),
          ),
          AccountAmountAllocation(
            accountId: 'bank',
            amount: Money(minorUnits: 600),
          ),
        ]);

      final outcome = await viewModel.submit(amountText: '15', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = orchestration.createSceneCommands.single;
      expect(command.amount, const Money(minorUnits: 1500));
      expect(
        command.categoryAllocations.map((item) => item.amount.minorUnits),
        [800, 700],
      );
      expect(
        command.settlementAllocations.map((item) => item.amount.minorUnits),
        [900, 600],
      );
    });

    test(
      'rejects allocated payment totals that do not match categories',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final orchestration = _FakeAdvanceOrchestrationAppService();
        final container = _container(
          postingService: posting,
          advanceOrchestrationService: orchestration,
          settlementAccounts: [_account('cash')],
        );
        final viewModel = container.read(_provider().notifier);

        viewModel
          ..useAllocatedEntry(Money.zero())
          ..setCategoryAllocations(const [
            AccountAmountAllocation(
              accountId: 'food',
              amount: Money(minorUnits: 1500),
            ),
          ])
          ..setSettlementAllocations(const [
            AccountAmountAllocation(
              accountId: 'cash',
              amount: Money(minorUnits: 1400),
            ),
          ]);

        final outcome = await viewModel.submit(amountText: '15', noteText: '');

        expect(outcome, isA<SubmitFailure>());
        expect(orchestration.createSceneCommands, isEmpty);
      },
    );

    test('switching allocated expense back to normal clears selections', () {
      final container = _container(settlementAccounts: [_account('cash')]);
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setExpenseCategory(rootId: 'food', categoryId: 'food')
        ..setFromAccountId('cash')
        ..useAllocatedEntry(const Money(minorUnits: 1000))
        ..useNormalEntry();

      final state = container.read(_provider()).requireValue!;
      expect(state.entryMode, TransactionEntryMode.normal);
      expect(state.expenseCategoryId, isNull);
      expect(state.fromAccountId, isNull);
      expect(state.categoryAllocations, isEmpty);
      expect(state.settlementAllocations, isEmpty);
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

    test('creates advance command when account is selected', () async {
      final posting = _FakeTransactionPostingAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        postingService: posting,
        advanceOrchestrationService: orchestration,
        settlementAccounts: [_account('cash')],
        advanceReceivableAccounts: [_account('company')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setExpenseCategory(rootId: 'travel', categoryId: 'taxi')
        ..setFromAccountId('cash')
        ..setAdvanceAccountId('company');

      final outcome = await viewModel.submit(amountText: '20', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = orchestration.createSceneCommands.single;
      expect(command.amount, const Money(minorUnits: 2000));
      expect(command.settlementAllocations.single.accountId, 'cash');
      expect(command.categoryAllocations.single.accountId, 'taxi');
      final target = command.target as ItemizedAdvanceSceneTarget;
      expect(target.receivableAccountId, 'company');
      expect(target.scenario, AdvanceScenario.reimbursement);
    });

    for (final scenario in [
      (
        TransactionExpenseScene.reimbursement,
        AdvanceScenario.reimbursement,
        AdvanceTrackingMode.itemized,
      ),
      (
        TransactionExpenseScene.reimbursementAccount,
        AdvanceScenario.reimbursement,
        AdvanceTrackingMode.account,
      ),
      (
        TransactionExpenseScene.onBehalf,
        AdvanceScenario.onBehalf,
        AdvanceTrackingMode.itemized,
      ),
      (
        TransactionExpenseScene.onBehalfAccount,
        AdvanceScenario.onBehalf,
        AdvanceTrackingMode.account,
      ),
    ]) {
      test(
        'creates a full advance for ${scenario.$1.name} without amount input',
        () async {
          final posting = _FakeTransactionPostingAppService();
          final orchestration = _FakeAdvanceOrchestrationAppService();
          final container = _container(
            postingService: posting,
            advanceOrchestrationService: orchestration,
            settlementAccounts: [_account('cash')],
            advanceReceivableAccounts: [_account('company')],
          );
          final viewModel = container.read(_provider().notifier);

          viewModel
            ..setExpenseCategory(rootId: 'travel', categoryId: 'taxi')
            ..setFromAccountId('cash')
            ..setExpenseScene(scenario.$1)
            ..setAdvanceAccountId('company');

          final outcome = await viewModel.submit(
            amountText: '20',
            noteText: '',
          );

          expect(outcome, isA<SubmitSuccess>());
          final command = orchestration.createSceneCommands.single;
          expect(command.amount, const Money(minorUnits: 2000));
          switch (scenario.$3) {
            case AdvanceTrackingMode.itemized:
              final target = command.target as ItemizedAdvanceSceneTarget;
              expect(target.scenario, scenario.$2);
            case AdvanceTrackingMode.account:
              final target = command.target as AccountAdvanceSceneTarget;
              expect(target.scenario, scenario.$2);
          }
        },
      );
    }

    test('computes AA self-borne shares across multiple categories', () async {
      final posting = _FakeTransactionPostingAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        postingService: posting,
        advanceOrchestrationService: orchestration,
        settlementAccounts: [_account('cash')],
        advanceReceivableAccounts: [_account('company')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..useAllocatedEntry(const Money(minorUnits: 30000))
        ..setCategoryAllocations(const [
          AccountAmountAllocation(
            accountId: 'food',
            amount: Money(minorUnits: 12000),
          ),
          AccountAmountAllocation(
            accountId: 'travel',
            amount: Money(minorUnits: 18000),
          ),
        ])
        ..setSettlementAllocations(const [
          AccountAmountAllocation(
            accountId: 'cash',
            amount: Money(minorUnits: 30000),
          ),
        ])
        ..setAdvanceAccountId('company')
        ..setAdvanceScenario(AdvanceScenario.aa)
        ..setAaPeopleCount(3);

      final outcome = await viewModel.submit(amountText: '300', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = orchestration.createSceneCommands.single;
      expect(
        command.categoryAllocations.map((item) => item.amount.minorUnits),
        [12000, 18000],
      );
      final target = command.target as ItemizedAdvanceSceneTarget;
      expect(target.scenario, AdvanceScenario.aa);
      expect(target.aaPeopleCount, 3);
    });

    test('creates an account-managed AA advance', () async {
      final posting = _FakeTransactionPostingAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        postingService: posting,
        advanceOrchestrationService: orchestration,
        settlementAccounts: [_account('cash')],
        advanceReceivableAccounts: [_account('company')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setExpenseCategory(rootId: 'travel', categoryId: 'taxi')
        ..setFromAccountId('cash')
        ..setExpenseScene(TransactionExpenseScene.aaAccount)
        ..setAdvanceAccountId('company')
        ..setAaPeopleCount(3);

      final outcome = await viewModel.submit(amountText: '30', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = orchestration.createSceneCommands.single;
      final target = command.target as AccountAdvanceSceneTarget;
      expect(target.scenario, AdvanceScenario.aa);
      expect(target.aaPeopleCount, 3);
    });

    test(
      'rounds AA per-person up and assigns category remainder to the last row',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final orchestration = _FakeAdvanceOrchestrationAppService();
        final container = _container(
          postingService: posting,
          advanceOrchestrationService: orchestration,
          settlementAccounts: [_account('cash')],
          advanceReceivableAccounts: [_account('company')],
        );
        final viewModel = container.read(_provider().notifier);

        viewModel
          ..useAllocatedEntry(const Money(minorUnits: 10000))
          ..setCategoryAllocations(const [
            AccountAmountAllocation(
              accountId: 'food',
              amount: Money(minorUnits: 4000),
            ),
            AccountAmountAllocation(
              accountId: 'travel',
              amount: Money(minorUnits: 6000),
            ),
          ])
          ..setSettlementAllocations(const [
            AccountAmountAllocation(
              accountId: 'cash',
              amount: Money(minorUnits: 10000),
            ),
          ])
          ..setAdvanceAccountId('company')
          ..setAdvanceScenario(AdvanceScenario.aa)
          ..setAaPeopleCount(3);

        final outcome = await viewModel.submit(amountText: '100', noteText: '');

        expect(outcome, isA<SubmitSuccess>());
        final command = orchestration.createSceneCommands.single;
        final target = command.target as ItemizedAdvanceSceneTarget;
        expect(target.aaPeopleCount, 3);
        expect(target.scenario, AdvanceScenario.aa);
        expect(command.categoryAllocations.map((item) => item.amount), [
          const Money(minorUnits: 4000),
          const Money(minorUnits: 6000),
        ]);
      },
    );

    test(
      'loads AA headcount from its orchestration case while editing',
      () async {
        final container = _container(
          editTransactionId: 'aa-1',
          editDetail: _aaAdvanceDetail(),
          editAdvanceCase: const AdvanceCase(
            id: 'aa-1',
            scenario: AdvanceScenario.aa,
            trackingMode: AdvanceTrackingMode.itemized,
            aaPeopleCount: 9,
          ),
          accountsById: {
            'food': _account('food', type: AccountType.expense),
            'cash': _account('cash'),
            'company': _account('company'),
          },
          settlementAccounts: [_account('cash')],
          advanceReceivableAccounts: [_account('company')],
        );

        final state = container
            .read(_provider(editTransactionId: 'aa-1'))
            .requireValue!;

        expect(state.expenseScene, TransactionExpenseScene.aa);
        expect(state.aaPeopleCount, 9);
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
      expect(command.categoryAllocations.single.accountId, 'salary');
      expect(command.settlementAllocations.single.accountId, 'bank');
      expect(command.isExcludedFromStats, true);
    });

    test('creates income with multiple categories and accounts', () async {
      final posting = _FakeTransactionPostingAppService();
      final container = _container(
        postingService: posting,
        settlementAccounts: [_account('bank'), _account('cash')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setMode(TransactionFormMode.income)
        ..setIncomeCategory(rootId: 'salary', categoryId: 'salary')
        ..setToAccountId('bank')
        ..useAllocatedEntry(const Money(minorUnits: 1000))
        ..setCategoryAllocations(const [
          AccountAmountAllocation(
            accountId: 'salary',
            amount: Money(minorUnits: 800),
          ),
          AccountAmountAllocation(
            accountId: 'bonus',
            amount: Money(minorUnits: 700),
          ),
        ])
        ..setSettlementAllocations(const [
          AccountAmountAllocation(
            accountId: 'bank',
            amount: Money(minorUnits: 900),
          ),
          AccountAmountAllocation(
            accountId: 'cash',
            amount: Money(minorUnits: 600),
          ),
        ]);

      final outcome = await viewModel.submit(amountText: '15', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = posting.incomeCommands.single;
      expect(command.categoryAllocations.map((item) => item.accountId), [
        'salary',
        'bonus',
      ]);
      expect(
        command.categoryAllocations.map((item) => item.amount.minorUnits),
        [800, 700],
      );
      expect(command.settlementAllocations.map((item) => item.accountId), [
        'bank',
        'cash',
      ]);
      expect(
        command.settlementAllocations.map((item) => item.amount.minorUnits),
        [900, 600],
      );
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
        ..setToAccountId('bank')
        ..setCounterpartyId('cp-ziroom');

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
      expect(command.counterpartyId, 'cp-ziroom');
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
          advanceReceivableAccounts: [_account('advance')],
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

    test(
      'uses the deposit relation scene with the lending primitive',
      () async {
        final posting = _FakeTransactionPostingAppService();
        final orchestration = _FakeAdvanceOrchestrationAppService();
        final container = _container(
          postingService: posting,
          advanceOrchestrationService: orchestration,
          fundAccounts: [_account('cash')],
          ordinaryReceivableAccounts: [_account('deposit')],
        );
        final viewModel = container.read(_provider().notifier);

        viewModel.setRelationScene(TransactionRelationScene.deposit);
        expect(viewModel.state.requireValue!.mode, TransactionFormMode.lending);
        expect(
          viewModel.state.requireValue!.relationScene,
          TransactionRelationScene.deposit,
        );
        viewModel
          ..setFromAccountId('cash')
          ..setOrdinaryReceivableAccountId('deposit');

        final outcome = await viewModel.submit(
          amountText: '1000',
          noteText: '租房押金',
        );

        expect(outcome, isA<SubmitSuccess>());
        final command = posting.lendingCommands.single;
        expect(command.paidFromAccountId, 'cash');
        expect(command.receivableAccountId, 'deposit');
        expect(command.note, '租房押金');
        expect(orchestration.createSceneCommands, isEmpty);
      },
    );

    test('uses a receivable account as a daily expense account', () async {
      final posting = _FakeTransactionPostingAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        postingService: posting,
        advanceOrchestrationService: orchestration,
        settlementAccounts: [_account('cash')],
        ordinaryReceivableAccounts: [_account('deposit')],
      );
      final viewModel = container.read(_provider().notifier);

      viewModel
        ..setExpenseCategory(rootId: 'rental', categoryId: 'deduction')
        ..setFromAccountId('deposit');

      final outcome = await viewModel.submit(
        amountText: '200',
        noteText: '家具破损扣除押金',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = orchestration.createSceneCommands.single;
      expect(command.settlementAllocations.single.accountId, 'deposit');
      expect(
        command.settlementAllocations.single.amount,
        const Money(minorUnits: 20000),
      );
    });

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
        final orchestration = _FakeAdvanceOrchestrationAppService();
        final container = _container(
          postingService: posting,
          advanceOrchestrationService: orchestration,
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
        expect(orchestration.createSceneCommands, isEmpty);
      },
    );

    test('maps business exceptions to submit failure', () async {
      final orchestration = _FakeAdvanceOrchestrationAppService(
        exception: BusinessException(
          LedgerErrorCode.accountInvalidRole,
          message: '账户不能用于当前交易。',
        ),
      );
      final container = _container(
        advanceOrchestrationService: orchestration,
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
      final orchestration = _FakeAdvanceOrchestrationAppService(
        exception: unexpected,
      );
      final container = _container(
        advanceOrchestrationService: orchestration,
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

    test('submits ordinary expense conversion through orchestration', () async {
      final editService = _FakeTransactionEditAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        editService: editService,
        advanceOrchestrationService: orchestration,
        editTransactionId: 'tx-1',
        editDetail: _transactionDetail(),
        accountsById: {
          'cash': _account('cash'),
          'food': _account('food', type: AccountType.expense),
          'company': _account('company'),
        },
        settlementAccounts: [_account('cash')],
        advanceReceivableAccounts: [_account('company')],
      );
      final viewModel = container.read(
        _provider(editTransactionId: 'tx-1').notifier,
      );

      viewModel
        ..setExpenseCategory(rootId: 'travel', categoryId: 'hotel')
        ..setFromAccountId('cash')
        ..setExpenseScene(TransactionExpenseScene.reimbursement)
        ..setAdvanceAccountId('company');

      final outcome = await viewModel.submit(amountText: '30', noteText: '');

      expect(outcome, isA<SubmitSuccess>());
      final command = orchestration.expenseSceneCommands.single;
      expect(command.transactionId, 'tx-1');
      final target = command.target as ItemizedAdvanceSceneTarget;
      expect(target.receivableAccountId, 'company');
      expect(command.categoryAllocations!.single.accountId, 'hotel');
    });

    test('saves a loaded daily expense without changing its fields', () async {
      final editService = _FakeTransactionEditAppService();
      final orchestration = _FakeAdvanceOrchestrationAppService();
      final container = _container(
        editService: editService,
        advanceOrchestrationService: orchestration,
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
      final command = orchestration.expenseSceneCommands.single;
      expect(command.target, isA<OrdinaryExpenseSceneTarget>());
      expect(command.transactionId, 'tx-1');
      expect(command.amount, const Money(minorUnits: 1234));
      expect(command.settlementAllocations!.single.accountId, 'cash');
      expect(command.categoryAllocations!.single.accountId, 'food');
      expect(command.note, isA<PatchSet<String?>>());
      expect((command.note as PatchSet<String?>).value, 'note');
    });

    test(
      'loads and updates the counterparty through the edit command',
      () async {
        final editService = _FakeTransactionEditAppService();
        final orchestration = _FakeAdvanceOrchestrationAppService();
        final container = _container(
          editService: editService,
          advanceOrchestrationService: orchestration,
          editTransactionId: 'tx-1',
          editDetail: _transactionDetail(counterpartyId: 'cp-ziroom'),
          accountsById: {
            'cash': _account('cash'),
            'food': _account('food', type: AccountType.expense),
          },
          settlementAccounts: [_account('cash')],
        );
        final viewModel = container.read(
          _provider(editTransactionId: 'tx-1').notifier,
        );
        expect(
          container
              .read(_provider(editTransactionId: 'tx-1'))
              .requireValue!
              .counterpartyId,
          'cp-ziroom',
        );

        viewModel.setCounterpartyId(null);
        final outcome = await viewModel.submit(
          amountText: '12.34',
          noteText: 'note',
        );

        expect(outcome, isA<SubmitSuccess>());
        expect(
          orchestration.expenseSceneCommands.single.counterpartyId,
          isA<PatchClear<String?>>(),
        );
      },
    );

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
  AdvanceOrchestrationAppService? advanceOrchestrationService,
  AdvanceCaseRepository? advanceCaseRepository,
  AdvanceCase? editAdvanceCase,
  TransactionQueryService? transactionQueryService,
  String? editTransactionId,
  TransactionReadModel? editDetail,
  Map<String, Account> accountsById = const {},
  List<Account> settlementAccounts = const [],
  List<Account> fundAccounts = const [],
  List<Account> liabilityAccounts = const [],
  List<Account> advanceReceivableAccounts = const [],
  List<Account> ordinaryReceivableAccounts = const [],
  List<CounterpartyView> counterparties = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      transactionPostingAppServiceProvider.overrideWith(
        (ref) => postingService ?? _FakeTransactionPostingAppService(),
      ),
      transactionEditAppServiceProvider.overrideWith(
        (ref) => editService ?? _FakeTransactionEditAppService(),
      ),
      advanceOrchestrationAppServiceProvider.overrideWithValue(
        advanceOrchestrationService ?? _FakeAdvanceOrchestrationAppService(),
      ),
      advanceCaseRepositoryProvider.overrideWithValue(
        advanceCaseRepository ?? FakeAdvanceCaseRepository(),
      ),
      if (editAdvanceCase != null)
        advanceCaseForFormProvider(
          editAdvanceCase.id,
        ).overrideWith((ref) => editAdvanceCase),
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
        AccountSelectionPurpose.advanceReceivable,
      ).overrideWithValue(AsyncData(advanceReceivableAccounts)),
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
      counterpartyListProvider.overrideWithValue(AsyncData(counterparties)),
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

TransactionReadModel _transactionDetail({String? counterpartyId}) {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'tx-1',
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 2, 8, 30),
      primaryAmount: const Money(minorUnits: 1234),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      counterpartyId: counterpartyId,
      note: 'note',
    ),
    createdAt: DateTime(2026, 1, 2, 8, 30),
    lines: const [
      TransactionLine(
        id: 'category',
        transactionId: 'tx-1',
        lineNo: 1,
        role: TransactionRole.category,
        accountId: 'food',
        amount: Money(minorUnits: 1234),
      ),
      TransactionLine(
        id: 'settlement',
        transactionId: 'tx-1',
        lineNo: 2,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: Money(minorUnits: 1234),
      ),
    ],
  );
}

TransactionReadModel _lendingTransactionDetail() {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'lending-1',
      businessPurpose: BusinessPurpose.lending,
      occurredAt: DateTime(2026, 8, 21),
      primaryAmount: const Money(minorUnits: 5000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
    ),
    createdAt: DateTime(2026, 8, 21),
    lines: const [
      TransactionLine(
        id: 'receivable',
        transactionId: 'lending-1',
        lineNo: 1,
        role: TransactionRole.receivable,
        accountId: 'receivable',
        amount: Money(minorUnits: 5000),
      ),
      TransactionLine(
        id: 'settlement',
        transactionId: 'lending-1',
        lineNo: 2,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: Money(minorUnits: 5000),
      ),
    ],
  );
}

TransactionReadModel _aaAdvanceDetail() {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'aa-1',
      businessPurpose: BusinessPurpose.advance,
      occurredAt: DateTime(2026, 1, 2, 8, 30),
      primaryAmount: const Money(minorUnits: 1000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      ownership: advanceOwnership(
        management: AdvanceTrackingMode.itemized,
        ownerId: 'aa-1',
        scenario: AdvanceScenario.aa,
      ),
    ),
    createdAt: DateTime(2026, 1, 2, 8, 30),
    lines: const [
      TransactionLine(
        id: 'category',
        transactionId: 'aa-1',
        lineNo: 1,
        role: TransactionRole.advanceExpenseCategory,
        accountId: 'food',
        amount: Money(minorUnits: 1000),
      ),
      TransactionLine(
        id: 'self-borne',
        transactionId: 'aa-1',
        lineNo: 2,
        role: TransactionRole.advanceSelfBorne,
        accountId: 'food',
        amount: Money(minorUnits: 104),
      ),
      TransactionLine(
        id: 'receivable',
        transactionId: 'aa-1',
        lineNo: 3,
        role: TransactionRole.receivable,
        accountId: 'company',
        amount: Money(minorUnits: 896),
      ),
      TransactionLine(
        id: 'settlement',
        transactionId: 'aa-1',
        lineNo: 4,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: Money(minorUnits: 1000),
      ),
    ],
  );
}

TransactionReadModel _transferTransactionDetail() {
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
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'transfer-1',
      businessPurpose: BusinessPurpose.transfer,
      occurredAt: DateTime(2026, 8, 22),
      primaryAmount: amount,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      lines: lines,
    ),
    createdAt: DateTime(2026, 8, 22),
    lines: lines,
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

class _FakeAdvanceOrchestrationAppService
    implements AdvanceOrchestrationAppService {
  _FakeAdvanceOrchestrationAppService({this.exception});

  final Object? exception;
  final createCommands = <CreateAdvanceWorkflowCommand>[];
  final createSceneCommands = <CreateExpenseSceneWorkflowCommand>[];
  final editCommands = <EditAdvanceWorkflowCommand>[];
  final expenseSceneCommands = <EditExpenseSceneWorkflowCommand>[];

  @override
  Future<String> createAdvance(CreateAdvanceWorkflowCommand command) async {
    createCommands.add(command);
    return 'advance-transaction';
  }

  @override
  Future<String> createExpenseScene(
    CreateExpenseSceneWorkflowCommand command,
  ) async {
    if (exception case final exception?) throw exception;
    createSceneCommands.add(command);
    return 'expense-transaction';
  }

  @override
  Future<String> editAdvance(EditAdvanceWorkflowCommand command) async {
    editCommands.add(command);
    return command.transactionId;
  }

  @override
  Future<String> editExpenseScene(
    EditExpenseSceneWorkflowCommand command,
  ) async {
    expenseSceneCommands.add(command);
    return command.transactionId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTransactionPostingAppService
    implements
        TransactionPostingAppService,
        ReceivableTransactionPostingAppService {
  final incomeCommands = <CreateIncomeCommand>[];
  final transferCommands = <CreateTransferCommand>[];
  final borrowingCommands = <CreateBorrowingCommand>[];
  final lendingCommands = <CreateLendingCommand>[];

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
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
  Future<PostedTransactionResult> createAdvance(
    CreateAdvanceCommand command,
  ) async {
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
    return const PostedTransactionResult(transactionId: 'transaction-1');
  }

  @override
  Future<PostedTransactionResult> adjustBalance(AdjustBalanceCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> settleAdvance(
    CreateAdvanceSettlementCommand command,
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
  Future<PostedTransactionResult> createAdvanceCollection(
    CreateAdvanceCollectionCommand command,
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
  final transferCommands = <EditTransferCommand>[];
  final lendingCommands = <EditLendingCommand>[];
  final deletedTransactionIds = <String>[];

  @override
  Future<PostedTransactionResult> editExpense(
    EditExpenseCommand command,
  ) async {
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
  Future<PostedTransactionResult> editAdvance(
    EditAdvanceCommand command,
  ) async {
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
  Future<PostedTransactionResult> editAdvanceSettlement(
    EditAdvanceSettlementCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editAdvanceCollection(
    EditAdvanceCollectionCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editRepayment(EditRepaymentCommand command) {
    throw UnimplementedError();
  }
}
