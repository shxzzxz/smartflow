import '../../../domain/credit/valobj/floating_rate.dart';
import '../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import 'installment_terms_draft.dart';
import 'loan_configuration_view_model.dart';

enum LoanChangeOperationKind { prepayment, repricing, interestAdjustment }

sealed class LoanChangeOperation {
  const LoanChangeOperation({required this.id});
  final int id;
  DateTime get date;
  LoanChangeOperationKind get kind;
}

class LoanPrepaymentOperation extends LoanChangeOperation {
  const LoanPrepaymentOperation({required super.id, required this.reduction});
  final PrincipalReduction reduction;
  @override
  DateTime get date => reduction.date;
  @override
  LoanChangeOperationKind get kind => LoanChangeOperationKind.prepayment;
}

class LoanRepricingOperation extends LoanChangeOperation {
  const LoanRepricingOperation({
    required super.id,
    required this.stageId,
    required this.change,
  });
  final String stageId;
  final RateChange change;
  @override
  DateTime get date => change.effectiveDate;
  @override
  LoanChangeOperationKind get kind => LoanChangeOperationKind.repricing;
}

class LoanInterestAdjustmentOperation extends LoanChangeOperation {
  const LoanInterestAdjustmentOperation({
    required super.id,
    required this.adjustment,
  });
  final InterestAdjustment adjustment;
  @override
  DateTime get date => adjustment.accrualRange.start;
  @override
  LoanChangeOperationKind get kind =>
      LoanChangeOperationKind.interestAdjustment;
}

class LoanChangeState {
  LoanChangeState({
    this.configuration,
    List<LoanChangeOperation> operations = const [],
  }) : operations = List.unmodifiable(operations);
  final LoanConfiguration? configuration;
  final List<LoanChangeOperation> operations;

  List<InstallmentStageDraft> get repricingStages => [
    for (final stage
        in configuration?.terms.stages ?? <InstallmentStageDraft>[])
      if (!stage.deferment &&
          stage.method != InstallmentRepaymentMethod.flatFee &&
          stage.method != InstallmentRepaymentMethod.custom)
        stage,
  ];
}
