import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../application/credit/credit_query_api.dart';
import 'installment_schedule_draft.dart';
import 'installment_terms_draft.dart';

export 'installment_schedule_draft.dart';

part 'installment_contract_edit_state.freezed.dart';

@freezed
sealed class InstallmentContractEditState with _$InstallmentContractEditState {
  const factory InstallmentContractEditState.loaded({
    required InstallmentContractReadModel contract,
    ContractMetrics? metrics,
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
