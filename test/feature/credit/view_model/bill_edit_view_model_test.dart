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
      expect(service.updatedWindows, hasLength(1));
      expect(service.updatedWindows.single.billId, 'bill-1');
      expect(service.updatedWindows.single.startDate, DateTime(2026, 6, 5));
      expect(service.updatedWindows.single.billingDate, DateTime(2026, 7, 5));
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
    expect(service.updatedWindows, isEmpty);
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
    items: const [],
    repayments: const [],
  );
}

class _RecordingGenerationService implements CreditBillGenerationAppService {
  final updatedWindows =
      <({String billId, DateTime startDate, DateTime billingDate})>[];

  @override
  Future<void> updateBillWindow({
    required String billId,
    required DateTime startDate,
    required DateTime billingDate,
  }) async {
    updatedWindows.add((
      billId: billId,
      startDate: startDate,
      billingDate: billingDate,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
