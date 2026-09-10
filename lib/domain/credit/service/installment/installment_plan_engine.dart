import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/rounding_mode.dart';
import '../../valobj/credit_error_code.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/installment_plan_terms.dart';
import '../../valobj/installment_plan_change.dart';
import '../../valobj/installment_contract_terms.dart';
import '../../valobj/repayment_dates_strategy.dart';
import '../../valobj/repricing_principal_source.dart';
import 'interest_accrual_policy.dart';
import 'floating_rate_calculator.dart';
import 'repayment_method_calculator.dart';

class InstallmentSchedulePlanEntry {
  const InstallmentSchedulePlanEntry({
    required this.periodNo,
    this.stageIndex = 0,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
  });

  final int periodNo;
  final int stageIndex;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
}

/// 一个摊还阶段的计算结果摘要。
class InstallmentStagePlan {
  const InstallmentStagePlan({
    required this.firstPeriodNo,
    required this.lastPeriodNo,
    this.installmentAmount,
    this.lastPeriodDifference,
  });

  final int firstPeriodNo;
  final int lastPeriodNo;

  /// 等额本息实际采用的固定额；其他方式为空。
  final Money? installmentAmount;

  /// 末期本息合计与固定额的差额（正数表示末期多还）；仅等额本息有值。
  final Money? lastPeriodDifference;
}

class InstallmentPlan {
  InstallmentPlan({
    required List<InstallmentSchedulePlanEntry> entries,
    required List<InstallmentStagePlan> stages,
  }) : entries = List.unmodifiable(entries),
       stages = List.unmodifiable(stages);

  final List<InstallmentSchedulePlanEntry> entries;
  final List<InstallmentStagePlan> stages;
}

/// 计划生成与变更的纯计算入口。冻结范围、期次结构、利率和本金来源均在内部确定。
/// 返回不可变结果；不读取数据库、不分配持久化身份、不修改传入实体。
class InstallmentPlanEngine {
  const InstallmentPlanEngine({
    Map<InstallmentRepaymentMethod, RepaymentMethodCalculator>? calculators,
  }) : _calculators = calculators ?? _defaultCalculators;

  /// 一次性手续费是"等额本金 + 免息 + 阶段手续费"的预设，共用等额本金计算器。
  static const _defaultCalculators = {
    InstallmentRepaymentMethod.equalInstallment: EqualInstallmentCalculator(),
    InstallmentRepaymentMethod.equalPrincipal: EqualPrincipalCalculator(),
    InstallmentRepaymentMethod.interestFirst: InterestFirstCalculator(),
    InstallmentRepaymentMethod.flatFee: EqualPrincipalCalculator(),
    InstallmentRepaymentMethod.custom: CustomInstallmentCalculator(),
  };

  final Map<InstallmentRepaymentMethod, RepaymentMethodCalculator> _calculators;

  InstallmentPlan generate(InstallmentPlanTerms terms) => _calculate(terms);

  InstallmentPlanChangeSet recalculate(
    InstallmentPlanContext context,
    InstallmentPlanChangeRequest change,
  ) {
    final eventDate = switch (change) {
      RecalculateFromTerms() => null,
      RecalculateAfterPrepayment(:final repaymentDate) => repaymentDate,
      ApplyInstallmentRepricing(:final record) => record.change.effectiveDate,
    };
    // 先验证旧时间线，再按旧日期冻结，避免新日期改变冻结范围。
    final original = [...context.rows]
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    _validateTimeline(
      context.borrowingDate,
      original.map((r) => r.date).toList(),
    );
    final periods = original.map((r) => r.periodNo).toSet();
    final identities = original.map((r) => r.id).toSet();
    if (periods.length != original.length ||
        identities.length != original.length ||
        original.any((r) => r.id == null || r.periodNo <= 0) ||
        context.prepaymentPrincipal.minorUnits < 0) {
      throw _invalid('计划身份、期序或提前还款本金无效');
    }
    final window = _selectWindow(original, eventDate);
    var terms = context.terms;
    var tail = window.tail;
    final principalSources = <String, RepricingPrincipalSource>{};
    switch (change) {
      case RecalculateFromTerms(terms: final revisedTerms):
        terms = revisedTerms;
        terms.validateReplacementOf(context.terms);
        final layout = _layout(terms);
        final oldLayout = _layout(context.terms);
        final oldByPeriod = {for (final row in original) row.periodNo: row};
        String? stageOf(InstallmentPlanRow row) =>
            row.stageId ?? oldLayout[row.periodNo]?.stageId;
        for (final row in window.frozen) {
          if (!layout.containsKey(row.periodNo) ||
              layout[row.periodNo]!.stageId != stageOf(row)) {
            throw _invalid('阶段结构调整不能移除或移动已冻结期次');
          }
        }
        final frozenPeriods = window.frozen.map((r) => r.periodNo).toSet();
        tail = [
          for (final entry in layout.entries)
            if (!frozenPeriods.contains(entry.key))
              InstallmentPlanRow(
                id: switch (oldByPeriod[entry.key]) {
                  final old? when stageOf(old) == entry.value.stageId => old.id,
                  _ => null,
                },
                stageId: entry.value.stageId,
                periodNo: entry.key,
                date: entry.value.date,
                principal: Money.zero(),
                interest: Money.zero(),
                fee: Money.zero(),
                status: InstallmentScheduleStatus.pending,
              ),
        ];
        break;
      case ApplyInstallmentRepricing(:final record):
        if (record.applied) throw _invalid('重定价结果已应用');
        terms = context.terms.withRepricing(record.stageId, record.change);
        principalSources[record.stageId] =
            RepricingPrincipalSource.scheduleSnapshot({
              for (final row in original) row.date: row.principal,
            });
      case RecalculateAfterPrepayment():
        break;
    }
    return _recalculateTail(
      context,
      change,
      terms,
      window.frozen,
      tail,
      principalSources,
    );
  }

  InstallmentPlanChangeSet _recalculateTail(
    InstallmentPlanContext context,
    InstallmentPlanChangeRequest change,
    InstallmentContractTerms terms,
    List<InstallmentPlanRow> frozen,
    List<InstallmentPlanRow> tail,
    Map<String, RepricingPrincipalSource> principalSources,
  ) {
    final input = _buildTailInput(
      terms: terms,
      principal: context.principal,
      borrowingDate: context.borrowingDate,
      prepaymentPrincipal: context.prepaymentPrincipal,
      window: _RecalculationWindow(frozen: frozen, tail: tail),
      repricingPrincipalSources: principalSources,
    );
    final entries = input == null
        ? <InstallmentSchedulePlanEntry>[]
        : _calculate(
            input.terms,
            firstPeriodNo: tail.first.periodNo,
            capEndPrincipal: true,
            repricingPrincipalSources: input.repricingPrincipalSources,
          ).entries;
    if (entries.length != tail.length) throw _invalid('计算结果与期次结构不一致');
    final result = <InstallmentPlanRow>[
      ...frozen,
      for (var i = 0; i < tail.length; i++)
        InstallmentPlanRow(
          id: tail[i].id,
          stageId: tail[i].stageId,
          periodNo: tail[i].periodNo,
          date: entries[i].expectedRepaymentDate,
          principal: entries[i].expectedPrincipal,
          interest: entries[i].expectedInterest,
          fee: change is ApplyInstallmentRepricing
              ? tail[i].fee
              : entries[i].expectedFee,
          status: tail[i].status,
          manuallyAdjusted: tail[i].manuallyAdjusted,
        ),
    ];
    return InstallmentPlanChangeSet(
      context: context,
      request: change,
      terms: terms,
      rows: result,
      frozenIds: {for (final row in frozen) row.id!},
      recalculatedPeriods: {for (final row in tail) row.periodNo},
    );
  }

  Map<int, ({String stageId, DateTime date})> _layout(
    InstallmentContractTerms terms,
  ) {
    var period = 1;
    return {
      for (final stage in terms.stages)
        if (stage.terms case AmortizingStage(:final dates))
          for (final date in dates.getDates())
            period++: (stageId: stage.id, date: date),
    };
  }

  _RecalculationWindow _selectWindow(
    List<InstallmentPlanRow> rows,
    DateTime? eventDate,
  ) {
    final timeline = [...rows]
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    DateTime? anchorDate = eventDate == null ? null : _dateOnly(eventDate);
    for (final row in timeline) {
      if (row.isPending) continue;
      final date = _dateOnly(row.date);
      if (anchorDate == null || date.isAfter(anchorDate)) anchorDate = date;
    }
    final frozen = timeline
        .where(
          (r) => anchorDate != null && !_dateOnly(r.date).isAfter(anchorDate),
        )
        .toList();
    final frozenIds = frozen.map((r) => r.id).toSet();
    final tail = timeline.where((r) => !frozenIds.contains(r.id)).toList();
    return _RecalculationWindow(frozen: frozen, tail: tail);
  }

  _TailCalculationInput? _buildTailInput({
    required InstallmentContractTerms terms,
    required Money principal,
    required DateTime borrowingDate,
    required Money prepaymentPrincipal,
    required _RecalculationWindow window,
    required Map<String, RepricingPrincipalSource> repricingPrincipalSources,
  }) {
    final frozen = window.frozen;
    final tail = window.tail;
    final remaining =
        principal.minorUnits -
        prepaymentPrincipal.minorUnits -
        frozen.fold<int>(0, (sum, r) => sum + r.principal.minorUnits);
    if (remaining < 0 || (tail.isEmpty && remaining != 0)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: remaining < 0
            ? 'Remaining principal would be negative.'
            : 'No pending schedule remains after the anchor; restore skipped schedules first.',
      );
    }
    if (tail.isEmpty) return null;
    final generated = _layout(terms);
    String stageId(InstallmentPlanRow r) =>
        r.stageId ?? generated[r.periodNo]?.stageId ?? terms.stages.first.id;
    DateTime dateOf(InstallmentPlanRow r) => r.date;

    _validateTimeline(borrowingDate, [
      for (final r in frozen) r.date,
      for (final r in tail) dateOf(r),
    ]);
    var accrualStartDate = frozen.isEmpty ? borrowingDate : frozen.last.date;
    final stages = <InstallmentStage>[];
    final sourcesByStageIndex = <int, RepricingPrincipalSource>{};
    final orderedTail = <InstallmentPlanRow>[];
    var started = false;
    for (final config in terms.stages) {
      final stage = config.terms;
      if (stage is DefermentStage) {
        if (!started) {
          if (stage.until.isAfter(accrualStartDate)) {
            accrualStartDate = stage.until;
          }
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
        (sum, r) => sum + r.fee.minorUnits,
      );
      final fee = amortizing.fee.minorUnits - frozenFee;
      if (repricingPrincipalSources[config.id] case final source?) {
        sourcesByStageIndex[stages.length] = source;
      }
      stages.add(
        AmortizingStage(
          dates: ExplicitRepaymentDates([
            for (final r in rows) dateOf(r),
          ], intervalMonths: amortizing.dates.intervalMonths),
          accrualStartDate: !started && stageFrozen.isNotEmpty
              ? accrualStartDate
              : amortizing.accrualStartDate,
          method: amortizing.method,
          rate: amortizing.rate,
          floatingRate: amortizing.floatingRate,
          rateChanges: amortizing.rateChanges,
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
        [for (final r in orderedTail) r.periodNo].join('|') !=
            [for (final r in tail) r.periodNo].join('|')) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '计划与合同阶段的归属不一致',
      );
    }
    return _TailCalculationInput(
      terms: InstallmentPlanTerms(
        principal: Money(minorUnits: remaining),
        borrowingDate: accrualStartDate,
        stages: stages,
        dayCount: terms.dayCount,
        rounding: terms.rounding,
        tailDifference: terms.tailDifference,
      ),
      repricingPrincipalSources: sourcesByStageIndex,
    );
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

  InstallmentPlan _calculate(
    InstallmentPlanTerms terms, {
    int firstPeriodNo = 1,
    bool capEndPrincipal = false,
    // 本次计算的本金来源按 terms.stages 下标匹配；缺省采用本次投影。
    Map<int, RepricingPrincipalSource> repricingPrincipalSources = const {},
  }) {
    if (terms.principal.minorUnits < 0) {
      throw _invalid('Principal must not be negative.');
    }
    if (terms.stages.isEmpty) {
      throw _invalid('At least one stage is required.');
    }
    if (firstPeriodNo <= 0) {
      throw ArgumentError.value(firstPeriodNo, 'firstPeriodNo', 'Must be > 0');
    }
    final policy = InterestAccrualPolicy(dayCount: terms.dayCount);
    final entries = <InstallmentSchedulePlanEntry>[];
    final stagePlans = <InstallmentStagePlan>[];
    var timelineDate = terms.borrowingDate;
    var openingPrincipal = terms.principal;
    var periodNo = firstPeriodNo;
    for (var index = 0; index < terms.stages.length; index++) {
      final stage = terms.stages[index];
      final isLastStage = index == terms.stages.length - 1;
      switch (stage) {
        case DefermentStage(:final until):
          if (!_dateOnly(until).isAfter(_dateOnly(timelineDate))) {
            throw _invalid('Deferment must end after the previous stage.');
          }
          timelineDate = until;
        case AmortizingStage():
          final result = _planStage(
            stage,
            stageIndex: index,
            policy: policy,
            rounding: terms.rounding,
            capEndPrincipal: capEndPrincipal,
            openingPrincipal: openingPrincipal,
            timelineDate: timelineDate,
            isLastStage: isLastStage,
            firstPeriodNo: periodNo,
            repricingPrincipalSource:
                repricingPrincipalSources[index] ??
                const RepricingPrincipalSource.projection(),
          );
          entries.addAll(result.entries);
          stagePlans.add(result.summary);
          timelineDate = result.entries.last.expectedRepaymentDate;
          openingPrincipal = result.closingPrincipal;
          periodNo += result.entries.length;
      }
    }
    if (entries.isEmpty) {
      throw _invalid('At least one amortizing stage is required.');
    }
    // 自定义合同先生成占位行，再由用户填写本金；自动计划必须一次分配全部本金。
    final hasCustomStage = terms.stages.any(
      (stage) =>
          stage is AmortizingStage &&
          stage.method == InstallmentRepaymentMethod.custom,
    );
    final allocatedPrincipal = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.expectedPrincipal.minorUnits,
    );
    if (!hasCustomStage && allocatedPrincipal != terms.principal.minorUnits) {
      throw _invalid('The plan must allocate the entire principal.');
    }
    return InstallmentPlan(entries: entries, stages: stagePlans);
  }

  _StageResult _planStage(
    AmortizingStage stage, {
    required int stageIndex,
    required InterestAccrualPolicy policy,
    required RoundingMode rounding,
    required bool capEndPrincipal,
    required Money openingPrincipal,
    required DateTime timelineDate,
    required bool isLastStage,
    required int firstPeriodNo,
    required RepricingPrincipalSource repricingPrincipalSource,
  }) {
    final dates = stage.dates.getDates();
    stage.validateFloatingRate();
    if (dates.isEmpty) {
      throw ArgumentError.value(dates, 'repaymentDates', 'Must not be empty');
    }
    if (!_dateOnly(dates.first).isAfter(_dateOnly(timelineDate))) {
      throw _invalid(
        'Repayment dates must be strictly increasing across stages.',
      );
    }
    final accrualStart = stage.accrualStartDate ?? timelineDate;
    final spans = <AccrualPeriodSpan>[];
    var previous = accrualStart;
    for (final date in dates) {
      final days = _daysBetween(previous, date);
      if (days < 1) {
        throw _invalid(
          'Repayment dates must be strictly increasing after the accrual start date.',
        );
      }
      spans.add(
        AccrualPeriodSpan(days: days, months: stage.dates.intervalMonths),
      );
      previous = date;
    }

    final isFlatFee = stage.method == InstallmentRepaymentMethod.flatFee;
    final method = isFlatFee
        ? InstallmentRepaymentMethod.equalPrincipal
        : stage.method;
    final rate = isFlatFee ? null : stage.rate;
    final requestedEndPrincipal = _endPrincipal(
      stage,
      method,
      openingPrincipal,
      isLastStage,
    );
    final endPrincipal =
        capEndPrincipal &&
            requestedEndPrincipal.minorUnits > openingPrincipal.minorUnits
        ? openingPrincipal
        : requestedEndPrincipal;
    if (endPrincipal.minorUnits < 0 ||
        endPrincipal.minorUnits > openingPrincipal.minorUnits) {
      throw _invalid(
        'End principal must be between zero and the opening principal.',
      );
    }
    final balloon =
        isLastStage &&
        stage.endPrincipal != null &&
        endPrincipal.minorUnits > 0;
    final calculator = _calculators[method];
    if (calculator == null) {
      throw StateError('No calculator for $method.');
    }
    // 零本金分摊时按余额计息，指定固定额不能反推出额外本金。
    final effectiveCalculator =
        capEndPrincipal &&
            endPrincipal.minorUnits == openingPrincipal.minorUnits
        ? const InterestFirstCalculator()
        : calculator;
    final calculation = stage.floatingRate != null
        ? const FloatingRateCalculator().calculate(
            stage: stage,
            dates: dates,
            start: accrualStart,
            policy: policy,
            calculator: effectiveCalculator,
            opening: openingPrincipal,
            end: endPrincipal,
            rounding: rounding,
            principalSource: repricingPrincipalSource,
          )
        : effectiveCalculator.calculate(
            RepaymentMethodCalculationInput(
              openingPrincipal: openingPrincipal,
              endPrincipal: endPrincipal,
              rates: [
                for (final span in spans)
                  policy.periodRate(
                    rate: rate,
                    accrual: stage.accrual,
                    span: span,
                  ),
              ],
              rounding: rounding,
              installmentAmount: stage.installmentAmount,
            ),
          );
    if (stage.fee.minorUnits < 0) {
      throw _invalid('Stage fee must not be negative.');
    }
    final fees = splitEvenly(stage.fee.minorUnits, dates.length, rounding);

    final entries = <InstallmentSchedulePlanEntry>[];
    for (var i = 0; i < dates.length; i++) {
      final allocation = calculation.allocations[i];
      final isLastPeriod = i == dates.length - 1;
      entries.add(
        InstallmentSchedulePlanEntry(
          periodNo: firstPeriodNo + i,
          stageIndex: stageIndex,
          expectedRepaymentDate: dates[i],
          expectedPrincipal: balloon && isLastPeriod
              ? allocation.principal + endPrincipal
              : allocation.principal,
          expectedInterest: allocation.interest,
          expectedFee: Money(minorUnits: fees[i]),
        ),
      );
    }
    final installmentAmount = calculation.installmentAmount;
    final last = entries.last;
    return _StageResult(
      entries: entries,
      closingPrincipal: balloon ? Money.zero() : endPrincipal,
      summary: InstallmentStagePlan(
        firstPeriodNo: firstPeriodNo,
        lastPeriodNo: last.periodNo,
        installmentAmount: installmentAmount,
        lastPeriodDifference: installmentAmount == null
            ? null
            : last.expectedPrincipal +
                  last.expectedInterest -
                  installmentAmount,
      ),
    );
  }

  Money _endPrincipal(
    AmortizingStage stage,
    InstallmentRepaymentMethod method,
    Money openingPrincipal,
    bool isLastStage,
  ) {
    final explicit = stage.endPrincipal;
    if (explicit != null) return explicit;
    if (isLastStage) return Money.zero();
    if (method == InstallmentRepaymentMethod.interestFirst) {
      return openingPrincipal;
    }
    throw _invalid(
      'Non-final stages of this repayment method require an explicit end principal.',
    );
  }

  static int _daysBetween(DateTime from, DateTime to) {
    return _dateOnly(to).difference(_dateOnly(from)).inDays;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day);
  }

  static BusinessException _invalid(String message) {
    return BusinessException(
      CreditErrorCode.contractInvalidCommand,
      message: message,
    );
  }
}

class _StageResult {
  const _StageResult({
    required this.entries,
    required this.closingPrincipal,
    required this.summary,
  });

  final List<InstallmentSchedulePlanEntry> entries;
  final Money closingPrincipal;
  final InstallmentStagePlan summary;
}

class _RecalculationWindow {
  _RecalculationWindow({
    required List<InstallmentPlanRow> frozen,
    required List<InstallmentPlanRow> tail,
  }) : frozen = List.unmodifiable(frozen),
       tail = List.unmodifiable(tail);

  final List<InstallmentPlanRow> frozen;
  final List<InstallmentPlanRow> tail;
}

class _TailCalculationInput {
  _TailCalculationInput({
    required this.terms,
    required Map<int, RepricingPrincipalSource> repricingPrincipalSources,
  }) : repricingPrincipalSources = Map.unmodifiable(repricingPrincipalSources);

  final InstallmentPlanTerms terms;

  /// 从合同阶段 ID 转换为裁剪后计划中的阶段下标，包含免还阶段的位置。
  final Map<int, RepricingPrincipalSource> repricingPrincipalSources;
}
