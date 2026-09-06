import 'package:decimal/decimal.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/rounding_mode.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/loan_calculator_presentation.dart';

part 'loan_calculator_view_model.g.dart';

final _logger = Logger('feature.credit.loan_calculator');

@riverpod
class LoanCalculatorViewModel extends _$LoanCalculatorViewModel {
  int _stageSequence = 0;

  @override
  LoanCalculatorState build() {
    final today = _dateOnly(DateTime.now());
    return LoanCalculatorState(
      borrowingDate: today,
      dayCount: DayCountConvention.thirty360,
      rounding: RoundingMode.halfUp,
      stages: [_amortizingDraft(firstRepaymentDate: _addMonths(today, 1))],
      simulatePrepayment: false,
      prepaymentDate: today,
    );
  }

  void setBorrowingDate(DateTime value) {
    state = state.copyWith(borrowingDate: _dateOnly(value));
  }

  void setDayCount(DayCountConvention value) {
    state = state.copyWith(dayCount: value);
  }

  void setRounding(RoundingMode value) {
    state = state.copyWith(rounding: value);
  }

  void setSimulatePrepayment(bool value) {
    state = state.copyWith(simulatePrepayment: value, clearSimulation: !value);
  }

  void setPrepaymentDate(DateTime value) {
    state = state.copyWith(prepaymentDate: _dateOnly(value));
  }

  void addAmortizingStage() {
    final anchor = _timelineEnd();
    _replaceStages([
      ...state.stages,
      _amortizingDraft(firstRepaymentDate: _addMonths(anchor, 1)),
    ]);
  }

  void addDefermentStage() {
    final anchor = _timelineEnd();
    _replaceStages([
      ...state.stages,
      _defermentDraft(untilDate: _addMonths(anchor, 12)),
    ]);
  }

  void removeStage(String stageId) {
    if (state.stages.length <= 1) return;
    _replaceStages([
      for (final stage in state.stages)
        if (stage.id != stageId) stage,
    ]);
  }

  void setStageMethod(String stageId, InstallmentRepaymentMethod value) {
    _updateStage(stageId, (stage) => stage.copyWith(method: value));
  }

  void setStageRatePeriod(String stageId, InterestRatePeriod value) {
    _updateStage(stageId, (stage) => stage.copyWith(ratePeriod: value));
  }

  void setStageAccrual(String stageId, InterestAccrualMethod value) {
    _updateStage(stageId, (stage) => stage.copyWith(accrual: value));
  }

  void setStageInstallmentAmountMode(
    String stageId,
    EqualInstallmentAmountMode value,
  ) {
    _updateStage(
      stageId,
      (stage) => stage.copyWith(installmentAmountMode: value),
    );
  }

  void setStageFirstRepaymentDate(String stageId, DateTime value) {
    _updateStage(
      stageId,
      (stage) => stage.copyWith(firstRepaymentDate: _dateOnly(value)),
    );
  }

  void setStageLastRepaymentDate(String stageId, DateTime? value) {
    _updateStage(
      stageId,
      (stage) => stage.copyWith(
        lastRepaymentDate: value == null ? null : _dateOnly(value),
      ),
    );
  }

  void setStageUntilDate(String stageId, DateTime value) {
    _updateStage(
      stageId,
      (stage) => stage.copyWith(untilDate: _dateOnly(value)),
    );
  }

  /// 产品预设只是阶段的组合方式；金额相关文本按当前本金给出可直接试算的示例值。
  void applyPreset(
    LoanCalculatorPreset preset, {
    required String principalText,
  }) {
    final borrowing = state.borrowingDate;
    final principal = Money.tryParse(principalText.trim());
    final firstMonthly = _addMonths(borrowing, 1);
    final stages = switch (preset) {
      LoanCalculatorPreset.equalInstallment => [
        _amortizingDraft(firstRepaymentDate: firstMonthly, rateText: '7.2'),
      ],
      LoanCalculatorPreset.studentLoan => () {
        final graduation = _addMonths(borrowing, 48);
        final firstInterestOnly = _addMonths(graduation, 12);
        return [
          _defermentDraft(untilDate: graduation),
          _amortizingDraft(
            method: InstallmentRepaymentMethod.interestFirst,
            firstRepaymentDate: firstInterestOnly,
            periodsText: '2',
            intervalMonthsText: '12',
            rateText: '3.1',
            accrual: InterestAccrualMethod.annual,
          ),
          _amortizingDraft(
            method: InstallmentRepaymentMethod.equalPrincipal,
            firstRepaymentDate: _addMonths(firstInterestOnly, 24),
            periodsText: '5',
            intervalMonthsText: '12',
            rateText: '3.1',
            accrual: InterestAccrualMethod.annual,
          ),
        ];
      }(),
      LoanCalculatorPreset.interestFirstThenEqualInstallment => [
        _amortizingDraft(
          method: InstallmentRepaymentMethod.interestFirst,
          firstRepaymentDate: firstMonthly,
          periodsText: '12',
          rateText: '4.8',
        ),
        _amortizingDraft(
          firstRepaymentDate: _addMonths(borrowing, 13),
          periodsText: '24',
          rateText: '4.8',
        ),
      ],
      LoanCalculatorPreset.balloon => [
        _amortizingDraft(
          firstRepaymentDate: firstMonthly,
          periodsText: '36',
          rateText: '5',
          endPrincipalText: principal == null
              ? ''
              : Money(minorUnits: principal.minorUnits ~/ 2).format(),
        ),
      ],
      LoanCalculatorPreset.flatFee => [
        _amortizingDraft(
          method: InstallmentRepaymentMethod.flatFee,
          firstRepaymentDate: firstMonthly,
          periodsText: '1',
          feeText: principal == null
              ? ''
              : Money(
                  minorUnits: (principal.minorUnits * 88 / 1000).round(),
                ).format(),
        ),
      ],
    };
    _replaceStages(stages);
  }

  Future<UiActionOutcome<void>> calculate(LoanCalculatorFormTexts texts) async {
    final current = state;
    final principal = Money.tryParse(texts.principal.trim());
    if (principal == null || principal.minorUnits <= 0) {
      return _invalid('请输入有效本金');
    }
    final stages = <InstallmentStage>[];
    for (var index = 0; index < current.stages.length; index++) {
      final draft = current.stages[index];
      final label = '阶段 ${index + 1}';
      switch (draft.kind) {
        case LoanCalculatorStageKind.deferment:
          stages.add(DefermentStage(until: draft.untilDate));
        case LoanCalculatorStageKind.amortizing:
          final stageTexts =
              texts.stages[draft.id] ?? const LoanCalculatorStageTexts.empty();
          final isFlatFee = draft.method == InstallmentRepaymentMethod.flatFee;
          final periods = isFlatFee
              ? 1
              : int.tryParse(stageTexts.periods.trim());
          if (periods == null || periods <= 0) {
            return _invalid('$label：请输入有效期数');
          }
          final intervalText = stageTexts.intervalMonths.trim();
          final intervalMonths = isFlatFee || intervalText.isEmpty
              ? 1
              : int.tryParse(intervalText);
          if (intervalMonths == null || intervalMonths <= 0) {
            return _invalid('$label：请输入有效各期间隔（月数）');
          }
          InterestRate? rate;
          if (!isFlatFee && stageTexts.rate.trim().isNotEmpty) {
            final ppm = _parseRatePpm(stageTexts.rate);
            if (ppm == null) return _invalid('$label：请输入有效利率');
            rate = InterestRate(ppm: ppm, period: draft.ratePeriod);
          }
          Money? endPrincipal;
          if (stageTexts.endPrincipal.trim().isNotEmpty) {
            endPrincipal = _parseNonNegativeMoney(stageTexts.endPrincipal);
            if (endPrincipal == null) return _invalid('$label：请输入有效期末本金');
          }
          var fee = Money.zero();
          if (isFlatFee && stageTexts.fee.trim().isNotEmpty) {
            final parsed = _parseNonNegativeMoney(stageTexts.fee);
            if (parsed == null) return _invalid('$label：请输入有效手续费');
            fee = parsed;
          }
          var installmentAmount = const EqualInstallmentAmount.nominalRate();
          if (draft.method == InstallmentRepaymentMethod.equalInstallment) {
            Money? fixedAmount;
            if (draft.installmentAmountMode ==
                EqualInstallmentAmountMode.fixed) {
              fixedAmount = _parseNonNegativeMoney(stageTexts.fixedAmount);
              if (fixedAmount == null || fixedAmount.minorUnits <= 0) {
                return _invalid('$label：请输入有效固定还款额');
              }
            }
            installmentAmount = equalInstallmentAmountFor(
              draft.installmentAmountMode,
              fixedAmount: fixedAmount,
            );
          }
          stages.add(
            AmortizingStage(
              dates: IntervalRepaymentDates(
                firstDate: draft.firstRepaymentDate,
                count: periods,
                intervalMonths: intervalMonths,
                lastDate: isFlatFee ? null : draft.lastRepaymentDate,
              ),
              method: draft.method,
              rate: rate,
              accrual: draft.accrual,
              endPrincipal: endPrincipal,
              fee: fee,
              installmentAmount: installmentAmount,
            ),
          );
      }
    }
    final terms = InstallmentPlanTerms(
      principal: principal,
      borrowingDate: current.borrowingDate,
      dayCount: current.dayCount,
      rounding: current.rounding,
      stages: stages,
    );

    int? paidPeriods;
    Money? prepaymentPrincipal;
    if (current.simulatePrepayment && current.canSimulatePrepayment) {
      final paidText = texts.paidPeriods.trim();
      paidPeriods = paidText.isEmpty ? 0 : int.tryParse(paidText);
      if (paidPeriods == null || paidPeriods < 0) {
        return _invalid('请输入有效已还期数');
      }
      prepaymentPrincipal = _parseNonNegativeMoney(texts.prepaymentPrincipal);
      if (prepaymentPrincipal == null || prepaymentPrincipal.minorUnits <= 0) {
        return _invalid('请输入有效提前还款本金');
      }
    }

    return guardUiAction(_logger, 'Loan calculation', () async {
      final query = ref.read(loanCalculatorQueryProvider);
      final result = query.calculate(terms);
      final simulation = paidPeriods == null
          ? null
          : query.simulatePrepayment(
              LoanPrepaymentSimulationRequest(
                terms: terms,
                paidPeriods: paidPeriods,
                prepaymentDate: current.prepaymentDate,
                prepaymentPrincipal: prepaymentPrincipal!,
              ),
            );
      state = state.copyWith(
        result: result,
        simulation: simulation,
        clearSimulation: simulation == null,
      );
    });
  }

  void _replaceStages(List<LoanCalculatorStageDraft> stages) {
    state = state.copyWith(
      stages: stages,
      clearResult: true,
      clearSimulation: true,
    );
  }

  void _updateStage(
    String stageId,
    LoanCalculatorStageDraft Function(LoanCalculatorStageDraft stage) update,
  ) {
    state = state.copyWith(
      stages: [
        for (final stage in state.stages)
          if (stage.id == stageId) update(stage) else stage,
      ],
    );
  }

  DateTime _timelineEnd() {
    if (state.stages.isEmpty) return state.borrowingDate;
    final last = state.stages.last;
    return switch (last.kind) {
      LoanCalculatorStageKind.deferment => last.untilDate,
      LoanCalculatorStageKind.amortizing =>
        last.method == InstallmentRepaymentMethod.flatFee
            ? last.firstRepaymentDate
            : last.lastRepaymentDate ?? last.firstRepaymentDate,
    };
  }

  LoanCalculatorStageDraft _amortizingDraft({
    required DateTime firstRepaymentDate,
    InstallmentRepaymentMethod method =
        InstallmentRepaymentMethod.equalInstallment,
    InterestAccrualMethod accrual = InterestAccrualMethod.monthly,
    String periodsText = '12',
    String intervalMonthsText = '1',
    String rateText = '',
    String endPrincipalText = '',
    String feeText = '',
  }) {
    return LoanCalculatorStageDraft(
      id: _nextStageId(),
      kind: LoanCalculatorStageKind.amortizing,
      method: method,
      ratePeriod: InterestRatePeriod.annual,
      accrual: accrual,
      installmentAmountMode: EqualInstallmentAmountMode.nominalRate,
      firstRepaymentDate: firstRepaymentDate,
      untilDate: firstRepaymentDate,
      periodsText: periodsText,
      intervalMonthsText: intervalMonthsText,
      rateText: rateText,
      endPrincipalText: endPrincipalText,
      feeText: feeText,
      fixedAmountText: '',
    );
  }

  LoanCalculatorStageDraft _defermentDraft({required DateTime untilDate}) {
    return LoanCalculatorStageDraft(
      id: _nextStageId(),
      kind: LoanCalculatorStageKind.deferment,
      method: InstallmentRepaymentMethod.equalInstallment,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.monthly,
      installmentAmountMode: EqualInstallmentAmountMode.nominalRate,
      firstRepaymentDate: untilDate,
      untilDate: untilDate,
      periodsText: '',
      intervalMonthsText: '1',
      rateText: '',
      endPrincipalText: '',
      feeText: '',
      fixedAmountText: '',
    );
  }

  String _nextStageId() => 'stage-${++_stageSequence}';

  UiActionOutcome<void> _invalid(String message) {
    return UiActionOutcome.failure(
      UiError(
        code: CreditErrorCode.contractInvalidCommand.code,
        message: message,
      ),
    );
  }
}

enum LoanCalculatorStageKind { amortizing, deferment }

enum LoanCalculatorPreset {
  equalInstallment,
  studentLoan,
  interestFirstThenEqualInstallment,
  balloon,
  flatFee,
}

class LoanCalculatorStageDraft {
  const LoanCalculatorStageDraft({
    required this.id,
    required this.kind,
    required this.method,
    required this.ratePeriod,
    required this.accrual,
    required this.installmentAmountMode,
    required this.firstRepaymentDate,
    required this.untilDate,
    required this.periodsText,
    required this.intervalMonthsText,
    required this.rateText,
    required this.endPrincipalText,
    required this.feeText,
    required this.fixedAmountText,
    this.lastRepaymentDate,
  });

  final String id;
  final LoanCalculatorStageKind kind;
  final InstallmentRepaymentMethod method;
  final InterestRatePeriod ratePeriod;
  final InterestAccrualMethod accrual;
  final EqualInstallmentAmountMode installmentAmountMode;
  final DateTime firstRepaymentDate;
  final DateTime? lastRepaymentDate;

  /// 免还期截止日。
  final DateTime untilDate;

  /// 文本字段的初始值；用户编辑中的文本由页面控件持有。
  final String periodsText;
  final String intervalMonthsText;
  final String rateText;
  final String endPrincipalText;
  final String feeText;
  final String fixedAmountText;

  LoanCalculatorStageDraft copyWith({
    InstallmentRepaymentMethod? method,
    InterestRatePeriod? ratePeriod,
    InterestAccrualMethod? accrual,
    EqualInstallmentAmountMode? installmentAmountMode,
    DateTime? firstRepaymentDate,
    Object? lastRepaymentDate = _sentinel,
    DateTime? untilDate,
  }) {
    return LoanCalculatorStageDraft(
      id: id,
      kind: kind,
      method: method ?? this.method,
      ratePeriod: ratePeriod ?? this.ratePeriod,
      accrual: accrual ?? this.accrual,
      installmentAmountMode:
          installmentAmountMode ?? this.installmentAmountMode,
      firstRepaymentDate: firstRepaymentDate ?? this.firstRepaymentDate,
      lastRepaymentDate: lastRepaymentDate == _sentinel
          ? this.lastRepaymentDate
          : lastRepaymentDate as DateTime?,
      untilDate: untilDate ?? this.untilDate,
      periodsText: periodsText,
      intervalMonthsText: intervalMonthsText,
      rateText: rateText,
      endPrincipalText: endPrincipalText,
      feeText: feeText,
      fixedAmountText: fixedAmountText,
    );
  }
}

class LoanCalculatorState {
  const LoanCalculatorState({
    required this.borrowingDate,
    required this.dayCount,
    required this.rounding,
    required this.stages,
    required this.simulatePrepayment,
    required this.prepaymentDate,
    this.result,
    this.simulation,
  });

  final DateTime borrowingDate;
  final DayCountConvention dayCount;
  final RoundingMode rounding;
  final List<LoanCalculatorStageDraft> stages;
  final bool simulatePrepayment;
  final DateTime prepaymentDate;
  final LoanCalculation? result;
  final LoanPrepaymentSimulation? simulation;

  /// 提前还款试算沿用合同重算规则，只支持单个还款阶段。
  bool get canSimulatePrepayment =>
      stages.length == 1 &&
      stages.single.kind == LoanCalculatorStageKind.amortizing;

  LoanCalculatorState copyWith({
    DateTime? borrowingDate,
    DayCountConvention? dayCount,
    RoundingMode? rounding,
    List<LoanCalculatorStageDraft>? stages,
    bool? simulatePrepayment,
    DateTime? prepaymentDate,
    LoanCalculation? result,
    LoanPrepaymentSimulation? simulation,
    bool clearResult = false,
    bool clearSimulation = false,
  }) {
    return LoanCalculatorState(
      borrowingDate: borrowingDate ?? this.borrowingDate,
      dayCount: dayCount ?? this.dayCount,
      rounding: rounding ?? this.rounding,
      stages: stages ?? this.stages,
      simulatePrepayment: simulatePrepayment ?? this.simulatePrepayment,
      prepaymentDate: prepaymentDate ?? this.prepaymentDate,
      result: clearResult ? null : result ?? this.result,
      simulation: clearSimulation ? null : simulation ?? this.simulation,
    );
  }
}

/// 页面提交时从控件收集的原始文本。
class LoanCalculatorFormTexts {
  const LoanCalculatorFormTexts({
    required this.principal,
    required this.stages,
    this.paidPeriods = '',
    this.prepaymentPrincipal = '',
  });

  final String principal;
  final Map<String, LoanCalculatorStageTexts> stages;
  final String paidPeriods;
  final String prepaymentPrincipal;
}

class LoanCalculatorStageTexts {
  const LoanCalculatorStageTexts({
    required this.periods,
    required this.intervalMonths,
    required this.rate,
    required this.endPrincipal,
    required this.fee,
    required this.fixedAmount,
  });

  const LoanCalculatorStageTexts.empty()
    : periods = '',
      intervalMonths = '',
      rate = '',
      endPrincipal = '',
      fee = '',
      fixedAmount = '';

  final String periods;
  final String intervalMonths;
  final String rate;
  final String endPrincipal;
  final String fee;
  final String fixedAmount;
}

int? _parseRatePpm(String text) {
  final percent = Decimal.tryParse(text.trim());
  if (percent == null || percent < Decimal.zero) return null;
  return (percent * Decimal.fromInt(10000)).round().toBigInt().toInt();
}

Money? _parseNonNegativeMoney(String text) {
  final money = Money.tryParse(text.trim());
  return money != null && money.minorUnits >= 0 ? money : null;
}

DateTime _addMonths(DateTime date, int months) {
  return IntervalRepaymentDates.addMonthsClamped(date, months);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

const Object _sentinel = Object();
