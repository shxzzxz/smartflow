import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/page/account_advance_form_page.dart';
import 'package:smartflow/feature/transaction/view_model/advance_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('creates an account-managed reimbursement collection', () async {
    final posting = _FakePostingService();
    final target = const AccountAdvanceFormTarget(
      accountId: 'reimbursement',
      scenario: AdvanceScenario.reimbursement,
    );
    final container = _container(posting);
    final provider = accountAdvanceFormViewModelProvider(target);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final state = await container.read(provider.future);
    expect(state.actionLabel, '报销');
    expect(state.mode, AccountAdvanceFormMode.collection);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '20', noteText: '报销到账');

    expect(outcome, isA<SubmitSuccess>());
    final command = posting.collectionCommands.single;
    expect(command.management, AdvanceManagement.account);
    expect(command.scenario, AdvanceScenario.reimbursement);
    expect(command.advanceTransactionId, isNull);
    expect(command.receivableAccountId, 'reimbursement');
    expect(command.settlementAllocations.single.accountId, 'cash');
  });

  test('creates an account-managed AA settlement', () async {
    final posting = _FakePostingService();
    final target = const AccountAdvanceFormTarget(
      accountId: 'receivable',
      scenario: AdvanceScenario.aa,
    );
    final container = _container(posting);
    final provider = accountAdvanceFormViewModelProvider(target);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    final viewModel = container.read(provider.notifier);
    viewModel.setSettlement(true);
    final outcome = await viewModel.submit(amountText: '30', noteText: '');

    expect(outcome, isA<SubmitSuccess>());
    final command = posting.settlementCommands.single;
    expect(command.management, AdvanceManagement.account);
    expect(command.scenario, AdvanceScenario.aa);
    expect(command.advanceTransactionId, isNull);
    expect(command.actualReceivedAmount, const Money(minorUnits: 3000));
    expect(command.gapExpenseAllocations, isEmpty);
  });

  testWidgets('switches the account collection form to settlement', (
    tester,
  ) async {
    final container = _container(_FakePostingService());
    const target = AccountAdvanceFormTarget(
      accountId: 'reimbursement',
      scenario: AdvanceScenario.reimbursement,
    );
    final provider = accountAdvanceFormViewModelProvider(target);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountAdvanceFormPage(target: target),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('报销'), findsOneWidget);
    expect(find.text('到账金额'), findsOneWidget);
    expect(find.text('垫付结清'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('account-advance-settlement-switch')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('实收金额'), findsOneWidget);
    expect(find.text('确认账户垫付结清'), findsOneWidget);
  });
}

ProviderContainer _container(_FakePostingService posting) {
  final cash = Account(
    id: 'cash',
    name: '现金',
    type: AccountType.asset,
    subtype: AccountSubtype.fund,
    profileKey: AccountProfileKind.fund.key,
    balance: Money.zero(),
  );
  final reimbursement = Account(
    id: 'reimbursement',
    name: '公司报销',
    type: AccountType.asset,
    subtype: AccountSubtype.receivable,
    profileKey: AccountProfileKind.reimbursement.key,
    balance: Money.zero(),
  );
  final receivable = Account(
    id: 'receivable',
    name: '朋友应收',
    type: AccountType.asset,
    subtype: AccountSubtype.receivable,
    profileKey: AccountProfileKind.receivable.key,
    balance: Money.zero(),
  );
  final accounts = <String, Account>{
    cash.id: cash,
    reimbursement.id: reimbursement,
    receivable.id: receivable,
  };
  final container = ProviderContainer(
    overrides: [
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWithValue(AsyncData([cash])),
      accountLookupProvider.overrideWith(
        (ref) => Stream.value(AccountLookup(accounts)),
      ),
      transactionPostingAppServiceProvider.overrideWithValue(posting),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakePostingService implements TransactionPostingAppService {
  final collectionCommands = <CreateAdvanceCollectionCommand>[];
  final settlementCommands = <CreateAdvanceSettlementCommand>[];

  @override
  Future<PostedTransactionResult> createAdvanceCollection(
    CreateAdvanceCollectionCommand command,
  ) async {
    collectionCommands.add(command);
    return const PostedTransactionResult(transactionId: 'collection');
  }

  @override
  Future<PostedTransactionResult> settleAdvance(
    CreateAdvanceSettlementCommand command,
  ) async {
    settlementCommands.add(command);
    return const PostedTransactionResult(transactionId: 'settlement');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
