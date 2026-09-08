import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/feature/credit/view_model/bill_edit_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  test(
    'submit sends the edited window to the bill generation service',
    () async {
      final service = _RecordingGenerationService();
      final container = ProviderContainer(
        overrides: [
          billDetailProvider('bill-1').overrideWith((ref) async => _detail()),
          creditBillGenerationAppServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        billEditViewModelProvider('bill-1').notifier,
      );
      await container.read(billEditViewModelProvider('bill-1').future);

      final outcome = await notifier.submit();

      expect(outcome, isA<SubmitSuccess>());
      expect(service.updatedConsumptionWindows, hasLength(1));
      expect(service.updatedConsumptionWindows.single.billId, 'bill-1');
      expect(service.updatedConsumptionWindows.single.billItemId, 'item-1');
      expect(
        service.updatedConsumptionWindows.single.startInclusive,
        DateTime(2026, 6, 5),
      );
      expect(
        service.updatedConsumptionWindows.single.endInclusive,
        DateTime(2026, 7, 5),
      );
    },
  );

  test('submit rejects a start date not before the billing date', () async {
    final service = _RecordingGenerationService();
    final container = ProviderContainer(
      overrides: [
        billDetailProvider('bill-1').overrideWith((ref) async => _detail()),
        creditBillGenerationAppServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      billEditViewModelProvider('bill-1').notifier,
    );
    await container.read(billEditViewModelProvider('bill-1').future);
    notifier.setStartDate(DateTime(2026, 7, 10));

    final outcome = await notifier.submit();

    expect(outcome, isA<SubmitFailure>());
    expect(
      (outcome as SubmitFailure).error.code,
      CreditErrorCode.billWindowInvalid.code,
    );
    expect(service.updatedConsumptionWindows, isEmpty);
  });
}

BillDetailReadModel _detail() {
  return BillDetailReadModel(
    summary: BillSummaryReadModel(
      id: 'bill-1',
      accountId: 'account',
      period: BillPeriod(year: 2026, month: 7),
      status: BillStatus.open,
      expectedPrincipal: Money.zero(),
      expectedInterest: Money.zero(),
      expectedFee: Money.zero(),
      pendingPrincipal: Money.zero(),
      itemCount: 0,
      overdueItemCount: 0,
      windowStartDate: DateTime(2026, 6, 5),
      windowBillingDate: DateTime(2026, 7, 5),
      windowRepaymentDate: DateTime(2026, 7, 25),
    ),
    items: [
      BillItemReadModel(
        id: 'item-1',
        itemType: BillItemType.consumption,
        status: BillItemStatus.pending,
        billingState: BillItemBillingState.open,
        repaymentDate: DateTime(2026, 7, 25),
        startInclusive: DateTime(2026, 6, 5),
        endInclusive: DateTime(2026, 7, 5),
        expectedPrincipal: const Money(minorUnits: 1000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: RepaymentAmountDto.zero,
        isOverdue: false,
      ),
    ],
    repayments: const [],
  );
}

class _RecordingGenerationService implements CreditBillGenerationAppService {
  final updatedConsumptionWindows =
      <
        ({
          String billId,
          String billItemId,
          DateTime startInclusive,
          DateTime endInclusive,
        })
      >[];

  @override
  Future<void> updateConsumptionWindow({
    required String billId,
    required String billItemId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {
    updatedConsumptionWindows.add((
      billId: billId,
      billItemId: billItemId,
      startInclusive: startInclusive,
      endInclusive: endInclusive,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
