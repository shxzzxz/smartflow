import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  const recalculator = InstallmentPrepaymentRecalculator();

  group('anchor', () {
    test('freezes every schedule up to the last non-pending period and only '
        'recalculates the tail', () {
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

      final result = recalculator.recalculate(
        contract: _dailyInterestContract(totalPeriods: 4),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      // 锚点 = 第 3 期（最后一个非待还），第 2 期虽待还但日期在锚点前，保持旧值。
      expect(result.map((item) => item.scheduleId), ['pending-4']);
      expect(result.single.expectedPrincipal.minorUnits, 5000);
      // 剩余本金 10000 − 2000 − 0 − 3000 = 5000，从第 3 期日期起计 30 天。
      expect(result.single.expectedInterest.minorUnits, 150);
      expect(result.single.expectedRepaymentDate, DateTime(2026, 5, 1));
    });

    test('accrues the tail from the last frozen schedule date', () {
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

      final result = recalculator.recalculate(
        contract: _dailyInterestContract(totalPeriods: 3),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.scheduleId), ['pending-3']);
      // 6000 × 3% × 31 / 30
      expect(result.single.expectedInterest.minorUnits, 186);
      expect(result.single.expectedPrincipal.minorUnits, 6000);
    });

    test('uses the borrowing date when nothing is frozen', () {
      final schedules = [
        _schedule(id: 'pending-1', periodNo: 1, principal: 0),
        _schedule(id: 'pending-2', periodNo: 2, principal: 0),
        _schedule(id: 'pending-3', periodNo: 3, principal: 10000),
      ];

      final result = recalculator.recalculate(
        contract: _dailyInterestContract(totalPeriods: 3),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result.map((item) => item.expectedInterest.minorUnits), [
        310,
        280,
        310,
      ]);
    });

    test('pending schedule accrues from the previous non-pending date', () {
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

      final result = recalculator.recalculate(
        contract: _dailyInterestContract(totalPeriods: 2),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      // 7500 × 3% × 19 / 30 = 142.5 → 143
      expect(result.single.expectedInterest.minorUnits, 143);
      expect(result.single.expectedPrincipal.minorUnits, 7500);
    });

    test('event date later than the last paid period freezes pending rows '
        'before it', () {
      final schedules = [
        _schedule(id: 'pending-1', periodNo: 1, principal: 0),
        _schedule(id: 'pending-2', periodNo: 2, principal: 10000),
      ];

      final result = recalculator.recalculate(
        contract: _dailyInterestContract(totalPeriods: 2),
        schedules: schedules,
        prepaymentPrincipalMinor: 2000,
        eventDate: DateTime(2026, 2, 15, 14, 30),
      );

      expect(result.map((item) => item.scheduleId), ['pending-2']);
      // 计息起点为第 1 期日期 2026-02-01，28 天：8000 × 3% × 28 / 30
      expect(result.single.expectedInterest.minorUnits, 224);
      expect(result.single.expectedPrincipal.minorUnits, 8000);
    });

    test('event date on a schedule date freezes that schedule', () {
      final schedules = [
        _schedule(id: 'pending-1', periodNo: 1, principal: 5000),
        _schedule(id: 'pending-2', periodNo: 2, principal: 5000),
      ];

      final result = recalculator.recalculate(
        contract: _dailyInterestContract(
          totalPeriods: 2,
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
        ),
        schedules: schedules,
        prepaymentPrincipalMinor: 1000,
        eventDate: DateTime(2026, 2, 1, 9),
      );

      expect(result.map((item) => item.scheduleId), ['pending-2']);
      expect(result.single.expectedPrincipal.minorUnits, 4000);
    });
  });

  group('principal', () {
    test(
      'equal principal splits the tail evenly with the tail difference last',
      () {
        final schedules = [
          _schedule(id: 'pending-1', periodNo: 1, principal: 0),
          _schedule(id: 'pending-2', periodNo: 2, principal: 0),
          _schedule(id: 'pending-3', periodNo: 3, principal: 10000),
        ];

        final result = recalculator.recalculate(
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
      },
    );

    test('prepayment principal reduces the tail allocation', () {
      final schedules = [
        _schedule(id: 'pending-1', periodNo: 1, principal: 0),
        _schedule(id: 'pending-2', periodNo: 2, principal: 10000),
      ];

      final result = recalculator.recalculate(
        contract: _dailyInterestContract(totalPeriods: 2),
        schedules: schedules,
        prepaymentPrincipalMinor: 2000,
      );

      expect(result.map((item) => item.expectedInterest.minorUnits), [
        248,
        224,
      ]);
      expect(result.map((item) => item.expectedPrincipal.minorUnits), [
        0,
        8000,
      ]);
    });

    test('prepayment recalculates every pending schedule after all non-pending '
        'principal is fixed', () {
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

      final result = recalculator.recalculate(
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
    });

    test('deleting a prepayment recalculates the tail from the remaining '
        'effective prepayments', () {
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

      final result = recalculator.recalculate(
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
    });

    test('a fully prepaid tail is recalculated to zero principal', () {
      final schedules = [
        _schedule(id: 'pending-1', periodNo: 1, principal: 5000),
        _schedule(id: 'pending-2', periodNo: 2, principal: 5000),
      ];

      final result = recalculator.recalculate(
        contract: _contract(),
        schedules: schedules,
        prepaymentPrincipalMinor: 10000,
      );

      expect(result.map((item) => item.expectedPrincipal.minorUnits), [0, 0]);
      expect(result.map((item) => item.expectedInterest.minorUnits), [0, 0]);
    });
  });

  group('failures', () {
    test('rejects a negative remaining principal', () {
      final schedules = [
        _schedule(
          id: 'paid',
          periodNo: 1,
          principal: 6000,
          status: InstallmentScheduleStatus.paid,
        ),
        _schedule(id: 'pending-2', periodNo: 2, principal: 4000),
      ];

      expect(
        () => recalculator.recalculate(
          contract: _contract(),
          schedules: schedules,
          prepaymentPrincipalMinor: 5000,
        ),
        throwsA(_invalidCommand(contains('negative'))),
      );
    });

    test(
      'fails when principal remains but no pending schedule follows the anchor',
      () {
        final schedules = [
          _schedule(
            id: 'paid',
            periodNo: 1,
            principal: 2000,
            status: InstallmentScheduleStatus.paid,
          ),
          _schedule(
            id: 'skipped',
            periodNo: 2,
            principal: 3000,
            status: InstallmentScheduleStatus.skipped,
          ),
        ];

        expect(
          () => recalculator.recalculate(
            contract: _contract(),
            schedules: schedules,
            prepaymentPrincipalMinor: 0,
          ),
          throwsA(_invalidCommand(contains('restore skipped'))),
        );
      },
    );

    test('returns nothing when the tail is empty and principal is settled', () {
      final schedules = [
        _schedule(
          id: 'paid',
          periodNo: 1,
          principal: 7000,
          status: InstallmentScheduleStatus.paid,
        ),
        _schedule(
          id: 'skipped',
          periodNo: 2,
          principal: 3000,
          status: InstallmentScheduleStatus.skipped,
        ),
      ];

      final result = recalculator.recalculate(
        contract: _contract(),
        schedules: schedules,
        prepaymentPrincipalMinor: 0,
      );

      expect(result, isEmpty);
    });

    test('schedule dates must be strictly increasing by period number', () {
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
          () => recalculator.recalculate(
            contract: _dailyInterestContract(totalPeriods: 2),
            schedules: schedules,
            prepaymentPrincipalMinor: 0,
          ),
          throwsA(_invalidCommand(contains('strictly increasing'))),
        );
      }
    });
  });

  group('regenerated dates', () {
    test(
      'regenerates tail dates from the terms and freezes completed dates',
      () {
        final contract = InstallmentContract(
          id: 'contract',
          liabilityAccountId: 'liability',
          sourceType: InstallmentSourceType.disbursement,
          principal: const Money(minorUnits: 10000),
          borrowingDate: DateTime(2026, 1, 1),
          status: InstallmentContractStatus.active,
          createdAt: DateTime(2026, 1, 1),
          stageTerms: InstallmentContractTerms.singleStage(
            id: 'contract:stage:1',
            totalPeriods: 4,
            firstDate: DateTime(2026, 3, 1),
            lastDate: DateTime(2026, 6, 1),
            method: InstallmentRepaymentMethod.equalPrincipal,
            accrual: InterestAccrualMethod.monthly,
            feeMinor: 0,
          ),
        );
        final schedules = [
          _schedule(
            id: 'paid-1',
            periodNo: 1,
            date: DateTime(2026, 2, 1),
            principal: 2500,
            status: InstallmentScheduleStatus.paid,
          ),
          _schedule(
            id: 'pending-2',
            periodNo: 2,
            date: DateTime(2026, 3, 1),
            principal: 2500,
          ),
          _schedule(
            id: 'pending-3',
            periodNo: 3,
            date: DateTime(2026, 4, 1),
            principal: 2500,
          ),
          _schedule(
            id: 'pending-4',
            periodNo: 4,
            date: DateTime(2026, 5, 1),
            principal: 2500,
          ),
        ];

        final result = recalculator.recalculate(
          contract: contract,
          schedules: schedules,
          prepaymentPrincipalMinor: 0,
          regenerateDates: true,
        );

        expect(schedules.first.expectedRepaymentDate, DateTime(2026, 2, 1));
        expect(result.map((item) => item.expectedRepaymentDate), [
          DateTime(2026, 4, 1),
          DateTime(2026, 5, 1),
          DateTime(2026, 6, 1),
        ]);
      },
    );

    test('rejects pending periods outside the regenerated terms', () {
      final contract = InstallmentContract(
        id: 'contract',
        liabilityAccountId: 'liability',
        sourceType: InstallmentSourceType.disbursement,
        principal: const Money(minorUnits: 10000),
        borrowingDate: DateTime(2026, 1, 1),
        status: InstallmentContractStatus.active,
        createdAt: DateTime(2026, 1, 1),
        stageTerms: InstallmentContractTerms.singleStage(
          id: 'contract:stage:1',
          totalPeriods: 1,
          firstDate: DateTime(2026, 2, 1),
          lastDate: DateTime(2026, 2, 1),
          method: InstallmentRepaymentMethod.equalPrincipal,
          accrual: InterestAccrualMethod.monthly,
          feeMinor: 0,
        ),
      );

      expect(
        () => recalculator.recalculate(
          contract: contract,
          schedules: [
            _schedule(id: 'pending-1', periodNo: 1, principal: 5000),
            _schedule(id: 'pending-2', periodNo: 2, principal: 5000),
          ],
          prepaymentPrincipalMinor: 0,
          regenerateDates: true,
        ),
        throwsA(_invalidCommand(contains('outside the contract terms'))),
      );
    });
  });
}

Matcher _invalidCommand(Matcher message) {
  return isA<BusinessException>()
      .having((error) => error.code, 'code', 'credit.contract.invalid_command')
      .having((error) => error.message, 'message', message);
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'liability',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 10000),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'contract:stage:1',
      totalPeriods: 5,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 6, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.monthly,
      feeMinor: 0,
    ),
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
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'contract:stage:1',
      totalPeriods: totalPeriods,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, totalPeriods + 1, 1),
      method: repaymentMethod,
      ratePeriod: InterestRatePeriod.monthly,
      ratePpm: 30000,
      accrual: InterestAccrualMethod.daily,
      feeMinor: 0,
    ),
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
