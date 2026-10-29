import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/service/installment/consumption_installment_refund_policy.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';

void main() {
  const policy = ConsumptionInstallmentRefundPolicy();

  test(
    'includes unpaid principal only when the due date is after refund date',
    () {
      final amount = policy.refundablePrincipal(
        refundDate: DateTime(2026, 7, 10, 18),
        rows: [
          _row(
            id: 'same-day',
            periodNo: 1,
            date: DateTime(2026, 7, 10),
            principal: const Money(minorUnits: 60000),
          ),
          _row(
            id: 'future',
            periodNo: 2,
            date: DateTime(2026, 8, 10),
            principal: const Money(minorUnits: 60000),
          ),
        ],
        paidPrincipalByScheduleId: {'future': const Money(minorUnits: 20000)},
      );

      expect(amount, const Money(minorUnits: 40000));
    },
  );

  test('excludes skipped schedules and ignores time of day', () {
    final amount = policy.refundablePrincipal(
      refundDate: DateTime(2026, 7, 10, 23, 59),
      rows: [
        _row(
          id: 'skipped',
          periodNo: 1,
          date: DateTime(2026, 8, 10),
          principal: const Money(minorUnits: 60000),
          status: InstallmentScheduleStatus.skipped,
        ),
        _row(
          id: 'future',
          periodNo: 2,
          date: DateTime(2026, 7, 11),
          principal: const Money(minorUnits: 40000),
        ),
      ],
      paidPrincipalByScheduleId: const {},
    );

    expect(amount, const Money(minorUnits: 40000));
  });
}

InstallmentPlanRow _row({
  required String id,
  required int periodNo,
  required DateTime date,
  required Money principal,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentPlanRow(
    id: id,
    stageId: 'stage',
    periodNo: periodNo,
    date: date,
    principal: principal,
    interest: Money.zero(),
    fee: Money.zero(),
    status: status,
  );
}
