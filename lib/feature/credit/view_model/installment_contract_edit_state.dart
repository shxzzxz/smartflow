import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../application/credit/credit_command_api.dart';
import '../../../core/money/money.dart';

part 'installment_contract_edit_state.freezed.dart';

@freezed
sealed class InstallmentContractEditState with _$InstallmentContractEditState {
  const factory InstallmentContractEditState.loaded({
    required InstallmentContract contract,
    required int paidCount,
    required DateTime firstRepaymentDate,
    required DateTime lastRepaymentDate,
    required InstallmentRepaymentMethod method,
    required InterestRatePeriod ratePeriod,
    required InterestAccrualMethod accrualMethod,
    required List<InstallmentContractDraftRow> draft,
    @Default({}) Set<int> manualPatchedPeriodNos,
    @Default(false) bool submitting,
  }) = InstallmentContractEditLoaded;

  const factory InstallmentContractEditState.notFound() =
      InstallmentContractEditNotFound;
}

@freezed
abstract class InstallmentContractDraftRow with _$InstallmentContractDraftRow {
  const InstallmentContractDraftRow._();

  const factory InstallmentContractDraftRow({
    required int periodNo,
    required DateTime date,
    required Money principal,
    required Money interest,
    required Money fee,
    required InstallmentScheduleStatus status,
    String? scheduleId,
  }) = _InstallmentContractDraftRow;

  Money get total => principal + interest + fee;
}

enum InstallmentAmountField { principal, interest, fee }
