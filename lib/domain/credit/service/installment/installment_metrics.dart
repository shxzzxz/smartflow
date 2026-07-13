import 'dart:math' as math;

import '../../../../core/money/money.dart';
import '../../entity/installment_contract.dart';
import '../../entity/installment_schedule.dart';

enum ContractMetricsUnavailableReason {
  principalNotConserved,
  insufficientCashflows,
  noRateSolution,
}

class ContractMetrics {
  const ContractMetrics.available({
    required this.monthlyIrr,
    required this.nominalApr,
    required this.effectiveApr,
    required this.totalRepayment,
    required this.totalInterest,
    required this.totalFee,
    required this.converged,
  }) : unavailableReason = null;

  const ContractMetrics.unavailable({
    required this.unavailableReason,
    required this.totalRepayment,
    required this.totalInterest,
    required this.totalFee,
  }) : monthlyIrr = null,
       nominalApr = null,
       effectiveApr = null,
       converged = false;

  /// 月 IRR（小数；0.01 = 1%）。
  final double? monthlyIrr;

  /// 名义年化利率 = 月IRR × 12。
  final double? nominalApr;

  /// 有效年化利率 EAR = (1+月IRR)^12 − 1。
  final double? effectiveApr;

  final Money totalRepayment;
  final Money totalInterest;
  final Money totalFee;

  /// 可计算结果的 XIRR 已收敛；不可计算结果固定为 false。
  final bool converged;

  final ContractMetricsUnavailableReason? unavailableReason;

  bool get isAvailable => unavailableReason == null;
}

class InstallmentMetricsCalculator {
  const InstallmentMetricsCalculator();

  ContractMetrics compute({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
  }) {
    var totalRepayMinor = 0;
    var totalInterestMinor = 0;
    var totalFeeMinor = 0;
    final breakdown = _buildBreakdown(schedules: schedules);
    for (final b in breakdown) {
      totalRepayMinor += b.principal + b.interest + b.fee;
      totalInterestMinor += b.interest;
      totalFeeMinor += b.fee;
    }

    final scheduledPrincipalMinor = schedules.fold<int>(
      0,
      (sum, schedule) => sum + schedule.expectedPrincipal.minorUnits,
    );
    if (scheduledPrincipalMinor != contract.principal.minorUnits) {
      return ContractMetrics.unavailable(
        unavailableReason:
            ContractMetricsUnavailableReason.principalNotConserved,
        totalRepayment: Money(minorUnits: totalRepayMinor),
        totalInterest: Money(minorUnits: totalInterestMinor),
        totalFee: Money(minorUnits: totalFeeMinor),
      );
    }

    final flows = _buildCashflows(contract: contract, schedules: schedules);
    final hasPositive = flows.any((flow) => flow.amount > 0);
    final hasNegative = flows.any((flow) => flow.amount < 0);
    if (flows.length < 2 || !hasPositive || !hasNegative) {
      return ContractMetrics.unavailable(
        unavailableReason:
            ContractMetricsUnavailableReason.insufficientCashflows,
        totalRepayment: Money(minorUnits: totalRepayMinor),
        totalInterest: Money(minorUnits: totalInterestMinor),
        totalFee: Money(minorUnits: totalFeeMinor),
      );
    }

    final xirrResult = _xirr(flows);
    if (!xirrResult.converged) {
      return ContractMetrics.unavailable(
        unavailableReason: ContractMetricsUnavailableReason.noRateSolution,
        totalRepayment: Money(minorUnits: totalRepayMinor),
        totalInterest: Money(minorUnits: totalInterestMinor),
        totalFee: Money(minorUnits: totalFeeMinor),
      );
    }
    final ear = xirrResult.rate;
    final monthlyIrr = math.pow(1 + ear, 1 / 12) - 1;
    final nominalApr = monthlyIrr * 12;

    return ContractMetrics.available(
      monthlyIrr: monthlyIrr.toDouble(),
      nominalApr: nominalApr.toDouble(),
      effectiveApr: ear,
      totalRepayment: Money(minorUnits: totalRepayMinor),
      totalInterest: Money(minorUnits: totalInterestMinor),
      totalFee: Money(minorUnits: totalFeeMinor),
      converged: xirrResult.converged,
    );
  }

  // ---------- 内部 ----------

  List<_DatedCashflow> _buildCashflows({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
  }) {
    final flows = <_DatedCashflow>[];
    // t0: 借款流入
    flows.add(
      _DatedCashflow(
        date: contract.borrowingDate,
        amount: contract.principal.minorUnits.toDouble(),
      ),
    );
    final breakdown = _buildBreakdown(schedules: schedules);
    for (final b in breakdown) {
      final outflow = -(b.principal + b.interest + b.fee).toDouble();
      if (outflow == 0) continue;
      flows.add(_DatedCashflow(date: b.date, amount: outflow));
    }
    flows.sort((a, b) => a.date.compareTo(b.date));
    return flows;
  }

  List<_Breakdown> _buildBreakdown({
    required List<InstallmentSchedule> schedules,
  }) {
    final out = <_Breakdown>[];

    for (final s in schedules) {
      out.add(
        _Breakdown(
          date: s.expectedRepaymentDate,
          principal: s.expectedPrincipal.minorUnits,
          interest: s.expectedInterest.minorUnits,
          fee: s.expectedFee.minorUnits,
        ),
      );
    }

    return out;
  }

  /// XIRR：解出年化利率，使
  ///   ∑ CF_i / (1+r)^((date_i − date_0) / 365) = 0
  _XirrResult _xirr(List<_DatedCashflow> flows) {
    if (flows.length < 2) {
      return const _XirrResult(rate: 0, converged: false);
    }
    final hasPositive = flows.any((f) => f.amount > 0);
    final hasNegative = flows.any((f) => f.amount < 0);
    if (!hasPositive || !hasNegative) {
      return const _XirrResult(rate: 0, converged: false);
    }
    final t0 = flows.first.date;
    final ts = flows
        .map((f) => f.date.difference(t0).inDays / 365.0)
        .toList(growable: false);
    final cfs = flows.map((f) => f.amount).toList(growable: false);

    double f(double r) {
      var sum = 0.0;
      for (var i = 0; i < cfs.length; i++) {
        sum += cfs[i] / math.pow(1 + r, ts[i]);
      }
      return sum;
    }

    double df(double r) {
      var sum = 0.0;
      for (var i = 0; i < cfs.length; i++) {
        sum += -ts[i] * cfs[i] / math.pow(1 + r, ts[i] + 1);
      }
      return sum;
    }

    // Newton-Raphson
    var r = 0.1;
    for (var i = 0; i < 100; i++) {
      final fr = f(r);
      final dfr = df(r);
      if (dfr.abs() < 1e-12) break;
      final next = r - fr / dfr;
      if (!next.isFinite || next <= -0.999) {
        // 失败 → 走 bisection
        break;
      }
      if ((next - r).abs() < 1e-9) {
        return _XirrResult(rate: next, converged: true);
      }
      r = next;
    }
    // bisection 兜底
    var lo = -0.99;
    var hi = 10.0;
    var fLo = f(lo);
    var fHi = f(hi);
    if (fLo.sign == fHi.sign) {
      return _XirrResult(rate: r, converged: false);
    }
    for (var i = 0; i < 200; i++) {
      final mid = (lo + hi) / 2;
      final fMid = f(mid);
      if (fMid.abs() < 1e-9 || (hi - lo) < 1e-10) {
        return _XirrResult(rate: mid, converged: true);
      }
      if (fMid.sign == fLo.sign) {
        lo = mid;
        fLo = fMid;
      } else {
        hi = mid;
        fHi = fMid;
      }
    }
    return _XirrResult(rate: (lo + hi) / 2, converged: false);
  }
}

class _DatedCashflow {
  const _DatedCashflow({required this.date, required this.amount});

  final DateTime date;
  final double amount;
}

class _Breakdown {
  const _Breakdown({
    required this.date,
    required this.principal,
    required this.interest,
    required this.fee,
  });

  final DateTime date;
  final int principal;
  final int interest;
  final int fee;
}

class _XirrResult {
  const _XirrResult({required this.rate, required this.converged});

  final double rate;
  final bool converged;
}
