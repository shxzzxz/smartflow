import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/application/credit/credit_api.dart';

void main() {
  const calc = InstallmentMetricsCalculator();

  InstallmentContract makeContract({
    int principalMinor = 1200000,
    int totalPeriods = 12,
    DateTime? borrowingDate,
    DateTime? firstDate,
    DateTime? lastDate,
    int totalFeeMinor = 0,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    InstallmentRepaymentMethod method =
        InstallmentRepaymentMethod.equalInstallment,
  }) {
    return InstallmentContract(
      id: '1',
      liabilityAccountId: '1',
      sourceType: InstallmentSourceType.disbursement,
      principal: Money(minorUnits: principalMinor),
      totalPeriods: totalPeriods,
      borrowingDate: borrowingDate ?? DateTime(2026, 5, 10),
      firstRepaymentDate: firstDate ?? DateTime(2026, 6, 10),
      lastRepaymentDate: lastDate ?? DateTime(2027, 5, 10),
      repaymentMethod: method,
      interestRatePeriod: ratePeriod,
      interestRatePpm: ratePpm,
      interestAccrualMethod: InterestAccrualMethod.daily,
      totalFeeMinor: totalFeeMinor,
      status: InstallmentContractStatus.active,
      createdAt: DateTime(2026, 5, 10),
    );
  }

  InstallmentSchedule makeSchedule({
    required int id,
    required int periodNo,
    required DateTime date,
    required int principal,
    int interest = 0,
    int fee = 0,
    InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
  }) {
    return InstallmentSchedule(
      id: id,
      contractId: '1',
      periodNo: periodNo,
      expectedRepaymentDate: date,
      expectedPrincipal: Money(minorUnits: principal),
      expectedInterest: Money(minorUnits: interest),
      expectedFee: Money(minorUnits: fee),
      status: status,
      createdAt: DateTime(2026, 5, 10),
    );
  }

  group('InstallmentMetricsCalculator', () {
    test('零利率合同：IRR ≈ 0，总利息 = 0', () {
      final contract = makeContract(principalMinor: 1200000, totalPeriods: 12);
      final schedules = [
        for (var i = 1; i <= 12; i++)
          makeSchedule(
            id: i,
            periodNo: i,
            date: DateTime(
              2026,
              6 + ((i - 1) ~/ 12),
              10 + 0,
            ).add(Duration(days: 30 * (i - 1))),
            principal: 100000,
          ),
      ];
      final m = calc.compute(
        contract: contract,
        schedules: schedules,
        repayments: const [],
      );
      expect(m.totalInterest.minorUnits, 0);
      expect(m.totalFee.minorUnits, 0);
      expect(m.totalRepayment.minorUnits, 1200000);
      expect(m.monthlyIrr.abs(), lessThan(1e-3));
      expect(m.effectiveApr.abs(), lessThan(1e-3));
    });

    test('单期合同 12 万本金 + 6000 利息 = 5% 月化 ≈ 80% APR', () {
      final contract = makeContract(
        principalMinor: 120000,
        totalPeriods: 1,
        firstDate: DateTime(2026, 6, 10),
        lastDate: DateTime(2026, 6, 10),
      );
      final schedules = [
        makeSchedule(
          id: '1',
          periodNo: 1,
          date: DateTime(2026, 6, 10),
          principal: 120000,
          interest: 6000,
        ),
      ];
      final m = calc.compute(
        contract: contract,
        schedules: schedules,
        repayments: const [],
      );
      // 现金流：t0 (5/10) = +120000; t1 (6/10, 31 天后) = -126000
      // (1+EAR)^(31/365) = 126/120 → EAR ≈ ((1.05)^(365/31)) - 1
      // EAR ≈ 0.79 (79%)
      expect(m.effectiveApr, closeTo(0.79, 0.05));
      expect(m.monthlyIrr, closeTo(0.0496, 0.005));
      // nominalApr = 月IRR × 12
      expect(m.nominalApr, closeTo(m.monthlyIrr * 12, 1e-9));
      // effective ≈ (1+月)^12 -1
      expect(m.effectiveApr, closeTo(_pow(1 + m.monthlyIrr, 12) - 1, 1e-6));
    });

    test('提前还本计入 designed IRR，本金合计守恒', () {
      // 原始 12 期合同；第 3 期前提前还本 50%。
      // 提前还本后 pending 行被重算（service 模拟），剩余 pending 本金合计 = 600000
      // designed view 现金流应包含 +1200000，-paid，-extra(600000)，-pending(600000)
      final contract = makeContract(principalMinor: 1200000);
      final schedules = [
        // 前 2 期 paid
        makeSchedule(
          id: '1',
          periodNo: 1,
          date: DateTime(2026, 6, 10),
          principal: 100000,
          status: InstallmentScheduleStatus.paid,
        ),
        makeSchedule(
          id: '2',
          periodNo: 2,
          date: DateTime(2026, 7, 10),
          principal: 100000,
          status: InstallmentScheduleStatus.paid,
        ),
        // 后 10 期 pending，每期 60000（重算后）
        for (var i = 3; i <= 12; i++)
          makeSchedule(
            id: i,
            periodNo: i,
            date: DateTime(2026, 5 + i, 10),
            principal: 60000,
          ),
      ];
      final repayments = [
        // 提前还本 400000，日期在第 2 期还款之后
        RepaymentCashflow(
          id: '1',
          transactionId: '0',
          repaymentType: InstallmentRepaymentType.extraPrincipal,
          occurredAt: DateTime(2026, 8, 1),
          principal: const Money(minorUnits: 400000),
          interest: const Money(minorUnits: 0),
          fee: const Money(minorUnits: 0),
        ),
      ];

      final m = calc.compute(
        contract: contract,
        schedules: schedules,
        repayments: repayments,
      );
      // 本金合计 = 100000 + 100000 + 400000 + 600000 = 1200000 ✓
      expect(m.totalRepayment.minorUnits, 1200000);
      expect(m.totalInterest.minorUnits, 0);
      // 零利息 → IRR ≈ 0
      expect(m.monthlyIrr.abs(), lessThan(1e-3));
    });

    test('actual view 与 designed view 在无差异时相等', () {
      final contract = makeContract(principalMinor: 100000, totalPeriods: 2);
      final schedules = [
        makeSchedule(
          id: '1',
          periodNo: 1,
          date: DateTime(2026, 6, 10),
          principal: 50000,
          interest: 500,
          status: InstallmentScheduleStatus.paid,
        ),
        makeSchedule(
          id: '2',
          periodNo: 2,
          date: DateTime(2026, 7, 10),
          principal: 50000,
          interest: 250,
        ),
      ];
      // actual 数据完全等于 expected
      final repayments = [
        RepaymentCashflow(
          id: '10',
          transactionId: '0',
          repaymentType: InstallmentRepaymentType.scheduled,
          scheduleId: '1',
          occurredAt: DateTime(2026, 6, 10),
          principal: const Money(minorUnits: 50000),
          interest: const Money(minorUnits: 500),
          fee: const Money(minorUnits: 0),
        ),
      ];

      final designed = calc.compute(
        contract: contract,
        schedules: schedules,
        repayments: repayments,
      );
      final actual = calc.compute(
        contract: contract,
        schedules: schedules,
        repayments: repayments,
        view: ContractMetricsView.actual,
      );
      expect(
        designed.totalRepayment.minorUnits,
        actual.totalRepayment.minorUnits,
      );
      expect(designed.monthlyIrr, closeTo(actual.monthlyIrr, 1e-9));
    });
  });
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}
