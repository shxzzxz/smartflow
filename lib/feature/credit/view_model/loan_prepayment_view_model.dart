import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'loan_configuration_view_model.dart';

part 'loan_prepayment_view_model.g.dart';

final _logger = Logger('feature.credit.loan_prepayment');

class LoanPrepaymentState {
  const LoanPrepaymentState({required this.date, this.configuration});
  final DateTime date;
  final LoanConfiguration? configuration;
}

@riverpod
class LoanPrepaymentViewModel extends _$LoanPrepaymentViewModel {
  @override
  LoanPrepaymentState build() {
    final now = DateTime.now();
    return LoanPrepaymentState(date: DateTime(now.year, now.month, now.day));
  }

  void setConfiguration(LoanConfiguration value) =>
      state = LoanPrepaymentState(date: state.date, configuration: value);
  void setDate(DateTime value) => state = LoanPrepaymentState(
    date: DateTime(value.year, value.month, value.day),
    configuration: state.configuration,
  );

  Future<UiActionOutcome<LoanPrepaymentSimulation>> simulate({
    required String paidPeriodsText,
    required String principalText,
  }) => guardUiAction(_logger, 'Simulate loan prepayment', () async {
    final configuration = state.configuration;
    if (configuration == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '请先完成贷款配置',
      );
    }
    final paid = paidPeriodsText.trim().isEmpty
        ? 0
        : int.tryParse(paidPeriodsText.trim());
    final principal = Money.tryParse(principalText.trim());
    if (paid == null ||
        paid < 0 ||
        principal == null ||
        principal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '请输入有效已还期数和提前还本金',
      );
    }
    return ref
        .read(loanCalculatorQueryProvider)
        .simulatePrepayment(
          LoanPrepaymentSimulationRequest(
            terms: configuration.terms.contractTerms().planTerms(
              configuration.principal,
              configuration.borrowingDate,
            ),
            paidPeriods: paid,
            prepaymentDate: state.date,
            prepaymentPrincipal: principal,
          ),
        );
  });
}
