import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'installment_terms_draft.dart';

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
      terms: InstallmentTermsDraft(
        stages: [_amortizingDraft(firstRepaymentDate: _addMonths(today, 1))],
      ),
      prepaymentDate: today,
    );
  }

  void setTerms(InstallmentTermsDraft value) =>
      state = state.copyWith(terms: value, clearResult: true);
  void invalidateResult() => state = state.copyWith(clearResult: true);
  void setBorrowingDate(DateTime value) => state = state.copyWith(
    borrowingDate: _dateOnly(value),
    clearResult: true,
  );
  void setSimulatePrepayment(bool value) =>
      state = state.copyWith(simulatePrepayment: value, clearResult: true);
  void setPrepaymentDate(DateTime value) => state = state.copyWith(
    prepaymentDate: _dateOnly(value),
    clearResult: true,
  );

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
    setTerms(state.terms.copyWith(stages: stages));
  }

  Future<UiActionOutcome<void>> calculate({
    required String principalText,
    String paidPeriodsText = '',
    String prepaymentPrincipalText = '',
  }) => guardUiAction(_logger, 'Loan calculation', () async {
    final current = state;
    final principal = Money.tryParse(principalText.trim());
    if (principal == null || principal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '请输入有效本金',
      );
    }
    final terms = current.terms.contractTerms().planTerms(
      principal,
      current.borrowingDate,
    );
    final query = ref.read(loanCalculatorQueryProvider);
    final result = query.calculate(terms);
    LoanPrepaymentSimulation? simulation;
    if (current.simulatePrepayment && current.canSimulatePrepayment) {
      final paid = paidPeriodsText.trim().isEmpty
          ? 0
          : int.tryParse(paidPeriodsText.trim());
      final amount = Money.tryParse(prepaymentPrincipalText.trim());
      if (paid == null ||
          paid < 0 ||
          amount == null ||
          amount.minorUnits <= 0) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '请输入有效已还期数和提前还款本金',
        );
      }
      simulation = query.simulatePrepayment(
        LoanPrepaymentSimulationRequest(
          terms: terms,
          paidPeriods: paid,
          prepaymentDate: current.prepaymentDate,
          prepaymentPrincipal: amount,
        ),
      );
    }
    state = current.copyWith(result: result, simulation: simulation);
  });

  InstallmentStageDraft _amortizingDraft({
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
    return InstallmentStageDraft(
      id: _nextStageId(),
      method: method,
      accrual: accrual,
      firstDate: firstRepaymentDate,
      inputs: {
        StageInput.periods: periodsText,
        StageInput.interval: intervalMonthsText,
        StageInput.rate: rateText,
        StageInput.endPrincipal: endPrincipalText,
        StageInput.fee: feeText,
      },
    );
  }

  InstallmentStageDraft _defermentDraft({required DateTime untilDate}) =>
      InstallmentStageDraft(
        id: _nextStageId(),
        deferment: true,
        untilDate: untilDate,
      );

  String _nextStageId() => 'preset-${++_stageSequence}';
}

enum LoanCalculatorPreset {
  equalInstallment,
  studentLoan,
  interestFirstThenEqualInstallment,
  balloon,
  flatFee,
}

class LoanCalculatorState {
  const LoanCalculatorState({
    required this.borrowingDate,
    required this.terms,
    required this.prepaymentDate,
    this.simulatePrepayment = false,
    this.result,
    this.simulation,
  });
  final DateTime borrowingDate, prepaymentDate;
  final InstallmentTermsDraft terms;
  final bool simulatePrepayment;
  final LoanCalculation? result;
  final LoanPrepaymentSimulation? simulation;

  bool get canSimulatePrepayment =>
      terms.stages.length == 1 && !terms.stages.single.deferment;

  LoanCalculatorState copyWith({
    DateTime? borrowingDate,
    DateTime? prepaymentDate,
    InstallmentTermsDraft? terms,
    bool? simulatePrepayment,
    LoanCalculation? result,
    LoanPrepaymentSimulation? simulation,
    bool clearResult = false,
  }) => LoanCalculatorState(
    borrowingDate: borrowingDate ?? this.borrowingDate,
    prepaymentDate: prepaymentDate ?? this.prepaymentDate,
    terms: terms ?? this.terms,
    simulatePrepayment: simulatePrepayment ?? this.simulatePrepayment,
    result: clearResult ? null : result ?? this.result,
    simulation: clearResult ? null : simulation ?? this.simulation,
  );
}

DateTime _addMonths(DateTime date, int months) =>
    IntervalRepaymentDates.addMonthsClamped(date, months);
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
