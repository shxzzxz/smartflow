import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import 'installment_terms_draft.dart';

part 'installment_contract_edit_state.freezed.dart';

@freezed
sealed class InstallmentContractEditState with _$InstallmentContractEditState {
  const factory InstallmentContractEditState.loaded({
    required InstallmentContractReadModel contract,
    required List<InstallmentContractDraftRow> draft,
    @Default({}) Set<int> manualPatchedPeriodNos,
    @Default(false) bool submitting,
    required InstallmentTermsDraft stageDraft,
    @Default(false) bool customRules,
    @Default(false) bool stagePlanPreviewed,
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
