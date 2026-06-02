import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';

void main() {
  const generator = InstallmentScheduleGenerator();

  group('InstallmentScheduleGenerator.generateDates', () {
    test('totalPeriods=1 时返回末期日', () {
      final dates = generator.generateDates(
        firstRepaymentDate: DateTime(2026, 2, 10),
        lastRepaymentDate: DateTime(2026, 12, 10),
        totalPeriods: 1,
      );
      expect(dates, [DateTime(2026, 12, 10)]);
    });

    test('中间期 = 首期 + (i-1) 月，末期为末期还款日', () {
      final dates = generator.generateDates(
        firstRepaymentDate: DateTime(2026, 1, 15),
        lastRepaymentDate: DateTime(2026, 12, 20),
        totalPeriods: 12,
      );
      expect(dates.first, DateTime(2026, 1, 15));
      expect(dates.last, DateTime(2026, 12, 20));
      // 中间期日期都是 15 号
      for (var i = 1; i < dates.length - 1; i++) {
        expect(dates[i].day, 15);
      }
      expect(dates, hasLength(12));
    });

    test('期数 <= 0 抛错', () {
      expect(
        () => generator.generateDates(
          firstRepaymentDate: DateTime(2026, 1, 1),
          lastRepaymentDate: DateTime(2026, 6, 1),
          totalPeriods: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('InstallmentScheduleGenerator.generate (整体)', () {
    test('equalInstallment：本金累计等于合同本金', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 1200000),
        borrowingDate: DateTime(2026, 5, 10),
        firstRepaymentDate: DateTime(2026, 6, 10),
        lastRepaymentDate: DateTime(2027, 5, 10),
        totalPeriods: 12,
        method: InstallmentRepaymentMethod.equalInstallment,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.annual,
        ratePpm: 72000,
      );
      final principalSum = drafts.fold<int>(
        0,
        (acc, d) => acc + d.expectedPrincipal.minorUnits,
      );
      expect(principalSum, 1200000);
      expect(drafts, hasLength(12));
    });

    test('equalInstallment 零利率退化为等额本金', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 1000),
        borrowingDate: DateTime(2026, 1, 1),
        firstRepaymentDate: DateTime(2026, 2, 1),
        lastRepaymentDate: DateTime(2026, 5, 1),
        totalPeriods: 4,
        method: InstallmentRepaymentMethod.equalInstallment,
        accrualMethod: InterestAccrualMethod.daily,
      );
      for (final d in drafts) {
        expect(d.expectedInterest.minorUnits, 0);
      }
      final sum = drafts.fold<int>(
        0,
        (acc, d) => acc + d.expectedPrincipal.minorUnits,
      );
      expect(sum, 1000);
    });

    test('equalPrincipal 本金均分，末期吸收误差', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 1000),
        borrowingDate: DateTime(2026, 1, 1),
        firstRepaymentDate: DateTime(2026, 2, 1),
        lastRepaymentDate: DateTime(2026, 4, 1),
        totalPeriods: 3,
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000,
      );
      expect(drafts[0].expectedPrincipal.minorUnits, 333);
      expect(drafts[1].expectedPrincipal.minorUnits, 333);
      expect(drafts[2].expectedPrincipal.minorUnits, 334);
    });

    test('interestFirst 前 N-1 期只付息，末期付本金', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 100000),
        borrowingDate: DateTime(2026, 1, 1),
        firstRepaymentDate: DateTime(2026, 2, 1),
        lastRepaymentDate: DateTime(2026, 5, 1),
        totalPeriods: 4,
        method: InstallmentRepaymentMethod.interestFirst,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000,
      );
      expect(drafts[0].expectedPrincipal.minorUnits, 0);
      expect(drafts[1].expectedPrincipal.minorUnits, 0);
      expect(drafts[2].expectedPrincipal.minorUnits, 0);
      expect(drafts[3].expectedPrincipal.minorUnits, 100000);
    });

    test('flatFee 本金 + 手续费均分', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 500000),
        borrowingDate: DateTime(2026, 5, 9),
        firstRepaymentDate: DateTime(2026, 6, 9),
        lastRepaymentDate: DateTime(2027, 5, 9),
        totalPeriods: 12,
        method: InstallmentRepaymentMethod.flatFee,
        accrualMethod: InterestAccrualMethod.daily,
        totalFeeMinor: 36000,
      );
      final principalSum = drafts.fold<int>(
        0,
        (acc, d) => acc + d.expectedPrincipal.minorUnits,
      );
      final feeSum = drafts.fold<int>(
        0,
        (acc, d) => acc + d.expectedFee.minorUnits,
      );
      expect(principalSum, 500000);
      expect(feeSum, 36000);
    });

    test('custom 返回 N 个全零草稿，日期由 generateDates 决定', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 9999),
        borrowingDate: DateTime(2025, 12, 15),
        firstRepaymentDate: DateTime(2026, 1, 15),
        lastRepaymentDate: DateTime(2026, 5, 15),
        totalPeriods: 5,
        method: InstallmentRepaymentMethod.custom,
        accrualMethod: InterestAccrualMethod.daily,
      );
      expect(drafts, hasLength(5));
      expect(drafts.first.periodNo, 1);
      expect(drafts.last.periodNo, 5);
      for (final d in drafts) {
        expect(d.expectedPrincipal.minorUnits, 0);
      }
    });

    test('daily + equalPrincipal 不规则首期：首期跨 45 天，利息按天数比例放大', () {
      // 借款 2026-01-01，首期 2026-02-15（45 天），末期 2026-05-15
      // 首期天数比 30 天多 15 天，利息应明显大于标准月供利息
      final drafts = generator.generate(
        principal: const Money(minorUnits: 1000000),
        borrowingDate: DateTime(2026, 1, 1),
        firstRepaymentDate: DateTime(2026, 2, 15),
        lastRepaymentDate: DateTime(2026, 5, 15),
        totalPeriods: 4,
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000, // 1%/月
      );
      // 首期天数 = 45
      // 等额本金 4 期：每期本金 250000，第 1 期占用本金 = 1000000
      // 标准利息 = 1000000 * 0.01 = 10000
      // 实际首期利息 ≈ 10000 * 45/30 = 15000
      expect(drafts[0].expectedInterest.minorUnits, closeTo(15000, 100));
    });

    test('daily + interestFirst 不规则末期：末期天数缩短，利息按比例缩小', () {
      // 借款 2026-01-01，首期 2026-02-01，末期 2026-04-15（仅 14 天 vs 30 天）
      final drafts = generator.generate(
        principal: const Money(minorUnits: 1000000),
        borrowingDate: DateTime(2026, 1, 1),
        firstRepaymentDate: DateTime(2026, 2, 1),
        lastRepaymentDate: DateTime(2026, 4, 15),
        totalPeriods: 3,
        method: InstallmentRepaymentMethod.interestFirst,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000,
      );
      // 末期天数 = 31（3/15 → 4/15）
      // 第 1 期 = 31 天 (2/1 - 1/1)
      // 第 2 期 = 28 天 (3/1 - 2/1)
      // 第 3 期 = 45 天 (4/15 - 3/1)
      // 利息 = 1000000 * 0.01 * (days/30)
      expect(drafts[0].expectedInterest.minorUnits, closeTo(10333, 50));
      expect(drafts[1].expectedInterest.minorUnits, closeTo(9333, 50));
      expect(drafts[2].expectedInterest.minorUnits, closeTo(15000, 50));
    });

    test('monthly + equalInstallment：各期 total 严格相等（末期容差 ≤ 10 minor）', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 1200000),
        borrowingDate: DateTime(2026, 5, 10),
        firstRepaymentDate: DateTime(2026, 6, 10),
        lastRepaymentDate: DateTime(2027, 5, 10),
        totalPeriods: 12,
        method: InstallmentRepaymentMethod.equalInstallment,
        accrualMethod: InterestAccrualMethod.monthly,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000, // 1%/月
      );
      expect(drafts, hasLength(12));
      // 中间期 total 严格相等
      final firstTotal =
          drafts.first.expectedPrincipal.minorUnits +
          drafts.first.expectedInterest.minorUnits;
      for (var i = 1; i < 11; i++) {
        final t =
            drafts[i].expectedPrincipal.minorUnits +
            drafts[i].expectedInterest.minorUnits;
        expect(t, firstTotal, reason: 'period ${i + 1} total');
      }
      // 末期受 round() 累积误差影响，与中间期相比偏差应 ≤ 10 minor
      final lastTotal =
          drafts.last.expectedPrincipal.minorUnits +
          drafts.last.expectedInterest.minorUnits;
      expect((lastTotal - firstTotal).abs(), lessThanOrEqualTo(10));
      // 本金累加 = 总本金
      final principalSum = drafts.fold<int>(
        0,
        (acc, d) => acc + d.expectedPrincipal.minorUnits,
      );
      expect(principalSum, 1200000);
    });

    test('monthly + equalPrincipal：不规则天数不影响利息', () {
      // 借款 2026-01-01，首期 2026-02-15（45 天），中间 2026-03-15（28 天），末期 2026-04-15（31 天）
      final drafts = generator.generate(
        principal: const Money(minorUnits: 1000000),
        borrowingDate: DateTime(2026, 1, 1),
        firstRepaymentDate: DateTime(2026, 2, 15),
        lastRepaymentDate: DateTime(2026, 4, 15),
        totalPeriods: 3,
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrualMethod: InterestAccrualMethod.monthly,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000, // 1%/月
      );
      // monthly：利息 = balance × monthlyRate，与天数无关
      // perPrincipal = 333333
      // Period 1: balance=1000000, interest = round(1000000 * 0.01) = 10000
      // Period 2: balance=666667, interest = round(666667 * 0.01) = 6667
      // Period 3 (last): principal = 1000000 - 666666 = 333334, balance = 333334, interest = round(3333.34) = 3333
      expect(drafts[0].expectedInterest.minorUnits, 10000);
      expect(drafts[1].expectedInterest.minorUnits, 6667);
      expect(drafts[2].expectedInterest.minorUnits, 3333);
    });

    test('monthly + interestFirst：各期利息严格相等 = P × r', () {
      final drafts = generator.generate(
        principal: const Money(minorUnits: 100000),
        borrowingDate: DateTime(2026, 1, 1),
        firstRepaymentDate: DateTime(2026, 2, 15), // 不规则首期
        lastRepaymentDate: DateTime(2026, 5, 1),
        totalPeriods: 4,
        method: InstallmentRepaymentMethod.interestFirst,
        accrualMethod: InterestAccrualMethod.monthly,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000,
      );
      for (final d in drafts) {
        expect(d.expectedInterest.minorUnits, 1000);
      }
      expect(drafts[0].expectedPrincipal.minorUnits, 0);
      expect(drafts[1].expectedPrincipal.minorUnits, 0);
      expect(drafts[2].expectedPrincipal.minorUnits, 0);
      expect(drafts[3].expectedPrincipal.minorUnits, 100000);
    });
  });

  group('InstallmentScheduleGenerator.allocate (按 dates 重算)', () {
    test('给定 anchor + dates 分配等额本金', () {
      final allocs = generator.allocate(
        remainingPrincipal: const Money(minorUnits: 600000),
        anchorDate: DateTime(2026, 3, 10),
        pendingDates: [
          DateTime(2026, 4, 10),
          DateTime(2026, 5, 10),
          DateTime(2026, 6, 10),
        ],
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 5000,
      );
      final sum = allocs.fold<int>(0, (acc, a) => acc + a.principal.minorUnits);
      expect(sum, 600000);
      expect(allocs, hasLength(3));
    });

    test('pendingDates 为空抛错', () {
      expect(
        () => generator.allocate(
          remainingPrincipal: const Money(minorUnits: 1000),
          anchorDate: DateTime(2026, 1, 1),
          pendingDates: const [],
          method: InstallmentRepaymentMethod.equalPrincipal,
          accrualMethod: InterestAccrualMethod.daily,
        ),
        throwsArgumentError,
      );
    });

    test('daily + equalInstallment：首期 45 天用现金流折现求 A', () {
      // 本金 10000，月利率 1%（d = 0.01/30），3 期 days=[45,30,30]
      // f1 = 1.015, f2 = f3 = 1.01
      // prodAll = 1.015 · 1.01 · 1.01 = 1.0354015
      // sumOfProducts = 1.0201 + 1.01 + 1 = 3.0301
      // A = round(10000 · 1.0354015 / 3.0301) = round(3417.05) = 3417
      // Period 1: balance=10000, interest=round(10000·0.01·45/30)=150,
      //           principal = 3417 - 150 = 3267; new balance = 6733
      // Period 2: balance=6733,  interest=round(6733·0.01·30/30)=67,
      //           principal = 3417 - 67 = 3350; new balance = 3383
      // Period 3 (last): principal = 10000 - 3267 - 3350 = 3383
      //                  interest = round(3383·0.01·30/30) = 34
      final allocs = generator.allocate(
        remainingPrincipal: const Money(minorUnits: 10000),
        anchorDate: DateTime(2026, 1, 1),
        pendingDates: [
          DateTime(2026, 2, 15), // +45 days
          DateTime(2026, 3, 17), // +30 days
          DateTime(2026, 4, 16), // +30 days
        ],
        method: InstallmentRepaymentMethod.equalInstallment,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000,
      );
      expect(allocs[0].interest.minorUnits, 150);
      expect(allocs[0].principal.minorUnits, 3267);
      expect(allocs[1].interest.minorUnits, 67);
      expect(allocs[1].principal.minorUnits, 3350);
      expect(allocs[2].principal.minorUnits, 3383);
      final principalSum = allocs.fold<int>(
        0,
        (a, x) => a + x.principal.minorUnits,
      );
      expect(principalSum, 10000);
    });

    test('daily + equalInstallment 退化：所有期 30 天时数值与 monthly 一致', () {
      final anchor = DateTime(2026, 1, 1);
      final dates = [
        for (var i = 1; i <= 12; i++) anchor.add(Duration(days: 30 * i)),
      ];
      final dailyAllocs = generator.allocate(
        remainingPrincipal: const Money(minorUnits: 1200000),
        anchorDate: anchor,
        pendingDates: dates,
        method: InstallmentRepaymentMethod.equalInstallment,
        accrualMethod: InterestAccrualMethod.daily,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000,
      );
      final monthlyAllocs = generator.allocate(
        remainingPrincipal: const Money(minorUnits: 1200000),
        anchorDate: anchor,
        pendingDates: dates,
        method: InstallmentRepaymentMethod.equalInstallment,
        accrualMethod: InterestAccrualMethod.monthly,
        ratePeriod: InterestRatePeriod.monthly,
        ratePpm: 10000,
      );
      for (var i = 0; i < 12; i++) {
        expect(
          dailyAllocs[i].principal.minorUnits,
          monthlyAllocs[i].principal.minorUnits,
          reason: 'period ${i + 1} principal',
        );
        expect(
          dailyAllocs[i].interest.minorUnits,
          monthlyAllocs[i].interest.minorUnits,
          reason: 'period ${i + 1} interest',
        );
      }
    });
  });
}
