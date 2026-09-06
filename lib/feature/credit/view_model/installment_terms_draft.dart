import '../../../core/error/app_exception.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../core/money/money.dart';
import '../../../core/money/rounding_mode.dart';
import '../../../domain/credit/valobj/day_count_convention.dart';
import '../../../domain/credit/valobj/equal_installment_amount.dart';
import '../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../domain/credit/valobj/installment_stage_rule.dart';
import '../../../domain/credit/valobj/interest_rate.dart';
import '../../../domain/credit/valobj/repayment_dates_strategy.dart';

enum StageInput { periods, interval, rate, endPrincipal, fixedAmount, fee }

class InstallmentStageDraft {
  InstallmentStageDraft({
    required this.id,
    this.deferment = false,
    this.method = InstallmentRepaymentMethod.equalInstallment,
    this.ratePeriod = InterestRatePeriod.annual,
    this.accrual = InterestAccrualMethod.monthly,
    this.algorithm = InstallmentAmountAlgorithm.nominalRate,
    this.firstDate,
    this.lastDate,
    this.untilDate,
    this.accrualStartDate,
    Map<StageInput, String> inputs = const {StageInput.interval: '1'},
  }) : inputs = Map.unmodifiable(inputs);
  final String id;
  final bool deferment;
  final InstallmentRepaymentMethod method;
  final InterestRatePeriod ratePeriod;
  final InterestAccrualMethod accrual;
  final InstallmentAmountAlgorithm algorithm;
  final DateTime? firstDate, lastDate, untilDate, accrualStartDate;
  final Map<StageInput, String> inputs;
  String text(StageInput field) => inputs[field] ?? '';

  InstallmentStageDraft copyWith({
    bool? deferment,
    InstallmentRepaymentMethod? method,
    InterestRatePeriod? ratePeriod,
    InterestAccrualMethod? accrual,
    InstallmentAmountAlgorithm? algorithm,
    DateTime? firstDate,
    Object? lastDate = _unchanged,
    DateTime? untilDate,
    Map<StageInput, String>? inputs,
  }) => InstallmentStageDraft(
    id: id,
    deferment: deferment ?? this.deferment,
    method: method ?? this.method,
    ratePeriod: ratePeriod ?? this.ratePeriod,
    accrual: accrual ?? this.accrual,
    algorithm: algorithm ?? this.algorithm,
    firstDate: firstDate ?? this.firstDate,
    lastDate: lastDate == _unchanged ? this.lastDate : lastDate as DateTime?,
    untilDate: untilDate ?? this.untilDate,
    accrualStartDate: accrualStartDate,
    inputs: inputs ?? this.inputs,
  );

  InstallmentStageDraft setInput(StageInput field, String value) =>
      copyWith(inputs: {...inputs, field: value});

  InstallmentStageRule toRule() {
    if (deferment) return InstallmentStageRule.deferment(id: id);
    final flat = method == InstallmentRepaymentMethod.flatFee;
    return InstallmentStageRule.repayment(
      id: id,
      method: method,
      intervalMonths: flat
          ? null
          : _positiveInt(text(StageInput.interval), '各期间隔'),
      ratePeriod: flat ? null : ratePeriod,
      accrual: flat ? null : accrual,
      amountAlgorithm: method == InstallmentRepaymentMethod.equalInstallment
          ? algorithm
          : null,
    );
  }

  InstallmentContractStage toContractStage() {
    if (deferment) {
      if (untilDate == null) _invalid('请选择免还结束日');
      return InstallmentContractStage(
        id: id,
        terms: DefermentStage(until: untilDate!),
      );
    }
    if (firstDate == null) _invalid('请选择首期还款日');
    final flat = method == InstallmentRepaymentMethod.flatFee;
    InterestRate? rate = flat ? null : InterestRate(ppm: 0, period: ratePeriod);
    if (!flat && text(StageInput.rate).trim().isNotEmpty) {
      final percent = double.tryParse(text(StageInput.rate).trim());
      if (percent == null || !percent.isFinite || percent < 0) {
        _invalid('请输入有效的非负利率');
      }
      rate = InterestRate(ppm: (percent * 10000).round(), period: ratePeriod);
    }
    return InstallmentContractStage(
      id: id,
      terms: AmortizingStage(
        dates: IntervalRepaymentDates(
          firstDate: firstDate!,
          lastDate: flat ? null : lastDate,
          count: flat ? 1 : _positiveInt(text(StageInput.periods), '期数'),
          intervalMonths: flat
              ? 1
              : _positiveInt(text(StageInput.interval), '各期间隔'),
        ),
        method: method,
        accrual: accrual,
        rate: rate,
        accrualStartDate: accrualStartDate,
        endPrincipal: _money(text(StageInput.endPrincipal), '期末本金'),
        fee: _money(text(StageInput.fee), '手续费') ?? Money.zero(),
        installmentAmount: method != InstallmentRepaymentMethod.equalInstallment
            ? const EqualInstallmentAmount.nominalRate()
            : switch (algorithm) {
                InstallmentAmountAlgorithm.nominalRate =>
                  const EqualInstallmentAmount.nominalRate(),
                InstallmentAmountAlgorithm.actualRate =>
                  const EqualInstallmentAmount.actualRate(),
                InstallmentAmountAlgorithm.fixed =>
                  EqualInstallmentAmount.fixed(
                    _money(text(StageInput.fixedAmount), '指定固定额') ??
                        Money.zero(),
                  ),
              },
      ),
    );
  }

  static int _positiveInt(String value, String label) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) _invalid('$label 必须为正整数');
    return parsed;
  }

  static Money? _money(String value, String label) {
    if (value.trim().isEmpty) return null;
    final parsed = Money.tryParse(value.trim());
    if (parsed == null || parsed.minorUnits < 0) _invalid('$label 必须为非负金额');
    return parsed;
  }
}

class InstallmentTermsDraft {
  InstallmentTermsDraft({
    required List<InstallmentStageDraft> stages,
    this.dayCount = DayCountConvention.thirty360,
    this.rounding = RoundingMode.halfUp,
  }) : stages = List.unmodifiable(stages);
  final List<InstallmentStageDraft> stages;
  final DayCountConvention dayCount;
  final RoundingMode rounding;

  factory InstallmentTermsDraft.initial() =>
      InstallmentTermsDraft(stages: [InstallmentStageDraft(id: 'draft-1')]);
  InstallmentTermsDraft copyWith({
    List<InstallmentStageDraft>? stages,
    DayCountConvention? dayCount,
    RoundingMode? rounding,
  }) => InstallmentTermsDraft(
    stages: stages ?? this.stages,
    dayCount: dayCount ?? this.dayCount,
    rounding: rounding ?? this.rounding,
  );
  InstallmentTermsDraft replace(InstallmentStageDraft stage) => copyWith(
    stages: [for (final old in stages) old.id == stage.id ? stage : old],
  );
  InstallmentTermsDraft add(bool deferment) {
    var suffix = stages.length + 1;
    while (stages.any((s) => s.id == 'draft-$suffix')) {
      suffix++;
    }
    return copyWith(
      stages: [
        ...stages,
        InstallmentStageDraft(id: 'draft-$suffix', deferment: deferment),
      ],
    );
  }

  InstallmentTermsDraft remove(String id) =>
      copyWith(stages: stages.where((s) => s.id != id).toList());
  InstallmentTermsDraft move(int from, int to) {
    final next = [...stages];
    next.insert(to, next.removeAt(from));
    return copyWith(stages: next);
  }

  List<InstallmentStageRule> productRules() => [
    for (final s in stages) s.toRule(),
  ];
  InstallmentContractTerms contractTerms() {
    final terms = InstallmentContractTerms(
      dayCount: dayCount,
      rounding: rounding,
      stages: [for (final s in stages) s.toContractStage()],
    );
    terms.validate();
    return terms;
  }

  factory InstallmentTermsDraft.product(
    List<InstallmentStageRule> stages,
    DayCountConvention dayCount,
    RoundingMode rounding,
  ) => InstallmentTermsDraft(
    dayCount: dayCount,
    rounding: rounding,
    stages: [
      for (final s in stages)
        InstallmentStageDraft(
          id: s.id,
          deferment: s.kind == InstallmentStageKind.deferment,
          method: s.method ?? InstallmentRepaymentMethod.equalInstallment,
          ratePeriod: s.ratePeriod ?? InterestRatePeriod.annual,
          accrual: s.accrual ?? InterestAccrualMethod.monthly,
          algorithm:
              s.amountAlgorithm ?? InstallmentAmountAlgorithm.nominalRate,
          inputs: {StageInput.interval: '${s.intervalMonths ?? 1}'},
        ),
    ],
  );

  factory InstallmentTermsDraft.contract(InstallmentContractTerms terms) =>
      InstallmentTermsDraft(
        dayCount: terms.dayCount,
        rounding: terms.rounding,
        stages: [
          for (final config in terms.stages)
            switch (config.terms) {
              DefermentStage(:final until) => InstallmentStageDraft(
                id: config.id,
                deferment: true,
                untilDate: until,
              ),
              AmortizingStage s => InstallmentStageDraft(
                id: config.id,
                method: s.method,
                firstDate: s.dates.getDates().first,
                lastDate: s.dates is IntervalRepaymentDates
                    ? (s.dates as IntervalRepaymentDates).lastDate
                    : s.dates.getDates().last,
                accrualStartDate: s.accrualStartDate,
                ratePeriod: s.rate?.period ?? InterestRatePeriod.annual,
                accrual: s.accrual,
                algorithm: switch (s.installmentAmount) {
                  NominalRateInstallmentAmount() =>
                    InstallmentAmountAlgorithm.nominalRate,
                  ActualRateInstallmentAmount() =>
                    InstallmentAmountAlgorithm.actualRate,
                  FixedInstallmentAmount() => InstallmentAmountAlgorithm.fixed,
                },
                inputs: {
                  StageInput.interval: '${s.dates.intervalMonths}',
                  StageInput.periods: '${s.dates.getDates().length}',
                  StageInput.rate: s.rate == null
                      ? ''
                      : '${s.rate!.ppm / 10000}',
                  StageInput.fee: s.fee.format(),
                  StageInput.endPrincipal: s.endPrincipal?.format() ?? '',
                  StageInput.fixedAmount:
                      s.installmentAmount is FixedInstallmentAmount
                      ? (s.installmentAmount as FixedInstallmentAmount).amount
                            .format()
                      : '',
                },
              ),
            },
        ],
      );
}

const _unchanged = Object();

Never _invalid(String message) => throw BusinessException(
  CreditErrorCode.contractInvalidCommand,
  message: message,
);
