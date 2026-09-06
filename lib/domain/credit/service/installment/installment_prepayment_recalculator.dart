import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/rounding_mode.dart';
import '../../entity/installment_contract.dart';
import '../../entity/installment_schedule.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/day_count_convention.dart';
import '../../valobj/equal_installment_amount.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/installment_plan_terms.dart';
import '../../valobj/interest_rate.dart';
import '../../valobj/repayment_dates_strategy.dart';
import 'installment_plan_engine.dart';

class InstallmentScheduleRecalculation {
  const InstallmentScheduleRecalculation({
    required this.scheduleId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
  });

  final String scheduleId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
}

/// 重算所依据的单阶段条款。
class InstallmentRecalculationTerms {
  const InstallmentRecalculationTerms({
    required this.principal,
    required this.borrowingDate,
    required this.method,
    required this.accrual,
    this.rate,
    this.endPrincipal,
    this.totalFee = const Money(minorUnits: 0),
    this.installmentAmount = const EqualInstallmentAmount.actualRate(),
    this.dayCount = DayCountConvention.thirty360,
    this.rounding = RoundingMode.halfUp,
    this.intervalMonths = 1,
  });

  final Money principal;
  final DateTime borrowingDate;
  final InstallmentRepaymentMethod method;
  final InterestAccrualMethod accrual;
  final InterestRate? rate;
  final Money? endPrincipal;
  final Money totalFee;
  final EqualInstallmentAmount installmentAmount;
  final DayCountConvention dayCount;
  final RoundingMode rounding;
  final int intervalMonths;
}

/// 参与重算的计划行；[isPending] 为 false 的行在任何情况下都不会被改写。
class InstallmentRecalculationRow {
  const InstallmentRecalculationRow({
    required this.id,
    required this.periodNo,
    required this.date,
    required this.principal,
    required this.interest,
    required this.fee,
    required this.isPending,
  });

  final String id;
  final int periodNo;
  final DateTime date;
  final Money principal;
  final Money interest;
  final Money fee;
  final bool isPending;
}

/// 按锚点规则重算待还尾部。
///
/// 锚点 = max(触发事件的还款日期, 最后一个非待还期次日期)；日期不晚于锚点的期次一律冻结，
/// 锚点之后的连续待还尾部按合同阶段顺序分配剩余本金。
class InstallmentPrepaymentRecalculator {
  const InstallmentPrepaymentRecalculator({
    InstallmentPlanEngine planEngine = const InstallmentPlanEngine(),
  }) : _planEngine = planEngine;

  final InstallmentPlanEngine _planEngine;

  /// [eventDate] 为触发事件的还款日期；按参数重算时为空。
  /// [regenerateDates] 为 true 时尾部日期按合同首期、末期与期数重新生成。
  List<InstallmentScheduleRecalculation> recalculate({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required int prepaymentPrincipalMinor,
    DateTime? eventDate,
    bool regenerateDates = false,
  }) {
    final terms = contract.stageTerms;
    final timeline = [...schedules]
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    DateTime? anchor = eventDate == null ? null : _dateOnly(eventDate);
    for (final row in timeline) {
      if (row.status != InstallmentScheduleStatus.pending &&
          (anchor == null ||
              _dateOnly(row.expectedRepaymentDate).isAfter(anchor))) {
        anchor = _dateOnly(row.expectedRepaymentDate);
      }
    }
    final frozen = timeline
        .where(
          (r) =>
              anchor != null &&
              !_dateOnly(r.expectedRepaymentDate).isAfter(anchor),
        )
        .toList();
    final frozenIds = frozen.map((r) => r.id).toSet();
    final tail = timeline.where((r) => !frozenIds.contains(r.id)).toList();
    final remaining =
        contract.principal.minorUnits -
        prepaymentPrincipalMinor -
        frozen.fold<int>(0, (sum, r) => sum + r.expectedPrincipal.minorUnits);
    if (remaining < 0 || (tail.isEmpty && remaining != 0)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: remaining < 0
            ? 'Remaining principal would be negative.'
            : 'No pending schedule remains after the anchor; restore skipped schedules first.',
      );
    }
    if (tail.isEmpty) return [];
    final generated = <int, ({String stageId, DateTime date})>{};
    var period = 1;
    for (final stage in terms.stages) {
      if (stage.terms case AmortizingStage(:final dates)) {
        for (final date in dates.getDates()) {
          generated[period++] = (stageId: stage.id, date: date);
        }
      }
    }
    String stageId(InstallmentSchedule r) =>
        r.stageId ?? generated[r.periodNo]?.stageId ?? terms.stages.first.id;
    DateTime dateOf(InstallmentSchedule r) {
      if (!regenerateDates) return r.expectedRepaymentDate;
      final value = generated[r.periodNo];
      if (value == null || value.stageId != stageId(r)) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: 'Pending schedule period is outside the contract terms.',
        );
      }
      return value.date;
    }

    _validateTimeline(contract.borrowingDate, [
      for (final r in frozen) r.expectedRepaymentDate,
      for (final r in tail) dateOf(r),
    ]);
    var start = frozen.isEmpty
        ? contract.borrowingDate
        : frozen.last.expectedRepaymentDate;
    final stages = <InstallmentStage>[];
    final orderedTail = <InstallmentSchedule>[];
    var started = false;
    for (final config in terms.stages) {
      final stage = config.terms;
      if (stage is DefermentStage) {
        if (!started) {
          if (stage.until.isAfter(start)) start = stage.until;
        } else {
          stages.add(stage);
        }
        continue;
      }
      final amortizing = stage as AmortizingStage;
      final rows = tail.where((r) => stageId(r) == config.id).toList();
      if (rows.isEmpty) continue;
      final stageFrozen = frozen.where((r) => stageId(r) == config.id).toList();
      final frozenFee = stageFrozen.fold<int>(
        0,
        (sum, r) => sum + r.expectedFee.minorUnits,
      );
      final fee = amortizing.fee.minorUnits - frozenFee;
      stages.add(
        AmortizingStage(
          dates: ExplicitRepaymentDates([
            for (final r in rows) dateOf(r),
          ], intervalMonths: amortizing.dates.intervalMonths),
          accrualStartDate: !started && stageFrozen.isNotEmpty
              ? start
              : amortizing.accrualStartDate,
          method: amortizing.method,
          rate: amortizing.rate,
          accrual: amortizing.accrual,
          endPrincipal: amortizing.endPrincipal,
          fee: Money(minorUnits: fee < 0 ? 0 : fee),
          installmentAmount: amortizing.installmentAmount,
        ),
      );
      orderedTail.addAll(rows);
      started = true;
    }
    if (orderedTail.length != tail.length ||
        [for (final r in orderedTail) r.id].join('|') !=
            [for (final r in tail) r.id].join('|')) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '计划与合同阶段的归属不一致',
      );
    }
    final plan = _planEngine.plan(
      InstallmentPlanTerms(
        principal: Money(minorUnits: remaining),
        borrowingDate: start,
        stages: stages,
        dayCount: terms.dayCount,
        rounding: terms.rounding,
        tailDifference: terms.tailDifference,
      ),
      firstPeriodNo: tail.first.periodNo,
      capEndPrincipal: true,
    );
    return [
      for (var i = 0; i < tail.length; i++)
        InstallmentScheduleRecalculation(
          scheduleId: tail[i].id,
          periodNo: tail[i].periodNo,
          expectedRepaymentDate: dateOf(tail[i]),
          expectedPrincipal: plan.entries[i].expectedPrincipal,
          expectedInterest: plan.entries[i].expectedInterest,
          expectedFee: plan.entries[i].expectedFee,
        ),
    ];
  }

  List<InstallmentScheduleRecalculation> recalculateRows({
    required InstallmentRecalculationTerms terms,
    required List<InstallmentRecalculationRow> rows,
    required Money prepaymentPrincipal,
    DateTime? eventDate,
    Map<int, DateTime>? pendingDatesByPeriodNo,
  }) {
    final timeline = [...rows]
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final anchorDate = _anchorDate(timeline, eventDate);
    final frozen = <InstallmentRecalculationRow>[];
    final tail = <InstallmentRecalculationRow>[];
    for (final row in timeline) {
      final isFrozen =
          anchorDate != null && !_dateOnly(row.date).isAfter(anchorDate);
      (isFrozen ? frozen : tail).add(row);
    }
    final tailDates = [
      for (final row in tail) _pendingDate(row, pendingDatesByPeriodNo),
    ];
    _validateTimeline(terms.borrowingDate, [
      for (final row in frozen) row.date,
      ...tailDates,
    ]);

    final frozenPrincipalMinor = frozen.fold<int>(
      0,
      (sum, row) => sum + row.principal.minorUnits,
    );
    final remainingMinor =
        terms.principal.minorUnits -
        prepaymentPrincipal.minorUnits -
        frozenPrincipalMinor;
    if (remainingMinor < 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Remaining principal would be negative.',
      );
    }
    if (tail.isEmpty) {
      if (remainingMinor == 0) return const [];
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message:
            'No pending schedule remains after the anchor; restore skipped schedules first.',
      );
    }

    final frozenFeeMinor = frozen.fold<int>(
      0,
      (sum, row) => sum + row.fee.minorUnits,
    );
    final remainingFeeMinor = terms.totalFee.minorUnits - frozenFeeMinor;
    final accrualStartDate = frozen.isEmpty
        ? terms.borrowingDate
        : frozen.last.date;
    final entries = _planEngine
        .plan(
          InstallmentPlanTerms(
            principal: Money(minorUnits: remainingMinor),
            borrowingDate: accrualStartDate,
            dayCount: terms.dayCount,
            rounding: terms.rounding,
            stages: [
              AmortizingStage(
                dates: ExplicitRepaymentDates(
                  tailDates,
                  intervalMonths: terms.intervalMonths,
                ),
                accrualStartDate: accrualStartDate,
                method: terms.method,
                rate: terms.rate,
                accrual: terms.accrual,
                endPrincipal: terms.endPrincipal,
                fee: Money(
                  minorUnits: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
                ),
                installmentAmount: terms.installmentAmount,
              ),
            ],
          ),
          firstPeriodNo: tail.first.periodNo,
          capEndPrincipal: true,
        )
        .entries;

    return [
      for (var i = 0; i < tail.length; i++)
        InstallmentScheduleRecalculation(
          scheduleId: tail[i].id,
          periodNo: tail[i].periodNo,
          expectedRepaymentDate: tailDates[i],
          expectedPrincipal: entries[i].expectedPrincipal,
          expectedInterest: entries[i].expectedInterest,
          expectedFee: entries[i].expectedFee,
        ),
    ];
  }

  DateTime? _anchorDate(
    List<InstallmentRecalculationRow> timeline,
    DateTime? eventDate,
  ) {
    DateTime? anchor = eventDate == null ? null : _dateOnly(eventDate);
    for (final row in timeline) {
      if (row.isPending) continue;
      final date = _dateOnly(row.date);
      if (anchor == null || date.isAfter(anchor)) anchor = date;
    }
    return anchor;
  }

  DateTime _pendingDate(
    InstallmentRecalculationRow row,
    Map<int, DateTime>? pendingDatesByPeriodNo,
  ) {
    if (pendingDatesByPeriodNo == null) return row.date;
    final regenerated = pendingDatesByPeriodNo[row.periodNo];
    if (regenerated == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Pending schedule period is outside the contract terms.',
      );
    }
    return regenerated;
  }

  void _validateTimeline(DateTime borrowingDate, List<DateTime> dates) {
    var previous = _dateOnly(borrowingDate);
    for (final date in dates) {
      final current = _dateOnly(date);
      if (!current.isAfter(previous)) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message:
              'Schedule dates must be strictly increasing by period number.',
        );
      }
      previous = current;
    }
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day);
  }
}
