import '../../../core/money/money.dart';
import '../enums/installment_enums.dart';

class InstallmentScheduleDraft {
  const InstallmentScheduleDraft({
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
  });

  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
}

/// 单期金额分配结果（不含日期）。
/// allocate() 的输入已提供 pending dates，仅需金额；输出按 dates 顺序对应。
class InstallmentAmountAllocation {
  const InstallmentAmountAllocation({
    required this.principal,
    required this.interest,
    required this.fee,
  });

  final Money principal;
  final Money interest;
  final Money fee;
}

/// 分期还款计划生成器。
///
/// 拆成两个相对独立的能力：
/// - [generateDates] 根据 (首期, 末期, 期数) 推导每期日期；
/// - [allocate] 根据 (锚点日, dates 列表, 待还本金, method, rate, accrual, fee)
///   计算每期金额。
///
/// 拆开的原因：提前还本后的重算只重新分配 pending 期次的金额，
/// 日期保持不变，此时只需要调用 [allocate]，不应该重新生成日期。
class InstallmentScheduleGenerator {
  const InstallmentScheduleGenerator();

  /// 生成 N 期的还款日期。
  /// - dates[0] = firstRepaymentDate
  /// - dates[i] = firstRepaymentDate + i 个月  (1 <= i <= N-2)
  /// - dates[N-1] = lastRepaymentDate
  ///
  /// 若 totalPeriods == 1，结果为 [lastRepaymentDate]；
  /// 若 totalPeriods == 2，结果为 [first, last]。
  List<DateTime> generateDates({
    required DateTime firstRepaymentDate,
    required DateTime lastRepaymentDate,
    required int totalPeriods,
  }) {
    if (totalPeriods <= 0) {
      throw ArgumentError.value(totalPeriods, 'totalPeriods', 'Must be > 0');
    }
    if (totalPeriods == 1) {
      return [lastRepaymentDate];
    }
    final dates = <DateTime>[firstRepaymentDate];
    for (var i = 1; i < totalPeriods - 1; i++) {
      dates.add(_addMonths(firstRepaymentDate, i));
    }
    dates.add(lastRepaymentDate);
    return dates;
  }

  /// 按给定 dates 分配本金 / 利息 / 手续费。
  ///
  /// - [anchorDate] 第一期的"上一个时点"，决定第一期天数：
  ///   - 创建时 = 借款日期；
  ///   - 重算 pending 时 = 最后一个 paid 期次的还款日（若无 paid 则借款日）。
  /// - [pendingDates] 必须按时间升序，且第一个 date 要晚于 anchorDate。
  /// - [remainingPrincipal] 这些 dates 需要分摊的总本金。
  /// - [remainingFeeMinor] 这些 dates 需要分摊的总手续费（flatFee 用）。
  /// - [accrualMethod] 计息方式：
  ///   - daily：利息 = 余额 × 日利率 × 实际天数；
  ///     等额本息下用现金流折现求每期还款额 A。
  ///   - monthly：利息 = 余额 × 月利率（与天数无关）；
  ///     等额本息下用标准月供公式求 A。
  /// - [equalInstallmentOverrideMinor]：等额本息下用户直接给定的每期还款额 A
  ///   （前 N-1 期；末期吸误差）。仅 [InstallmentRepaymentMethod.equalInstallment]
  ///   消费此参数，其它 method 忽略。**该参数仅作为生成期间的瞬态输入，不落库**。
  List<InstallmentAmountAllocation> allocate({
    required Money remainingPrincipal,
    required DateTime anchorDate,
    required List<DateTime> pendingDates,
    required InstallmentRepaymentMethod method,
    required InterestAccrualMethod accrualMethod,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    int remainingFeeMinor = 0,
    int? equalInstallmentOverrideMinor,
  }) {
    if (pendingDates.isEmpty) {
      throw ArgumentError.value(pendingDates, 'pendingDates', 'Must not be empty');
    }
    if (remainingPrincipal.minorUnits < 0) {
      throw ArgumentError.value(
        remainingPrincipal.minorUnits,
        'remainingPrincipal',
        'Must be >= 0',
      );
    }
    final dayCounts = _dayCountsForDates(anchorDate, pendingDates);
    switch (method) {
      case InstallmentRepaymentMethod.equalInstallment:
        return _equalInstallment(
          principal: remainingPrincipal,
          dayCounts: dayCounts,
          ratePeriod: ratePeriod,
          ratePpm: ratePpm,
          accrual: accrualMethod,
          overrideInstallmentMinor: equalInstallmentOverrideMinor,
        );
      case InstallmentRepaymentMethod.equalPrincipal:
        return _equalPrincipal(
          principal: remainingPrincipal,
          dayCounts: dayCounts,
          ratePeriod: ratePeriod,
          ratePpm: ratePpm,
          accrual: accrualMethod,
        );
      case InstallmentRepaymentMethod.interestFirst:
        return _interestFirst(
          principal: remainingPrincipal,
          dayCounts: dayCounts,
          ratePeriod: ratePeriod,
          ratePpm: ratePpm,
          accrual: accrualMethod,
        );
      case InstallmentRepaymentMethod.flatFee:
        return _flatFee(
          principal: remainingPrincipal,
          periods: pendingDates.length,
          remainingFeeMinor: remainingFeeMinor,
        );
      case InstallmentRepaymentMethod.custom:
        return _custom(
          currency: remainingPrincipal.currency,
          periods: pendingDates.length,
        );
    }
  }

  /// 便利方法：一次性生成完整 schedule 草稿（创建合同时使用）。
  List<InstallmentScheduleDraft> generate({
    required Money principal,
    required DateTime borrowingDate,
    required DateTime firstRepaymentDate,
    required DateTime lastRepaymentDate,
    required int totalPeriods,
    required InstallmentRepaymentMethod method,
    required InterestAccrualMethod accrualMethod,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    int totalFeeMinor = 0,
    int? equalInstallmentOverrideMinor,
  }) {
    if (principal.minorUnits <= 0) {
      throw ArgumentError.value(
        principal.minorUnits,
        'principal.minorUnits',
        'Must be > 0',
      );
    }
    final dates = generateDates(
      firstRepaymentDate: firstRepaymentDate,
      lastRepaymentDate: lastRepaymentDate,
      totalPeriods: totalPeriods,
    );
    final allocations = allocate(
      remainingPrincipal: principal,
      anchorDate: borrowingDate,
      pendingDates: dates,
      method: method,
      accrualMethod: accrualMethod,
      ratePeriod: ratePeriod,
      ratePpm: ratePpm,
      remainingFeeMinor: totalFeeMinor,
      equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
    );
    return [
      for (var i = 0; i < dates.length; i++)
        InstallmentScheduleDraft(
          periodNo: i + 1,
          expectedRepaymentDate: dates[i],
          expectedPrincipal: allocations[i].principal,
          expectedInterest: allocations[i].interest,
          expectedFee: allocations[i].fee,
        ),
    ];
  }

  // ---------- method 实现 ----------

  List<InstallmentAmountAllocation> _equalInstallment({
    required Money principal,
    required List<int> dayCounts,
    required InterestAccrualMethod accrual,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
    int? overrideInstallmentMinor,
  }) {
    final monthlyRate = _toMonthlyRate(ratePeriod, ratePpm);
    final n = dayCounts.length;
    // 求每期还款额 A：
    // - 若用户提供 override，直接采纳（前 N-1 期按此还款，末期吸误差）；
    // - 否则按 accrual 公式推导：
    //   monthly = 标准月供 P · r · (1+r)^n / ((1+r)^n − 1)
    //   daily   = 现金流折现 P · ∏fᵢ / Σⱼ ∏ᵢ>ⱼ fᵢ
    final int installmentMinor;
    if (overrideInstallmentMinor != null && overrideInstallmentMinor > 0) {
      installmentMinor = overrideInstallmentMinor;
    } else if (monthlyRate == 0) {
      return _equalPrincipal(
        principal: principal,
        dayCounts: dayCounts,
        ratePeriod: ratePeriod,
        ratePpm: ratePpm,
        accrual: accrual,
      );
    } else {
      switch (accrual) {
        case InterestAccrualMethod.monthly:
          final p = principal.minorUnits.toDouble();
          final r = monthlyRate;
          final pow = _pow(1 + r, n);
          installmentMinor = (p * r * pow / (pow - 1)).round();
        case InterestAccrualMethod.daily:
          installmentMinor = _solveDailyInstallment(
            principalMinor: principal.minorUnits,
            monthlyRate: monthlyRate,
            dayCounts: dayCounts,
          );
      }
    }

    final allocations = <InstallmentAmountAllocation>[];
    var remaining = principal.minorUnits;
    var principalAccum = 0;
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      final interestMinor = _interestForPeriod(
        balanceMinor: remaining,
        monthlyRate: monthlyRate,
        days: dayCounts[i],
        accrual: accrual,
      );
      var principalMinor = installmentMinor - interestMinor;
      if (isLast) {
        // 末期吸收取整误差：本金 = 剩余全部。
        principalMinor = principal.minorUnits - principalAccum;
      }
      allocations.add(
        InstallmentAmountAllocation(
          principal: Money(
            minorUnits: principalMinor,
            currency: principal.currency,
          ),
          interest: Money(
            minorUnits: interestMinor,
            currency: principal.currency,
          ),
          fee: Money.zero(currency: principal.currency),
        ),
      );
      remaining -= principalMinor;
      principalAccum += principalMinor;
    }
    return allocations;
  }

  List<InstallmentAmountAllocation> _equalPrincipal({
    required Money principal,
    required List<int> dayCounts,
    required InterestAccrualMethod accrual,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
  }) {
    final monthlyRate = _toMonthlyRate(ratePeriod, ratePpm);
    final n = dayCounts.length;
    final perPrincipal = principal.minorUnits ~/ n;
    final allocations = <InstallmentAmountAllocation>[];
    var remaining = principal.minorUnits;
    var principalAccum = 0;
    for (var i = 0; i < n; i++) {
      var principalMinor = perPrincipal;
      if (i == n - 1) {
        principalMinor = principal.minorUnits - principalAccum;
      }
      final interestMinor = _interestForPeriod(
        balanceMinor: remaining,
        monthlyRate: monthlyRate,
        days: dayCounts[i],
        accrual: accrual,
      );
      allocations.add(
        InstallmentAmountAllocation(
          principal: Money(
            minorUnits: principalMinor,
            currency: principal.currency,
          ),
          interest: Money(
            minorUnits: interestMinor,
            currency: principal.currency,
          ),
          fee: Money.zero(currency: principal.currency),
        ),
      );
      remaining -= principalMinor;
      principalAccum += principalMinor;
    }
    return allocations;
  }

  List<InstallmentAmountAllocation> _interestFirst({
    required Money principal,
    required List<int> dayCounts,
    required InterestAccrualMethod accrual,
    InterestRatePeriod? ratePeriod,
    int? ratePpm,
  }) {
    final monthlyRate = _toMonthlyRate(ratePeriod, ratePpm);
    final n = dayCounts.length;
    final allocations = <InstallmentAmountAllocation>[];
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      final interestMinor = _interestForPeriod(
        balanceMinor: principal.minorUnits,
        monthlyRate: monthlyRate,
        days: dayCounts[i],
        accrual: accrual,
      );
      allocations.add(
        InstallmentAmountAllocation(
          principal: Money(
            minorUnits: isLast ? principal.minorUnits : 0,
            currency: principal.currency,
          ),
          interest: Money(
            minorUnits: interestMinor,
            currency: principal.currency,
          ),
          fee: Money.zero(currency: principal.currency),
        ),
      );
    }
    return allocations;
  }

  List<InstallmentAmountAllocation> _flatFee({
    required Money principal,
    required int periods,
    required int remainingFeeMinor,
  }) {
    final perPrincipal = principal.minorUnits ~/ periods;
    final perFee = remainingFeeMinor ~/ periods;
    final allocations = <InstallmentAmountAllocation>[];
    var principalAccum = 0;
    var feeAccum = 0;
    for (var i = 0; i < periods; i++) {
      var principalMinor = perPrincipal;
      var feeMinor = perFee;
      if (i == periods - 1) {
        principalMinor = principal.minorUnits - principalAccum;
        feeMinor = remainingFeeMinor - feeAccum;
      }
      allocations.add(
        InstallmentAmountAllocation(
          principal: Money(
            minorUnits: principalMinor,
            currency: principal.currency,
          ),
          interest: Money.zero(currency: principal.currency),
          fee: Money(
            minorUnits: feeMinor,
            currency: principal.currency,
          ),
        ),
      );
      principalAccum += principalMinor;
      feeAccum += feeMinor;
    }
    return allocations;
  }

  List<InstallmentAmountAllocation> _custom({
    required String currency,
    required int periods,
  }) {
    final zero = Money.zero(currency: currency);
    return [
      for (var i = 0; i < periods; i++)
        InstallmentAmountAllocation(principal: zero, interest: zero, fee: zero),
    ];
  }

  // ---------- 工具 ----------

  /// 单期利息：
  /// - daily 走简单日息：B · d · days，d = monthlyRate / 30；
  /// - monthly 走月利率：B · r（与天数无关）。
  int _interestForPeriod({
    required int balanceMinor,
    required double monthlyRate,
    required int days,
    required InterestAccrualMethod accrual,
  }) {
    switch (accrual) {
      case InterestAccrualMethod.daily:
        // monthlyRate / 30 × days ≡ d × days；用单一乘除避免引入新的浮点路径。
        return (balanceMinor * monthlyRate * days / 30).round();
      case InterestAccrualMethod.monthly:
        return (balanceMinor * monthlyRate).round();
    }
  }

  /// 按日计息下等额本息的每期还款额 A：
  /// A = P · ∏(1+d·days_i) / Σ_j ∏_{i>j}(1+d·days_i)
  /// 退化：days_i = 30 时 f_i = 1 + r，公式回到标准月供。
  /// 一次倒序遍历同时计算 prodAll 与 sumOfProducts，O(n)。
  int _solveDailyInstallment({
    required int principalMinor,
    required double monthlyRate,
    required List<int> dayCounts,
  }) {
    final d = monthlyRate / 30;
    var prodAll = 1.0;
    for (final days in dayCounts) {
      prodAll *= (1 + d * days);
    }
    var sumOfProducts = 0.0;
    var suffix = 1.0;
    for (var i = dayCounts.length - 1; i >= 0; i--) {
      sumOfProducts += suffix;
      suffix *= (1 + d * dayCounts[i]);
    }
    return (principalMinor * prodAll / sumOfProducts).round();
  }

  /// 计算每期的"占用天数"：第 i 期天数 = dates[i] - prevDate (若 i==0 则 anchorDate)。
  /// 至少为 1 天，避免零利息退化。
  List<int> _dayCountsForDates(DateTime anchorDate, List<DateTime> dates) {
    final result = <int>[];
    var prev = anchorDate;
    for (final d in dates) {
      final days = d.difference(prev).inDays;
      result.add(days < 1 ? 1 : days);
      prev = d;
    }
    return result;
  }

  /// 将 (ratePeriod + ratePpm) 换算为月利率小数。
  /// ratePeriod / ratePpm 为空时返回 0。
  double _toMonthlyRate(InterestRatePeriod? period, int? ppm) {
    if (period == null || ppm == null || ppm == 0) {
      return 0;
    }
    final rate = ppm / 1000000.0;
    switch (period) {
      case InterestRatePeriod.annual:
        return rate / 12.0;
      case InterestRatePeriod.monthly:
        return rate;
      case InterestRatePeriod.daily:
        return rate * 30.0;
    }
  }

  double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  DateTime _addMonths(DateTime date, int months) {
    return DateTime(date.year, date.month + months, date.day);
  }
}
