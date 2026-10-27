import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/page/advance_form_page.dart';
import 'package:smartflow/feature/transaction/view_model/advance_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import '../../../helper/advance_ownership_fixtures.dart';
import '../../../helper/fake_advance_case_repository.dart';

void main() {
  test(
    'settles shortfall as self-borne or bad debt from the same form',
    () async {
      final posting = _FakeAdvanceOrchestrationService();
      final container = _container(posting);
      final provider = advanceFormViewModelProvider('advance');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final viewModel = container.read(provider.notifier);
      final loaded = await container.read(provider.future);
      expect(loaded.status, AdvanceFormStatus.loaded);
      expect(loaded.isClose, isTrue);
      expect(loaded.shortfallKind, AdvanceShortfallKind.selfBorne);
      expect(viewModel.state.value?.status, AdvanceFormStatus.loaded);

      var outcome = await viewModel.submit(amountText: '30', noteText: '');

      expect(
        outcome,
        isA<SubmitSuccess>(),
        reason: outcome is SubmitFailure ? outcome.error.message : null,
      );
      expect(
        posting.commands.single.shortfallKind,
        AdvanceShortfallKind.selfBorne,
      );
      expect(
        posting.commands.single.gapExpenseAllocations.single.accountId,
        'food',
      );

      viewModel.setSelfBorne(false);
      outcome = await viewModel.submit(amountText: '30', noteText: '');

      expect(
        outcome,
        isA<SubmitSuccess>(),
        reason: outcome is SubmitFailure ? outcome.error.message : null,
      );
      expect(posting.commands.last.shortfallKind, AdvanceShortfallKind.badDebt);
      expect(posting.commands.last.gapExpenseAllocations, isEmpty);
    },
  );

  test(
    'rejects the itemized receipt form for account-managed advance',
    () async {
      final provider = advanceFormViewModelProvider('advance');
      final container = _container(
        _FakeAdvanceOrchestrationService(),
        advanceCaseRepository: FakeAdvanceCaseRepository(const [
          AdvanceCase(
            id: 'receivable',
            scenario: AdvanceScenario.reimbursement,
            trackingMode: AdvanceTrackingMode.account,
            receivableAccountId: 'receivable',
          ),
        ]),
        detail: _advanceDetail(
          ownership: advanceOwnership(
            management: AdvanceTrackingMode.account,
            ownerId: 'receivable',
            scenario: AdvanceScenario.reimbursement,
          ),
        ),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final state = await container.read(provider.future);

      expect(state.status, AdvanceFormStatus.notEditable);
    },
  );

  testWidgets('switches shortfall allocation between self-borne and bad debt', (
    tester,
  ) async {
    final container = _container(_FakeAdvanceOrchestrationService());
    final provider = advanceFormViewModelProvider('advance');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdvanceFormPage(advanceTransactionId: 'advance'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountField = find.byType(EditableText).first;
    await tester.enterText(amountField, '30');
    await tester.pumpAndSettle();

    final selfBorneSwitch = find.byKey(
      const ValueKey('advance-self-borne-switch'),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(selfBorneSwitch, findsOneWidget);
    expect(
      find.byKey(const ValueKey('advance-gap-allocations')),
      findsOneWidget,
    );
    expect(find.text('差额计入所选支出分类'), findsOneWidget);

    await tester.ensureVisible(selfBorneSwitch);
    await tester.tap(
      find.descendant(of: selfBorneSwitch, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(find.text('差额计入内置坏账损失分类'), findsOneWidget);
    expect(find.byKey(const ValueKey('advance-gap-allocations')), findsNothing);
    expect(find.byKey(const ValueKey('advance-gap-builtin')), findsOneWidget);
    expect(find.text('计入内置分类“坏账损失” 10.00'), findsOneWidget);
  });
}

ProviderContainer _container(
  _FakeAdvanceOrchestrationService posting, {
  TransactionReadModel? detail,
  FakeAdvanceCaseRepository? advanceCaseRepository,
}) {
  final cash = Account(
    id: 'cash',
    name: '现金',
    type: AccountType.asset,
    balance: Money.zero(),
  );
  final receivable = Account(
    id: 'receivable',
    name: '报销',
    type: AccountType.asset,
    subtype: AccountSubtype.receivable,
    profileKey: AccountProfileKind.reimbursement.key,
    balance: Money.zero(),
  );
  final food = Account(
    id: 'food',
    name: '餐饮',
    type: AccountType.expense,
    balance: Money.zero(),
  );
  final accounts = {cash.id: cash, receivable.id: receivable, food.id: food};
  final container = ProviderContainer(
    overrides: [
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWithValue(AsyncData([cash])),
      accountLookupProvider.overrideWith(
        (ref) => Stream.value(AccountLookup(accounts)),
      ),
      transactionDetailProvider(
        'advance',
      ).overrideWithValue(AsyncData(detail ?? _advanceDetail())),
      advanceOrchestrationAppServiceProvider.overrideWithValue(posting),
      advanceCaseRepositoryProvider.overrideWithValue(
        advanceCaseRepository ?? FakeAdvanceCaseRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

TransactionReadModel _advanceDetail({TransactionOwnership? ownership}) {
  return TransactionReadModel(
    id: 'advance',
    businessPurpose: BusinessPurpose.advance,
    occurredAt: DateTime(2026, 10, 23),
    primaryAmount: const Money(minorUnits: 4000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    ownership: ownership,
    impactsByAccountId: const {},
    lines: const [
      TransactionLine(
        id: 'advance-category',
        transactionId: 'advance',
        lineNo: 1,
        role: TransactionRole.advanceExpenseCategory,
        accountId: 'food',
        amount: Money(minorUnits: 4000),
      ),
      TransactionLine(
        id: 'advance-cash',
        transactionId: 'advance',
        lineNo: 2,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: Money(minorUnits: 4000),
      ),
      TransactionLine(
        id: 'advance-receivable',
        transactionId: 'advance',
        lineNo: 3,
        role: TransactionRole.receivable,
        accountId: 'receivable',
        amount: Money(minorUnits: 4000),
      ),
    ],
    refundSummary: RefundSummary(
      refundedTotal: Money.zero(),
      originalCategoryAllocations: const [
        AccountAmountAllocation(
          accountId: 'food',
          amount: Money(minorUnits: 4000),
        ),
      ],
      refundedCategoryAllocations: const [],
    ),
    advanceSummary: const AdvanceSummary(
      advanceAmount: Money(minorUnits: 4000),
      receivedAmount: Money(minorUnits: 0),
      outstanding: Money(minorUnits: 4000),
      isClosed: false,
    ),
  );
}

class _FakeAdvanceOrchestrationService
    implements AdvanceOrchestrationAppService {
  final commands = <CreateAdvanceSettlementWorkflowCommand>[];

  @override
  Future<String> createSettlement(
    CreateAdvanceSettlementWorkflowCommand command,
  ) async {
    commands.add(command);
    return 'settlement';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
