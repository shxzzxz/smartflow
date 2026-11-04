import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';

void main() {
  test('switches content when the member page changes', () async {
    final pages = StreamController<BusinessActivityPage>.broadcast();
    final contents =
        StreamController<
          Map<BusinessActivityKey, BusinessActivityReadModel>
        >.broadcast();
    final query = _ContentQueryService(contents.stream);
    final events = <BusinessActivityPage>[];
    final subscription = watchBusinessActivityContents(
      pages.stream,
      query,
    ).listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(pages.close);
    addTearDown(contents.close);

    final first = _activity('first', 1);
    pages.add(BusinessActivityPage(items: [first], hasMore: false));
    await pumpEventQueue();

    contents.add({first.activityKey: _activity('first', 2)});
    await pumpEventQueue();
    expect(events.last.items.single.displayTransaction!.id, 'first');
    expect(
      events.last.items.single.displayTransaction!.primaryAmount.minorUnits,
      2,
    );

    final second = _activity('second', 3);
    pages.add(BusinessActivityPage(items: [second], hasMore: false));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(query.watchCalls, 2);
    expect(events.last.items.single.displayTransaction!.id, 'second');
  });

  test('refreshes a member that has no display transaction', () async {
    final pages = StreamController<BusinessActivityPage>.broadcast();
    final contents =
        StreamController<
          Map<BusinessActivityKey, BusinessActivityReadModel>
        >.broadcast();
    final query = _ContentQueryService(contents.stream);
    final events = <BusinessActivityPage>[];
    final subscription = watchBusinessActivityContents(
      pages.stream,
      query,
    ).listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(pages.close);
    addTearDown(contents.close);

    final first = _activity('first', 1, includeDisplayTransaction: false);
    pages.add(BusinessActivityPage(items: [first], hasMore: true));
    await pumpEventQueue();
    expect(events.last.items.single.displayTransaction, isNull);
    expect(events.last.hasMore, isTrue);
    expect(events.last.nextCursor?.activityAt, first.activityAt);
    expect(events.last.nextCursor?.activityKey, first.activityKey);

    final refreshedAt = DateTime(2026, 1, 2);
    contents.add({
      first.activityKey: _activity(
        'first',
        2,
        includeDisplayTransaction: false,
        activityAt: refreshedAt,
      ),
    });
    await pumpEventQueue();

    expect(events.last.items.single.activityAt, refreshedAt);
    expect(events.last.items.single.displayTransaction, isNull);
    expect(events.last.hasMore, isTrue);
  });
}

final class _ContentQueryService implements BusinessActivityQueryService {
  _ContentQueryService(this.contentChanges);

  final Stream<Map<BusinessActivityKey, BusinessActivityReadModel>>
  contentChanges;
  var watchCalls = 0;

  @override
  Stream<Map<BusinessActivityKey, BusinessActivityReadModel>> watchContents(
    Iterable<BusinessActivityReadModel> currentActivities,
  ) {
    watchCalls += 1;
    final current = {
      for (final activity in currentActivities) activity.activityKey: activity,
    };
    return Stream.multi((controller) {
      controller.add(current);
      final subscription = contentChanges.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BusinessActivityReadModel _activity(
  String id,
  int amountMinor, {
  bool includeDisplayTransaction = true,
  DateTime? activityAt,
}) {
  final transaction = TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: DateTime(2026, 1, 1),
    primaryAmount: Money(minorUnits: amountMinor),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
  return BusinessActivityReadModel.fromCandidate(
    candidate: BusinessActivityCandidate(
      activityKey: BusinessActivityKey.transactionGroup(id),
      displayTransactionId: includeDisplayTransaction ? id : null,
      activityAt: activityAt ?? transaction.occurredAt,
    ),
    displayTransaction: includeDisplayTransaction ? transaction : null,
    summary: const LedgerBusinessActivitySummary(),
  );
}
