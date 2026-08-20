import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
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
    details: const [
      TransactionDetailRecord(
        id: 'principal',
        transactionId: 'collection',
        lineNo: 1,
        type: TransactionDetailType.receivableCollectionPrincipal,
        amount: Money(minorUnits: 10000),
      ),
      TransactionDetailRecord(
        id: 'interest-detail',
        transactionId: 'collection',
        lineNo: 2,
        type: TransactionDetailType.receivableCollectionInterest,
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

  @override
  Future<PostedTransactionResult> createReceivableCollection(
    CreateReceivableCollectionCommand command,
  ) async {
    if (exception != null) throw exception!;
    if (error != null) throw error!;
    return const PostedTransactionResult(transactionId: 'collection');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEditService
    implements TransactionEditAppService, ReceivableTransactionEditAppService {
  final collectionCommands = <EditReceivableCollectionCommand>[];

  @override
  Future<PostedTransactionResult> editReceivableCollection(
    EditReceivableCollectionCommand command,
  ) async {
    collectionCommands.add(command);
    return const PostedTransactionResult(transactionId: 'collection');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
