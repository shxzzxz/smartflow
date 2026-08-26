import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/receivable_payable_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test('loads collection edit roles when principal equals interest', () async {
    final editing = _FakeEditService();
    final container = _container(editing: editing, detail: _collectionDetail());
    const args = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.collection,
      transactionId: 'collection',
    );
    final provider = receivablePayableFormViewModelProvider(args);

    final state = await container.read(provider.future);

    expect(state.accountId, 'receivable');
    expect(state.receiveAccountId, 'fund');
    expect(state.amountText, '100');
    expect(state.interestText, '100');
    expect(
      container.read(provider.notifier).balanceCrossingConfirmation('130'),
      isNotNull,
    );

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '100', interestText: '100', noteText: '');

    expect(outcome, isA<SubmitSuccess>());
    expect(editing.collectionCommands.single.receivableAccountId, 'receivable');
    expect(editing.collectionCommands.single.receiveAccountId, 'fund');
  });

  test('submits a new collection with its account and amount fields', () async {
    final posting = _FakePostingService();
    final container = _container(posting: posting);
    const args = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.collection,
      accountId: 'receivable',
    );
    final provider = receivablePayableFormViewModelProvider(args);
    await container.read(provider.future);

    final outcome = await container
        .read(provider.notifier)
        .submit(
          amountText: '100',
          interestText: '2.50',
          noteText: 'collection',
        );

    expect(outcome, isA<SubmitSuccess>());
    final command = posting.collectionCommands.single;
    expect(command.principal, const Money(minorUnits: 10000));
    expect(command.interest, const Money(minorUnits: 250));
    expect(command.receivableAccountId, 'receivable');
    expect(command.receiveAccountId, 'fund');
    expect(command.note, 'collection');
  });

  test('maps regular submit exceptions without exposing details', () async {
    final posting = _FakePostingService(
      exception: Exception('database failed'),
    );
    final container = _container(posting: posting);
    const args = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.collection,
      accountId: 'receivable',
    );
    final provider = receivablePayableFormViewModelProvider(args);
    await container.read(provider.future);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '10', interestText: '0', noteText: '');

    expect(outcome, isA<SubmitFailure>());
    final error = (outcome as SubmitFailure).error;
    expect(error.code, 'unknown');
    expect(error.message, isNot(contains('database')));
    expect(container.read(provider).requireValue.submitting, isFalse);
  });

  test('does not swallow Error at the submit boundary', () async {
    final posting = _FakePostingService(error: StateError('programming bug'));
    final container = _container(posting: posting);
    const args = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.collection,
      accountId: 'receivable',
    );
    final provider = receivablePayableFormViewModelProvider(args);
    await container.read(provider.future);

    await expectLater(
      container
          .read(provider.notifier)
          .submit(amountText: '10', interestText: '0', noteText: ''),
      throwsA(isA<StateError>()),
    );
    expect(container.read(provider).requireValue.submitting, isFalse);
  });

  test('submits bad debt reporting flags for creation and editing', () async {
    final posting = _FakePostingService();
    final editing = _FakeEditService();
    final createContainer = _container(posting: posting, editing: editing);
    const createArgs = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.badDebt,
      accountId: 'receivable',
    );
    final createProvider = receivablePayableFormViewModelProvider(createArgs);
    final createViewModel = createContainer.read(createProvider.notifier);
    await createContainer.read(createProvider.future);
    createViewModel
      ..setExcludeStats(true)
      ..setExcludeBudget(true);

    await createViewModel.submit(
      amountText: '10',
      interestText: '',
      noteText: 'write off',
    );

    final createCommand = posting.badDebtCommands.single;
    expect(createCommand.amount, const Money(minorUnits: 1000));
    expect(createCommand.receivableAccountId, 'receivable');
    expect(createCommand.note, 'write off');
    expect(createCommand.isExcludedFromStats, isTrue);
    expect(createCommand.isExcludedFromBudget, isTrue);

    final editContainer = _container(
      posting: posting,
      editing: editing,
      detail: _badDebtDetail(),
    );
    const editArgs = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.badDebt,
      transactionId: 'collection',
    );
    final editProvider = receivablePayableFormViewModelProvider(editArgs);
    final editViewModel = editContainer.read(editProvider.notifier);
    final editState = await editContainer.read(editProvider.future);
    expect(editState.excludeStats, isTrue);
    expect(editState.excludeBudget, isTrue);

    await editViewModel.submit(
      amountText: '10',
      interestText: '',
      noteText: 'updated write off',
    );

    final editCommand = editing.badDebtCommands.single;
    expect(editCommand.amount, const Money(minorUnits: 1000));
    expect(editCommand.receivableAccountId, 'receivable');
    expect(editCommand.note, isA<PatchSet<String?>>());
    expect((editCommand.note as PatchSet<String?>).value, 'updated write off');
    expect(editCommand.isExcludedFromStats, isTrue);
    expect(editCommand.isExcludedFromBudget, isTrue);
  });

  test('submits debt relief statistics exclusion', () async {
    final posting = _FakePostingService();
    final container = _container(posting: posting);
    const args = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.debtRelief,
      accountId: 'payable',
    );
    final provider = receivablePayableFormViewModelProvider(args);
    final viewModel = container.read(provider.notifier);
    await container.read(provider.future);
    viewModel.setExcludeStats(true);

    await viewModel.submit(amountText: '10', interestText: '', noteText: '');

    expect(posting.debtReliefCommands.single.isExcludedFromStats, isTrue);
  });

  test('loads and submits debt relief editing fields', () async {
    final editing = _FakeEditService();
    final container = _container(editing: editing, detail: _debtReliefDetail());
    const args = ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.debtRelief,
      transactionId: 'collection',
    );
    final provider = receivablePayableFormViewModelProvider(args);

    final state = await container.read(provider.future);
    expect(state.accountId, 'payable');
    expect(state.excludeStats, isTrue);

    final outcome = await container
        .read(provider.notifier)
        .submit(amountText: '10', interestText: '', noteText: 'relief');

    expect(outcome, isA<SubmitSuccess>());
    final command = editing.debtReliefCommands.single;
    expect(command.transactionId, 'collection');
    expect(command.amount, const Money(minorUnits: 1000));
    expect(command.liabilityAccountId, 'payable');
    expect(command.isExcludedFromStats, isTrue);
    expect(command.note, isA<PatchSet<String?>>());
    expect((command.note as PatchSet<String?>).value, 'relief');
  });
}

ProviderContainer _container({
  _FakePostingService? posting,
  _FakeEditService? editing,
  TransactionDetail? detail,
}) {
  final receivable = Account(
    id: 'receivable',
    name: '应收',
    type: AccountType.asset,
    subtype: AccountSubtype.receivable,
    balance: const Money(minorUnits: 2000),
  );
  final fund = Account(
    id: 'fund',
    name: '资金',
    type: AccountType.asset,
    subtype: AccountSubtype.fund,
    balance: const Money(minorUnits: 100000),
  );
  final interest = Account(
    id: 'interest',
    name: '利息收入',
    type: AccountType.income,
    balance: const Money(minorUnits: 0),
  );
  final container = ProviderContainer(
    overrides: [
      accountsByIdProvider.overrideWithValue(
        AsyncData({
          receivable.id: receivable,
          fund.id: fund,
          interest.id: interest,
          'payable': Account(
            id: 'payable',
            name: '应付',
            type: AccountType.liability,
            subtype: AccountSubtype.payable,
            balance: const Money(minorUnits: 2000),
          ),
        }),
      ),
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.fund,
      ).overrideWithValue(AsyncData([fund])),
      transactionPostingAppServiceProvider.overrideWithValue(
        posting ?? _FakePostingService(),
      ),
      transactionEditAppServiceProvider.overrideWithValue(
        editing ?? _FakeEditService(),
      ),
      if (detail != null)
        transactionDetailProvider(
          'collection',
        ).overrideWithValue(AsyncData(detail)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

TransactionDetail _badDebtDetail() => TransactionDetail(
  transaction: Transaction(
    id: 'collection',
    businessPurpose: BusinessPurpose.badDebt,
    occurredAt: DateTime(2026, 8, 20),
    primaryAmount: const Money(minorUnits: 1000),
    isExcludedFromStats: true,
    isExcludedFromBudget: true,
    sourceKind: SourceKind.manual,
    entries: [
      _entry('interest', EntryDirection.debit, 1000),
      _entry('receivable', EntryDirection.credit, 1000),
    ],
  ),
  createdAt: DateTime(2026, 8, 20),
  lines: const [
    TransactionLine(
      id: 'bad-debt-detail',
      transactionId: 'collection',
      lineNo: 1,
      role: TransactionRole.receivable,
      amount: Money(minorUnits: 1000),
    ),
  ],
  entries: [
    _entry('interest', EntryDirection.debit, 1000),
    _entry('receivable', EntryDirection.credit, 1000),
  ],
);

TransactionDetail _debtReliefDetail() => TransactionDetail(
  transaction: Transaction(
    id: 'collection',
    businessPurpose: BusinessPurpose.debtRelief,
    occurredAt: DateTime(2026, 8, 20),
    primaryAmount: const Money(minorUnits: 1000),
    isExcludedFromStats: true,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
    entries: [
      _entry('payable', EntryDirection.debit, 1000),
      _entry('interest', EntryDirection.credit, 1000),
    ],
  ),
  createdAt: DateTime(2026, 8, 20),
  lines: const [
    TransactionLine(
      id: 'debt-relief-detail',
      transactionId: 'collection',
      lineNo: 1,
      role: TransactionRole.liability,
      amount: Money(minorUnits: 1000),
    ),
  ],
  entries: [
    _entry('payable', EntryDirection.debit, 1000),
    _entry('interest', EntryDirection.credit, 1000),
  ],
);

TransactionDetail _collectionDetail() {
  final entries = [
    _entry('fund', EntryDirection.debit, 20000),
    _entry('interest', EntryDirection.credit, 10000),
    _entry('receivable', EntryDirection.credit, 10000),
  ];
  return TransactionDetail(
    transaction: Transaction(
      id: 'collection',
      businessPurpose: BusinessPurpose.receivableCollection,
      occurredAt: DateTime(2026, 8, 20),
      primaryAmount: const Money(minorUnits: 20000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      entries: entries,
    ),
    createdAt: DateTime(2026, 8, 20),
    lines: const [
      TransactionLine(
        id: 'principal',
        transactionId: 'collection',
        lineNo: 1,
        role: TransactionRole.receivable,
        amount: Money(minorUnits: 10000),
      ),
      TransactionLine(
        id: 'interest-detail',
        transactionId: 'collection',
        lineNo: 2,
        role: TransactionRole.interest,
        amount: Money(minorUnits: 10000),
      ),
    ],
    entries: entries,
  );
}

Entry _entry(String accountId, EntryDirection direction, int amountMinor) =>
    Entry(
      id: '$accountId-entry',
      transactionId: 'collection',
      accountId: accountId,
      direction: direction,
      amount: Money(minorUnits: amountMinor),
    );

class _FakePostingService
    implements
        TransactionPostingAppService,
        ReceivableTransactionPostingAppService {
  _FakePostingService({this.exception, this.error});

  final Exception? exception;
  final Error? error;
  final collectionCommands = <CreateReceivableCollectionCommand>[];
  final badDebtCommands = <CreateBadDebtCommand>[];
  final debtReliefCommands = <CreateDebtReliefCommand>[];

  @override
  Future<PostedTransactionResult> createReceivableCollection(
    CreateReceivableCollectionCommand command,
  ) async {
    if (exception != null) throw exception!;
    if (error != null) throw error!;
    collectionCommands.add(command);
    return const PostedTransactionResult(transactionId: 'collection');
  }

  @override
  Future<PostedTransactionResult> createBadDebt(
    CreateBadDebtCommand command,
  ) async {
    badDebtCommands.add(command);
    return const PostedTransactionResult(transactionId: 'bad-debt');
  }

  @override
  Future<PostedTransactionResult> createDebtRelief(
    CreateDebtReliefCommand command,
  ) async {
    debtReliefCommands.add(command);
    return const PostedTransactionResult(transactionId: 'debt-relief');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEditService
    implements TransactionEditAppService, ReceivableTransactionEditAppService {
  final collectionCommands = <EditReceivableCollectionCommand>[];
  final badDebtCommands = <EditBadDebtCommand>[];
  final debtReliefCommands = <EditDebtReliefCommand>[];

  @override
  Future<PostedTransactionResult> editReceivableCollection(
    EditReceivableCollectionCommand command,
  ) async {
    collectionCommands.add(command);
    return const PostedTransactionResult(transactionId: 'collection');
  }

  @override
  Future<PostedTransactionResult> editBadDebt(
    EditBadDebtCommand command,
  ) async {
    badDebtCommands.add(command);
    return const PostedTransactionResult(transactionId: 'bad-debt');
  }

  @override
  Future<PostedTransactionResult> editDebtRelief(
    EditDebtReliefCommand command,
  ) async {
    debtReliefCommands.add(command);
    return const PostedTransactionResult(transactionId: 'debt-relief');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
