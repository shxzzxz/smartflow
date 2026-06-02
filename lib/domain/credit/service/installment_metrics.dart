import 'dart:math' as math;

import '../../../core/money/money.dart';
import '../entity/installment_contract.dart';
import '../entity/installment_schedule.dart';
import '../valobj/installment_enums.dart';

/// 一笔实际还款的"现金流口径"快照，metrics 模块只依赖这个轻量结构，
/// 不直接依赖 transaction_details，避免把仓储耦合进 metrics 模块。
class RepaymentCashflow {
  const RepaymentCashflow({
    required this.id,
    required this.transactionId,
    required this.repaymentType,
    required this.occurredAt,
    required this.principal,
    required this.interest,
    required this.fee,
    this.scheduleId,
  });

  final String id;
  final String transactionId;
  final InstallmentRepaymentType repaymentType;
  final DateTime occurredAt;
  final Money principal;
  final Money interest;
  final Money fee;

  /// 若为正常还款（regular），关联的 schedule id。
  final String? scheduleId;
}

/// 计算视图：
/// - [designed] 合同设计 IRR：paid/pending 期次都用 schedule.expected；extra/settle 用实际
/// - [actual] 实际履约 IRR：paid 用实际交易金额；pending 用 schedule.expected；extra/settle 用实际
enum ContractMetricsView { designed, actual }

class ContractMetrics {
  const ContractMetrics({
    required this.view,
    required this.monthlyIrr,
    required this.nominalApr,
    required this.effectiveApr,
    required this.totalRepayment,
    required this.totalInterest,
    required this.totalFee,
    required this.converged,
  });

  final ContractMetricsView view;

  /// 月 IRR（小数；0.01 = 1%）。
  final double monthlyIrr;

  /// 名义年化利率 = 月IRR × 12。
  final double nominalApr;

  /// 有效年化利率 EAR = (1+月IRR)^12 − 1。
  final double effectiveApr;

  final Money totalRepayment;
  final Money totalInterest;
  final Money totalFee;

  /// XIRR 是否在迭代上限内收敛。
  /// 收敛失败时 monthlyIrr/nominalApr/effectiveApr 仍是兜底 bisection 的最佳估计。
  final bool converged;
}

class InstallmentMetricsCalculator {
  const InstallmentMetricsCalculator();

  ContractMetrics compute({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required List<RepaymentCashflow> repayments,
    ContractMetricsView view = ContractMetricsView.designed,
  }) {
    final flows = _buildCashflows(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
      view: view,
    );

    // 总还款额 / 利息 / 手续费：合计已 paid 期次 + pending 期次 + extra/settle
    var totalRepayMinor = 0;
    var totalInterestMinor = 0;
    var totalFeeMinor = 0;
    for (final f in flows) {
      if (f.amount >= 0) continue; // 流入（principal）跳过
      // 这里 flows 已经把 amount 拆成本金+利息+费的合计，但 metrics 需要分别累加：
      // 因此 metrics 用单独的展开列表（见下）。
    }
    final breakdown = _buildBreakdown(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
      view: view,
    );
    for (final b in breakdown) {
      totalRepayMinor += b.principal + b.interest + b.fee;
      totalInterestMinor += b.interest;
      totalFeeMinor += b.fee;
    }

    final xirrResult = _xirr(flows);
    final ear = xirrResult.rate;
    final monthlyIrr = math.pow(1 + ear, 1 / 12) - 1;
    final nominalApr = monthlyIrr * 12;

    return ContractMetrics(
      view: view,
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
    required List<RepaymentCashflow> repayments,
    required ContractMetricsView view,
  }) {
    final flows = <_DatedCashflow>[];
    // t0: 借款流入
    flows.add(
      _DatedCashflow(
        date: contract.borrowingDate,
        amount: contract.principal.minorUnits.toDouble(),
      ),
    );
    final breakdown = _buildBreakdown(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
      view: view,
    );
    for (final b in breakdown) {
      final outflow = -(b.principal + b.interest + b.fee).toDouble();
      if (outflow == 0) continue;
      flows.add(_DatedCashflow(date: b.date, amount: outflow));
    }
    flows.sort((a, b) => a.date.compareTo(b.date));
    return flows;
  }

  List<_Breakdown> _buildBreakdown({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required List<RepaymentCashflow> repayments,
    required ContractMetricsView view,
  }) {
    final out = <_Breakdown>[];

    // 索引：scheduleId -> 实际 repayment（scheduled）
    final actualByScheduleId = <String, RepaymentCashflow>{
      for (final r in repayments)
        if (r.repaymentType == InstallmentRepaymentType.scheduled &&
            r.scheduleId != null)
          r.scheduleId!: r,
    };

    for (final s in schedules) {
      if (s.status == InstallmentScheduleStatus.skipped) continue;
      final isPaid = s.status == InstallmentScheduleStatus.paid;
      if (view == ContractMetricsView.actual && isPaid) {
        final actual = actualByScheduleId[s.id];
        if (actual != null) {
          out.add(
            _Breakdown(
              date: actual.occurredAt,
              principal: actual.principal.minorUnits,
              interest: actual.interest.minorUnits,
              fee: actual.fee.minorUnits,
            ),
          );
          continue;
        }
      }
      // designed view 或 actual view 找不到实际：用 expected
      out.add(
        _Breakdown(
          date: s.expectedRepaymentDate,
          principal: s.expectedPrincipal.minorUnits,
          interest: s.expectedInterest.minorUnits,
          fee: s.expectedFee.minorUnits,
        ),
      );
    }

    // 提前还本 / 提前结清：始终用实际金额（保证本金合计正确）
    for (final r in repayments) {
      if (r.repaymentType == InstallmentRepaymentType.extraPrincipal ||
          r.repaymentType == InstallmentRepaymentType.earlySettlement) {
        out.add(
          _Breakdown(
            date: r.occurredAt,
            principal: r.principal.minorUnits,
            interest: r.interest.minorUnits,
            fee: r.fee.minorUnits,
          ),
        );
      }
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
