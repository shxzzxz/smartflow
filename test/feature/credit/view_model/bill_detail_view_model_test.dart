import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/view_model/bill_detail_view_model.dart';

import '../../../helper/fake_credit_bill_generation_app_service.dart';

void main() {
  test(
    'shows stored historical data before refreshing and updates it once',
    () async {
      final query = _BillQuery();
      final started = Completer<void>();
      final finish = Completer<void>();
      final generation = FakeCreditBillGenerationAppService(
        onRefreshBill: (_) async {
          started.complete();
          await finish.future;
        },
      );
      final container = _container(query, generation);
      final subscription = container.listen(
        billDetailViewModelProvider('bill'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final stored = await container
          .read(billDetailViewModelProvider('bill').future)
          .timeout(const Duration(seconds: 2));
      expect(stored!.summary.expectedPrincipal.minorUnits, 1000);
      await started.future;
      expect(
        container
            .read(billDetailViewModelProvider('bill'))
            .requireValue!
            .summary
            .expectedPrincipal
            .minorUnits,
        1000,
      );
      query.detail = _detail(2000);
      finish.complete();
      await _flush(container);
      expect(
        container
            .read(billDetailViewModelProvider('bill'))
            .requireValue!
            .summary
            .expectedPrincipal
            .minorUnits,
        2000,
      );
      expect(generation.refreshedBills, ['bill']);
      expect(query.reads, 2);
      await _flush(container);
      expect(generation.refreshedBills, ['bill']);
    },
  );

  test('background failure keeps stored data visible', () async {
    final query = _BillQuery();
    final generation = FakeCreditBillGenerationAppService(
      onRefreshBill: (_) async => throw Exception('refresh failed'),
    );
    final container = _container(query, generation);
    final subscription = container.listen(
      billDetailViewModelProvider('bill'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(billDetailViewModelProvider('bill').future);
    await _flush(container);
    expect(
      container
          .read(billDetailViewModelProvider('bill'))
          .requireValue!
          .summary
          .expectedPrincipal
          .minorUnits,
      1000,
    );
    expect(query.reads, 1);
    expect(generation.refreshedBills, ['bill']);
  });

  test(
    'leaving the page during refresh does not update a disposed provider',
    () async {
      final query = _BillQuery();
      final started = Completer<void>();
      final finish = Completer<void>();
      final generation = FakeCreditBillGenerationAppService(
        onRefreshBill: (_) async {
          started.complete();
          await finish.future;
        },
      );
      final container = _container(query, generation);
      final subscription = container.listen(
        billDetailViewModelProvider('bill'),
        (_, _) {},
      );
      await container.read(billDetailViewModelProvider('bill').future);
      await started.future;
      subscription.close();
      await _flush(container);
      finish.complete();
      await _flush(container);
      expect(query.reads, 1);
    },
  );
}

ProviderContainer _container(
  _BillQuery query,
  FakeCreditBillGenerationAppService generation,
) {
  final container = ProviderContainer(
    overrides: [
      billQueryServiceProvider.overrideWithValue(query),
      creditBillGenerationAppServiceProvider.overrideWithValue(generation),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _flush(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

class _BillQuery implements BillQueryService {
  var detail = _detail(1000);
  var reads = 0;

  @override
  Future<BillDetailReadModel?> findBillDetail(String billId) async {
    reads++;
    return detail;
  }

  @override
  Future<List<BillSummaryReadModel>> listBillsByAccount(
    String accountId,
  ) async => [detail.summary];

  @override
  Future<List<BillSummaryReadModel>> listAccountBillPreview(
    String accountId,
  ) async => [detail.summary];

  @override
  Future<bool> hasUnsettledObligations(String accountId) async => true;
}

BillDetailReadModel _detail(int amount) => BillDetailReadModel(
  summary: BillSummaryReadModel(
    id: 'bill',
    accountId: 'card',
    period: BillPeriod.fromInt(202506),
    status: BillStatus.billed,
    expectedPrincipal: Money(minorUnits: amount),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: Money(minorUnits: amount),
    itemCount: 1,
    overdueItemCount: 1,
  ),
  items: [
    BillItemReadModel(
      id: 'item',
      itemType: BillItemType.consumption,
      status: BillItemStatus.pending,
      repaymentDate: DateTime(2025, 6, 25),
      startInclusive: DateTime(2025, 5, 5),
      endInclusive: DateTime(2025, 6, 4),
      expectedPrincipal: Money(minorUnits: amount),
      expectedInterest: Money.zero(),
      expectedFee: Money.zero(),
      allocated: RepaymentAmountDto.zero,
      isOverdue: true,
    ),
  ],
  repayments: const [],
);
