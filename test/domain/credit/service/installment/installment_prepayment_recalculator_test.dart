import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  test(
    'paid pending skipped pending schedules follow both date and principal timelines',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(
          id: 'paid-1',
          periodNo: 1,
          date: DateTime(2026, 2, 1),
          principal: 2000,
          status: InstallmentScheduleStatus.paid,
        ),
        _schedule(
          id: 'pending-2',
          periodNo: 2,
          date: DateTime(2026, 3, 1),
          principal: 0,
        ),
        _schedule(
          id: 'skipped-3',
          periodNo: 3,
          date: DateTime(2026, 4, 1),
          principal: 3000,
          status: InstallmentScheduleStatus.skipped,
        ),
        _schedule(
          id: 'pending-4',
          periodNo: 4,
          date: DateTime(2026, 5, 1),
          principal: 5000,
        ),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _dailyInterestContract(totalPeriods: 4),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.scheduleId), ['pending-2', 'pending-4']);
      expect(result.map((item) => item.expectedInterest.minorUnits), [
        224,
        150,
      ]);
      expect(result.map((item) => item.expectedPrincipal.minorUnits), [
        0,
        5000,
      ]);
      expect(
        result.fold<int>(
          0,
          (sum, item) => sum + item.expectedPrincipal.minorUnits,
        ),
        5000,
      );
      expect(result.map((item) => item.expectedRepaymentDate), [
        DateTime(2026, 3, 1),
        DateTime(2026, 5, 1),
      ]);
    },
  );

  test(
    'pending skipped pending schedules use the timeline balance for each accrual interval',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(
          id: 'pending-1',
          periodNo: 1,
          date: DateTime(2026, 2, 1),
          principal: 0,
        ),
        _schedule(
          id: 'skipped-2',
          periodNo: 2,
          date: DateTime(2026, 3, 1),
          principal: 4000,
          status: InstallmentScheduleStatus.skipped,
        ),
        _schedule(
          id: 'pending-3',
          periodNo: 3,
          date: DateTime(2026, 4, 1),
          principal: 6000,
        ),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _dailyInterestContract(totalPeriods: 3),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.expectedInterest.minorUnits), [
        310,
        186,
      ]);
      expect(result.map((item) => item.expectedPrincipal.minorUnits), [
        0,
        6000,
      ]);
      expect(
        result.fold<int>(
          0,
          (sum, item) => sum + item.expectedPrincipal.minorUnits,
        ),
        6000,
      );
      expect(result.map((item) => item.expectedRepaymentDate), [
        DateTime(2026, 2, 1),
        DateTime(2026, 4, 1),
      ]);
    },
  );

  test('later paid principal does not reduce earlier pending interest', () {
    const recalculator = InstallmentPrepaymentRecalculator();
    final schedules = [
      _schedule(
        id: 'pending-1',
        periodNo: 1,
        date: DateTime(2026, 2, 1),
        principal: 0,
      ),
      _schedule(
        id: 'paid-2',
        periodNo: 2,
        date: DateTime(2026, 3, 1),
        principal: 2500,
        status: InstallmentScheduleStatus.paid,
      ),
      _schedule(
        id: 'pending-3',
        periodNo: 3,
        date: DateTime(2026, 4, 1),
        principal: 7500,
      ),
    ];

    final result = recalculator.recalculateAllPending(
      contract: _dailyInterestContract(totalPeriods: 3),
      schedules: schedules,
      prepaymentPrincipalMinor: 0,
    );

    expect(result.map((item) => item.expectedInterest.minorUnits), [310, 233]);
    expect(result.map((item) => item.expectedPrincipal.minorUnits), [0, 7500]);
  });

  test(
    'later partially paid principal does not reduce earlier pending interest',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(
          id: 'pending-1',
          periodNo: 1,
          date: DateTime(2026, 2, 1),
          principal: 0,
        ),
        _schedule(
          id: 'partially-paid-2',
          periodNo: 2,
          date: DateTime(2026, 3, 1),
          principal: 3500,
          status: InstallmentScheduleStatus.partiallyPaid,
        ),
        _schedule(
          id: 'pending-3',
          periodNo: 3,
          date: DateTime(2026, 4, 1),
          principal: 6500,
        ),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _dailyInterestContract(totalPeriods: 3),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.expectedInterest.minorUnits), [
        310,
        202,
      ]);
      expect(result.map((item) => item.expectedPrincipal.minorUnits), [
        0,
        6500,
      ]);
    },
  );

  test(
    'consecutive pending schedules accrue from the previous pending date',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(
          id: 'pending-1',
          periodNo: 1,
          date: DateTime(2026, 2, 1),
          principal: 0,
        ),
        _schedule(
          id: 'pending-2',
          periodNo: 2,
          date: DateTime(2026, 3, 1),
          principal: 0,
        ),
        _schedule(
          id: 'pending-3',
          periodNo: 3,
          date: DateTime(2026, 4, 1),
          principal: 10000,
        ),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _dailyInterestContract(totalPeriods: 3),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.expectedInterest.minorUnits), [
        310,
        280,
        310,
      ]);
    },
  );

  test(
    'equal principal schedules reduce the timeline balance after each pending principal',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(id: 'pending-1', periodNo: 1, principal: 0),
        _schedule(id: 'pending-2', periodNo: 2, principal: 0),
        _schedule(id: 'pending-3', periodNo: 3, principal: 10000),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _dailyInterestContract(
          totalPeriods: 3,
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
        ),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.expectedInterest.minorUnits), [
        310,
        187,
        103,
      ]);
      expect(result.map((item) => item.expectedPrincipal.minorUnits), [
        3333,
        3333,
        3334,
      ]);
      expect(result.map((item) => item.expectedRepaymentDate), [
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 1),
      ]);
    },
  );

  test(
    'equal installment payment solving includes fixed principal still outstanding in each interval',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(
          id: 'pending-1',
          periodNo: 1,
          date: DateTime(2026, 2, 1),
          principal: 0,
        ),
        _schedule(
          id: 'skipped-2',
          periodNo: 2,
          date: DateTime(2026, 3, 1),
          principal: 4000,
          status: InstallmentScheduleStatus.skipped,
        ),
        _schedule(
          id: 'pending-3',
          periodNo: 3,
          date: DateTime(2026, 4, 1),
          principal: 6000,
        ),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _dailyInterestContract(
          totalPeriods: 3,
          repaymentMethod: InstallmentRepaymentMethod.equalInstallment,
        ),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.expectedInterest.minorUnits), [310, 96]);
      expect(result.map((item) => item.expectedPrincipal.minorUnits), [
        2893,
        3107,
      ]);
      expect(
        result.map(
          (item) =>
              item.expectedPrincipal.minorUnits +
              item.expectedInterest.minorUnits,
        ),
        [3203, 3203],
      );
      expect(
        result.fold<int>(
          0,
          (sum, item) => sum + item.expectedPrincipal.minorUnits,
        ),
        6000,
      );
    },
  );

  test('pending schedule accrues from the previous non-pending date', () {
    const recalculator = InstallmentPrepaymentRecalculator();
    final schedules = [
      _schedule(
        id: 'partially-paid-1',
        periodNo: 1,
        date: DateTime(2026, 2, 10),
        principal: 2500,
        status: InstallmentScheduleStatus.partiallyPaid,
      ),
      _schedule(
        id: 'pending-2',
        periodNo: 2,
        date: DateTime(2026, 3, 1),
        principal: 7500,
      ),
    ];

    final result = recalculator.recalculateAllPending(
      contract: _dailyInterestContract(totalPeriods: 2),
      schedules: schedules,
      prepaymentPrincipalMinor: 0,
    );

    expect(result.single.expectedInterest.minorUnits, 143);
    expect(result.single.expectedPrincipal.minorUnits, 7500);
  });

  test('first pending schedule accrues from the contract borrowing date', () {
    const recalculator = InstallmentPrepaymentRecalculator();
    final schedules = [
      _schedule(
        id: 'pending-1',
        periodNo: 1,
        date: DateTime(2026, 2, 1),
        principal: 10000,
      ),
    ];

    final result = recalculator.recalculateAllPending(
      contract: _dailyInterestContract(totalPeriods: 1),
      schedules: schedules,
      prepaymentPrincipalMinor: 0,
    );

    expect(result.single.expectedInterest.minorUnits, 310);
  });

  test('prepayment principal reduces allocation and every pending balance', () {
    const recalculator = InstallmentPrepaymentRecalculator();
    final schedules = [
      _schedule(id: 'pending-1', periodNo: 1, principal: 0),
      _schedule(id: 'pending-2', periodNo: 2, principal: 10000),
    ];

    final result = recalculator.recalculateAllPending(
      contract: _dailyInterestContract(totalPeriods: 2),
      schedules: schedules,
      prepaymentPrincipalMinor: 2000,
    );

    expect(result.map((item) => item.expectedInterest.minorUnits), [248, 224]);
    expect(result.map((item) => item.expectedPrincipal.minorUnits), [0, 8000]);
    expect(
      result.fold<int>(
        0,
        (sum, item) => sum + item.expectedPrincipal.minorUnits,
      ),
      8000,
    );
  });

  test('schedule dates must be strictly increasing by period number', () {
    const recalculator = InstallmentPrepaymentRecalculator();

    for (final invalidDate in [DateTime(2026, 2, 1), DateTime(2026, 1, 31)]) {
      final schedules = [
        _schedule(
          id: 'pending-1',
          periodNo: 1,
          date: DateTime(2026, 2, 1),
          principal: 5000,
        ),
        _schedule(
          id: 'pending-2',
          periodNo: 2,
          date: invalidDate,
          principal: 5000,
        ),
      ];

      expect(
        () => recalculator.recalculateAllPending(
          contract: _dailyInterestContract(totalPeriods: 2),
          schedules: schedules,
          prepaymentPrincipalMinor: 0,
        ),
        throwsA(
          isA<BusinessException>()
              .having(
                (error) => error.code,
                'code',
                'credit.contract.invalid_command',
              )
              .having(
                (error) => error.message,
                'message',
                contains('strictly increasing'),
              ),
        ),
      );
    }
  });

  test(
    'prepayment recalculates every pending schedule after all non-pending principal is fixed',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(
          id: 'partially-paid',
          periodNo: 1,
          principal: 2000,
          status: InstallmentScheduleStatus.partiallyPaid,
        ),
        _schedule(
          id: 'paid',
          periodNo: 2,
          principal: 1000,
          status: InstallmentScheduleStatus.paid,
        ),
        _schedule(
          id: 'skipped',
          periodNo: 3,
          principal: 1000,
          status: InstallmentScheduleStatus.skipped,
        ),
        _schedule(id: 'pending-4', periodNo: 4, principal: 3000),
        _schedule(id: 'pending-5', periodNo: 5, principal: 3000),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _contract(),
        schedules: schedules,
        prepaymentPrincipalMinor: 1000,
      );

      expect(result.map((item) => item.scheduleId), ['pending-4', 'pending-5']);
      expect(
        result.fold<int>(
          0,
          (sum, item) => sum + item.expectedPrincipal.minorUnits,
        ),
        5000,
      );
      expect(result.map((item) => item.expectedRepaymentDate), [
        schedules[3].expectedRepaymentDate,
        schedules[4].expectedRepaymentDate,
      ]);
    },
  );

  test(
    'deleting a prepayment recalculates every pending schedule from remaining effective prepayments',
    () {
      const recalculator = InstallmentPrepaymentRecalculator();
      final schedules = [
        _schedule(
          id: 'paid',
          periodNo: 1,
          principal: 2000,
          status: InstallmentScheduleStatus.paid,
        ),
        _schedule(id: 'pending-2', periodNo: 2, principal: 2000),
        _schedule(id: 'pending-3', periodNo: 3, principal: 2000),
        _schedule(id: 'pending-4', periodNo: 4, principal: 2000),
        _schedule(id: 'pending-5', periodNo: 5, principal: 2000),
      ];

      final result = recalculator.recalculateAllPending(
        contract: _contract(),
        schedules: schedules,
        prepaymentPrincipalMinor: 1000,
      );

      expect(result.map((item) => item.scheduleId), [
        'pending-2',
        'pending-3',
        'pending-4',
        'pending-5',
      ]);
      expect(
        result.fold<int>(
          0,
          (sum, item) => sum + item.expectedPrincipal.minorUnits,
        ),
        7000,
      );
    },
  );
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'liability',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 10000),
    totalPeriods: 5,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 6, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentContract _dailyInterestContract({
  required int totalPeriods,
  InstallmentRepaymentMethod repaymentMethod =
      InstallmentRepaymentMethod.interestFirst,
}) {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'liability',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 10000),
    totalPeriods: totalPeriods,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, totalPeriods + 1, 1),
    repaymentMethod: repaymentMethod,
    interestAccrualMethod: InterestAccrualMethod.daily,
    interestRatePeriod: InterestRatePeriod.monthly,
    interestRatePpm: 30000,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentSchedule _schedule({
  required String id,
  required int periodNo,
  required int principal,
  DateTime? date,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: 'contract',
    periodNo: periodNo,
    expectedRepaymentDate: date ?? DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: Money(minorUnits: principal),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}
