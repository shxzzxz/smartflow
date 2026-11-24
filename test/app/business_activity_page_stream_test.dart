import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail/transaction_detail_view_model.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/transaction_view/business_activity/drift_business_activity_change_source.dart';
import 'package:smartflow/infrastructure/transaction_view/business_activity/drift_ledger_business_activity_source.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_port_api.dart';

import '../helper/sequential_id_generator.dart';
import '../helper/test_app_database.dart';

void main() {
  test('failed content reads finish before the snapshot closes', () async {
    final container = await _fixture();
    await _createExpense(container);
    final database = container.read(appDatabaseProvider);
    final summaryStarted = Completer<void>();
    final finishSummary = Completer<void>();
    final summaryErrors = <Object>[];
    final queryErrors = <Object>[];
    final service = BusinessActivityQueryServiceImpl(
      sources: [
        _CandidateReadHook(
          DriftLedgerBusinessActivitySource(database),
          () async {},
          beforeSummary: () async {
            summaryStarted.complete();
            await finishSummary.future;
            try {
              await database.customSelect('SELECT 1').get();
            } catch (error) {
              summaryErrors.add(error);
            }
          },
        ),
      ],
      transactionQuery: _FailingTransactionQuery(),
      transactionRunner: container.read(transactionRunnerProvider),
      changes: DriftBusinessActivityChangeSource(database),
    );
    final queryFinished = service
        .findPage(_query())
        .then<void>(
          (_) => fail('Expected the transaction read to fail.'),
          onError: (Object error, StackTrace stackTrace) =>
              queryErrors.add(error),
        );
    await summaryStarted.future;
    await pumpEventQueue();
    finishSummary.complete();
    await queryFinished;
    await pumpEventQueue();

    expect(queryErrors, hasLength(1));
    expect(summaryErrors, isEmpty);
  });

  test(
    'keeps candidates and content in one snapshot during deletion',
    () async {
      final container = await _fixture();
      final transactionId = await _createExpense(container);
      final candidatesRead = Completer<void>();
      final deletionStarted = Completer<void>();
      // The competing command is registered outside the query transaction.
      final deletion = Future<void>(() async {
        await candidatesRead.future;
        deletionStarted.complete();
        await container
            .read(transactionEditAppServiceProvider)
            .deleteTransaction(
              DeleteTransactionCommand(transactionId: transactionId),
            );
      });
      final service = _pageService(
        container,
        afterRead: () async {
          if (candidatesRead.isCompleted) return;
          candidatesRead.complete();
          await deletionStarted.future;
          await pumpEventQueue(times: 100);
        },
      );

      final page = await service.findPage(_query());
      await deletion;

      expect(page.items.single.displayTransactionId, transactionId);
      expect(page.items.single.displayTransaction!.primaryAmount, _amount);
      expect((await service.findPage(_query())).items, isEmpty);
    },
  );

  test('page stream recovers after a failed read', () async {
    final container = await _fixture();
    final counterparties = container.read(counterpartyRepositoryProvider);
    await counterparties.insertCounterparty(id: 'merchant', name: '原商户');
    await _createExpense(container, counterpartyId: 'merchant');
    var failNextRead = false;
    final service = _pageService(
      container,
      afterRead: () async {
        if (!failNextRead) return;
        failNextRead = false;
        throw StateError('fixture read failure');
      },
    );
    final pages = <BusinessActivityPage>[];
    final errors = <Object>[];
    final subscription = service
        .watchPage(_query())
        .listen(pages.add, onError: errors.add);
    addTearDown(subscription.cancel);
    await _flush(container);
    expect(pages.last.items.single.displayTransaction!.counterpartyName, '原商户');

    failNextRead = true;
    await counterparties.renameCounterparty(id: 'merchant', name: '第一次改名');
    await _flush(container);
    expect(errors, hasLength(1));

    await counterparties.renameCounterparty(id: 'merchant', name: '再次改名');
    await _flush(container);
    expect(
      pages.last.items.single.displayTransaction!.counterpartyName,
      '再次改名',
    );
    expect(errors, hasLength(1));
  });

  test('one multi-table posting commit publishes one complete page', () async {
    final container = await _fixture();
    final pages = <BusinessActivityPage>[];
    final subscription = container
        .read(businessActivityQueryServiceProvider)
        .watchPage(_query())
        .listen(pages.add);
    addTearDown(subscription.cancel);
    await _flush(container);
    expect(pages, hasLength(1));

    final transactionId = await _createExpense(container);
    await _flush(container);

    expect(pages, hasLength(2));
    expect(pages.last.items.single.displayTransactionId, transactionId);
    expect(pages.last.items.single.displayTransaction!.primaryAmount, _amount);
  });

  test('budget changes do not refresh the activity page', () async {
    final container = await _fixture();
    await _createExpense(container);
    final pages = <BusinessActivityPage>[];
    final subscription = container
        .read(businessActivityQueryServiceProvider)
        .watchPage(_query())
        .listen(pages.add);
    addTearDown(subscription.cancel);
    await _flush(container);
    expect(pages, hasLength(1));

    final database = container.read(appDatabaseProvider);
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'budget',
            monthKey: 202611,
            amountMinor: 20000,
          ),
        );
    await _flush(container);

    expect(pages, hasLength(1));
  });

  test(
    'page stream refreshes when only the counterparty name changes',
    () async {
      final container = await _fixture();
      final counterparties = container.read(counterpartyRepositoryProvider);
      await counterparties.insertCounterparty(id: 'merchant', name: '旧商户');
      await _createExpense(container, counterpartyId: 'merchant');
      final pages = <BusinessActivityPage>[];
      final errors = <Object>[];
      final subscription = container
          .read(businessActivityQueryServiceProvider)
          .watchPage(_query())
          .listen(pages.add, onError: errors.add);
      addTearDown(subscription.cancel);
      await _flush(container);
      expect(
        pages.last.items.single.displayTransaction!.counterpartyName,
        '旧商户',
      );

      await counterparties.renameCounterparty(id: 'merchant', name: '新商户');
      await _flush(container);

      expect(
        pages.last.items.single.displayTransaction!.counterpartyName,
        '新商户',
      );
      expect(errors, isEmpty);
    },
  );

  for (final trackingMode in AdvanceTrackingMode.values) {
    test('detail deletion removes ${trackingMode.name} AA from home', () async {
      final container = await _fixture();
      final month = DateTime(2026, 11);
      final homeProvider = homeTransactionFeedViewModelProvider(month);
      final homeSubscription = container.listen(homeProvider, (_, _) {});
      addTearDown(homeSubscription.close);
      await container.read(homeBusinessActivitiesProvider(month).future);
      final queryErrors = <Object>[];
      final querySubscription = container.listen(
        homeBusinessActivitiesProvider(month),
        (_, next) {
          if (next case AsyncError(:final error)) queryErrors.add(error);
        },
      );
      addTearDown(querySubscription.close);

      for (var cycle = 0; cycle < 2; cycle++) {
        final transactionId = await container
            .read(advanceOrchestrationAppServiceProvider)
            .createAdvance(
              CreateAdvanceWorkflowCommand(
                amount: _amount,
                scenario: AdvanceScenario.aa,
                trackingMode: trackingMode,
                aaPeopleCount: 2,
                receivableAccountId: 'receivable',
                categoryAllocations: [_allocation('food')],
                settlementAllocations: [_allocation('cash')],
                occurredAt: DateTime(2026, 11, 24, 12),
              ),
            );
        await _flush(container);
        expect(
          (container.read(homeProvider) as HomeTransactionFeedLoaded).items.map(
            (item) => item.displayTransactionId,
          ),
          [transactionId],
        );

        final detailProvider = transactionDetailViewModelProvider(
          transactionId,
        );
        final detailSubscription = container.listen(detailProvider, (_, _) {});
        addTearDown(detailSubscription.close);
        await container.read(detailProvider.future);
        await _flush(container);
        expect(container.read(detailProvider).isLoading, isFalse);
        expect(
          container.read(detailProvider).value,
          isA<TransactionDetailLoaded>(),
        );

        final outcome = await container.read(detailProvider.notifier).delete();
        expect(outcome, isA<UiActionSuccess<void>>());
        await _flush(container);

        expect(queryErrors, isEmpty);
        expect(
          (container.read(homeProvider) as HomeTransactionFeedLoaded).items,
          isEmpty,
        );
        expect(
          container.read(detailProvider).value,
          isA<TransactionDetailNotFound>(),
        );
        detailSubscription.close();
      }
    });
  }
}

const _amount = Money(minorUnits: 10000);

AccountAmountAllocation _allocation(String accountId) =>
    AccountAmountAllocation(accountId: accountId, amount: _amount);

BusinessActivityPageQuery _query() => BusinessActivityPageQuery(
  occurredFrom: DateTime(2026, 11),
  occurredUntil: DateTime(2026, 12),
  limit: homeBusinessActivityPageSize,
);

Future<String> _createExpense(
  ProviderContainer container, {
  String? counterpartyId,
}) async {
  final result = await container
      .read(transactionPostingAppServiceProvider)
      .createExpense(
        CreateExpenseCommand(
          amount: _amount,
          categoryAllocations: [_allocation('food')],
          settlementAllocations: [_allocation('cash')],
          occurredAt: DateTime(2026, 11, 24, 10),
          counterpartyId: counterpartyId,
        ),
      );
  return result.transactionId;
}

Future<ProviderContainer> _fixture() async {
  final database = createTestDatabase();
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      currentDateTimeProvider.overrideWith((ref) => DateTime(2026, 11, 24)),
      idGeneratorProvider.overrideWithValue(
        SequentialIdGenerator(prefix: 'page'),
      ),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await pumpEventQueue(times: 100);
    await database.close();
  });
  final accounts = container.read(accountRepositoryProvider);
  for (final account in [
    Account(
      id: 'cash',
      name: '现金',
      type: AccountType.asset,
      subtype: AccountSubtype.fund,
      balance: const Money(minorUnits: 0),
    ),
    Account(
      id: 'food',
      name: '餐饮',
      type: AccountType.expense,
      balance: const Money(minorUnits: 0),
    ),
    Account(
      id: 'receivable',
      name: '应收',
      type: AccountType.asset,
      subtype: AccountSubtype.receivable,
      balance: const Money(minorUnits: 0),
    ),
  ]) {
    await accounts.create(account);
  }
  return container;
}

Future<void> _flush(ProviderContainer container) async {
  await pumpEventQueue(times: 100);
  await container.pump();
}

BusinessActivityQueryService _pageService(
  ProviderContainer container, {
  required Future<void> Function() afterRead,
}) {
  final database = container.read(appDatabaseProvider);
  return BusinessActivityQueryServiceImpl(
    sources: [
      _CandidateReadHook(
        DriftLedgerBusinessActivitySource(database),
        afterRead,
      ),
    ],
    transactionQuery: container.read(transactionQueryServiceProvider),
    transactionRunner: container.read(transactionRunnerProvider),
    changes: DriftBusinessActivityChangeSource(database),
  );
}

final class _CandidateReadHook implements BusinessActivitySource {
  const _CandidateReadHook(this.source, this.afterRead, {this.beforeSummary});

  final BusinessActivitySource source;
  final Future<void> Function() afterRead;
  final Future<void> Function()? beforeSummary;

  @override
  String get sourceKey => source.sourceKey;

  @override
  Set<String> get supportedActivityTypes => source.supportedActivityTypes;

  @override
  Future<BusinessActivitySourcePage> findCandidatePage(
    BusinessActivityPageQuery query,
  ) async {
    final page = await source.findCandidatePage(query);
    await afterRead();
    return page;
  }

  @override
  Future<Map<BusinessActivityKey, BusinessActivitySummary>> findSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) async {
    await beforeSummary?.call();
    return source.findSummaries(candidates);
  }

  @override
  Stream<Map<BusinessActivityKey, BusinessActivitySummary>> watchSummaries(
    Iterable<BusinessActivityCandidate> candidates,
  ) => source.watchSummaries(candidates);
}

final class _FailingTransactionQuery implements TransactionBatchQueryService {
  @override
  Future<List<TransactionReadModel>> findTransactionsByIds(
    Set<String> ids,
  ) async {
    throw StateError('fixture transaction read failure');
  }

  @override
  Stream<List<TransactionReadModel>> watchTransactionsByIds(Set<String> ids) =>
      Stream.fromFuture(findTransactionsByIds(ids));
}
