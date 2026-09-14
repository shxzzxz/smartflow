import 'package:decimal/decimal.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/valobj/floating_rate.dart';
import '../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'loan_change_state.dart';
import 'loan_configuration_view_model.dart';

part 'loan_change_view_model.g.dart';

final _logger = Logger('feature.credit.loan_change');

@riverpod
class LoanChangeViewModel extends _$LoanChangeViewModel {
  var _nextId = 0;

  @override
  LoanChangeState build({LoanConfiguration? initial}) =>
      LoanChangeState(configuration: initial);

  void setConfiguration(LoanConfiguration value) => state = LoanChangeState(
    configuration: value,
    operations: state.operations,
  );

  void removeOperation(int id) => state = LoanChangeState(
    configuration: state.configuration,
    operations: state.operations
        .where((operation) => operation.id != id)
        .toList(),
  );

  Future<UiActionOutcome<void>> savePrepayment({
    int? id,
    required DateTime date,
    required String principalText,
  }) => guardUiAction(_logger, 'Set simulated prepayment', () async {
    final principal = Money.tryParse(principalText.trim());
    if (principal == null || principal.minorUnits <= 0) {
      _invalid('请输入有效提前还本金');
    }
    _save(
      LoanPrepaymentOperation(
        id: id ?? _nextId++,
        reduction: PrincipalReduction(
          date: referenceDate(date),
          principal: principal,
        ),
      ),
    );
  });

  Future<UiActionOutcome<void>> saveRepricing({
    int? id,
    required String stageId,
    required DateTime resetDate,
    required DateTime effectiveDate,
    required InterestRateType referenceRateType,
    required String referenceRateText,
    required String spreadBpText,
  }) => guardUiAction(_logger, 'Set simulated repricing', () async {
    final spread = int.tryParse(spreadBpText.trim());
    if (spread == null) _invalid('请输入整数基点，可为负数');
    if (!referenceRateType.isFloating) _invalid('请选择参考利率类型');
    _save(
      LoanRepricingOperation(
        id: id ?? _nextId++,
        stageId: stageId,
        change: RateChange(
          resetDate: referenceDate(resetDate),
          effectiveDate: referenceDate(effectiveDate),
          referenceRate: ReferenceRate(
            type: referenceRateType,
            // 本次试算假设的报价，不进入公共参考利率历史。
            date: referenceDate(resetDate).subtract(const Duration(days: 1)),
            ratePpm: _parsePercent(referenceRateText, '试算参考利率'),
            source: 'loan-change-simulation',
          ),
          spreadBp: spread,
        ),
      ),
    );
  });

  Future<UiActionOutcome<void>> saveInterestAdjustment({
    int? id,
    required DateTime start,
    required DateTime end,
    required String percentText,
  }) => guardUiAction(_logger, 'Set simulated interest adjustment', () async {
    _save(
      LoanInterestAdjustmentOperation(
        id: id ?? _nextId++,
        adjustment: InterestAdjustment(
          start: referenceDate(start),
          end: referenceDate(end),
          ratioPpm: _parsePercent(percentText, '利息比例'),
        ),
      ),
    );
  });

  Future<UiActionOutcome<LoanChangeSimulation>> simulate() => guardUiAction(
    _logger,
    'Simulate loan changes',
    () async => _calculate(state.operations),
  );

  void _save(LoanChangeOperation operation) {
    final operations =
        [
          for (final existing in state.operations)
            if (existing.id != operation.id) existing,
          operation,
        ]..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
    _calculate(operations);
    state = LoanChangeState(
      configuration: state.configuration,
      operations: operations,
    );
  }

  LoanChangeSimulation _calculate(List<LoanChangeOperation> operations) {
    final configuration = state.configuration;
    if (configuration == null) _invalid('请先完成贷款配置');
    final stageIndexes = {
      for (var i = 0; i < configuration.terms.stages.length; i++)
        configuration.terms.stages[i].id: i,
    };
    final reductions = <PrincipalReduction>[];
    final changes = <int, List<RateChange>>{};
    final adjustments = <InterestAdjustment>[];
    for (final operation in operations) {
      switch (operation) {
        case LoanPrepaymentOperation(:final reduction):
          reductions.add(reduction);
        case LoanRepricingOperation(:final stageId, :final change):
          final index = stageIndexes[stageId];
          if (index == null) _invalid('重定价所属阶段已移除，请编辑或删除该操作');
          (changes[index] ??= []).add(change);
        case LoanInterestAdjustmentOperation(:final adjustment):
          adjustments.add(adjustment);
      }
    }
    return ref
        .read(loanCalculatorQueryProvider)
        .simulateChanges(
          LoanChangeSimulationRequest(
            terms: configuration.terms.contractTerms().planTerms(
              configuration.principal,
              configuration.borrowingDate,
            ),
            operations: InstallmentPlanOperations(
              principalReductions: reductions,
              rateChangesByStage: changes,
              interestAdjustments: adjustments,
            ),
          ),
        );
  }

  int _parsePercent(String text, String label) {
    final value = Decimal.tryParse(text.trim());
    if (value == null || value < Decimal.zero) _invalid('请输入非负$label');
    final scaled = value * Decimal.fromInt(10000);
    if (scaled != scaled.round()) _invalid('$label最多保留四位小数');
    return scaled.toBigInt().toInt();
  }

  Never _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
