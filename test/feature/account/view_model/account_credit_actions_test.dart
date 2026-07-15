import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/feature/account/view_model/account_credit_actions.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  test('generates a user-selected historical bill period', () async {
    final bills = _FakeBillGenerationService();
    final container = ProviderContainer(
      overrides: [
        creditBillGenerationAppServiceProvider.overrideWithValue(bills),
      ],
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(accountCreditActionsProvider('account-1').notifier)
        .generateHistoricalBill(DateTime(2025, 11, 20));

    expect(outcome, isA<UiActionSuccess<void>>());
    expect(bills.accountId, 'account-1');
    expect(bills.period, BillPeriod(year: 2025, month: 11));
  });

  test('deletes an unattributed repayment by repayment id', () async {
    final repayments = _FakeRepaymentAppService();
    final container = ProviderContainer(
      overrides: [repaymentAppServiceProvider.overrideWithValue(repayments)],
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(accountCreditActionsProvider('account-1').notifier)
        .deleteUnattributedRepayment('repayment-1');

    expect(outcome, isA<UiActionSuccess<void>>());
    expect(repayments.deletedRepaymentId, 'repayment-1');
  });
}

class _FakeBillGenerationService implements CreditBillGenerationAppService {
  String? accountId;
  BillPeriod? period;

  @override
  Future<void> generateBillForPeriod({
    required String accountId,
    required BillPeriod period,
    required DateTime now,
  }) async {
    this.accountId = accountId;
    this.period = period;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepaymentAppService implements RepaymentAppService {
  String? deletedRepaymentId;

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    deletedRepaymentId = command.repaymentId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
