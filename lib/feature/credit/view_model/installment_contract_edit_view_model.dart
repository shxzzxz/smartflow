import 'installment_terms_draft.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../core/money/money.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import '../provider/credit_account_query_providers.dart';
import 'installment_contract_edit_state.dart';

part 'installment_contract_edit_view_model.g.dart';

final _logger = Logger('feature.credit.installment_contract_edit');

@riverpod
class InstallmentContractEditViewModel
    extends _$InstallmentContractEditViewModel {
  @override
  Future<InstallmentContractEditState> build(String contractId) async {
    final contract = await ref.watch(
      installmentContractProvider(contractId).future,
    );
    if (contract == null) return const InstallmentContractEditState.notFound();

    final schedules = await ref.watch(
      installmentSchedulesProvider(contractId).future,
    );
    return InstallmentContractEditState.loaded(
      contract: contract,
      stageDraft: InstallmentTermsDraft.contract(contract.stageTerms),
      customRules: contract.customRules,
      draft: [
        for (final schedule in schedules)
          InstallmentContractDraftRow(
            scheduleId: schedule.id,
            periodNo: schedule.periodNo,
            date: schedule.expectedRepaymentDate,
            principal: schedule.expectedPrincipal,
            interest: schedule.expectedInterest,
            fee: schedule.expectedFee,
            status: schedule.status,
          ),
      ],
    );
  }

  void setStageDraft(InstallmentTermsDraft value) => _updateLoaded(
    (s) => s.copyWith(stageDraft: value, stagePlanPreviewed: false),
  );
  void setCustomRules(bool value) =>
      _updateLoaded((s) => s.copyWith(customRules: value));

  Future<UiActionOutcome<void>> _recalculateStages(
    InstallmentContractEditLoaded loaded,
  ) => guardUiAction(_logger, 'Preview staged contract', () async {
    final terms = loaded.stageDraft.contractTerms();
    final preview = await ref
        .read(installmentAppServiceProvider)
        .previewContractRecalculation(
          RecalculateContractSchedulesCommand(
            contractId: contractId,
            stageTerms: terms,
          ),
        );
    final previous = {for (final row in loaded.draft) row.scheduleId: row};
    _setLoaded(
      loaded.copyWith(
        stagePlanPreviewed: true,
        manualPatchedPeriodNos: {},
        draft: [
          for (final row in preview)
            InstallmentContractDraftRow(
              scheduleId: row.scheduleId,
              periodNo: row.periodNo,
              date: row.expectedRepaymentDate,
              principal: row.expectedPrincipal,
              interest: row.expectedInterest,
              fee: row.expectedFee,
              status:
                  previous[row.scheduleId]?.status ??
                  InstallmentScheduleStatus.pending,
            ),
        ],
      ),
    );
  });

  Future<SubmitOutcome> _submitStages(
    InstallmentContractEditLoaded loaded,
  ) async {
    _setLoaded(loaded.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Save staged contract', () async {
        final terms = loaded.stageDraft.contractTerms();
        await ref
            .read(installmentAppServiceProvider)
            .updateContract(
              UpdateContractCommand(
                contractId: contractId,
                stageTerms: terms,
                customRules: loaded.customRules,
                regeneratePlan: loaded.stagePlanPreviewed,
                schedulePatches: [
                  for (final row in loaded.draft)
                    if (loaded.manualPatchedPeriodNos.contains(row.periodNo))
                      SchedulePendingPatch(
                        periodNo: row.periodNo,
                        expectedPrincipal: row.principal,
                        expectedInterest: row.interest,
                        expectedFee: row.fee,
                        expectedRepaymentDate: row.date,
                      ),
                ],
              ),
            );
        _setLoaded(loaded.copyWith(submitting: false));
        _invalidateCreditContractProviders(loaded.contract.liabilityAccountId);
      });
    } finally {
      final latest = _loadedOrNull();
      if (latest != null) _setLoaded(latest.copyWith(submitting: false));
    }
  }

  Future<UiActionOutcome<void>> recalculate() async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('合同尚未加载');
    return _recalculateStages(loaded);
  }

  void applyAmount(
    InstallmentContractDraftRow row,
    InstallmentAmountField field,
    Money value,
  ) {
    if (row.status != InstallmentScheduleStatus.pending) return;
    final loaded = _loadedOrNull();
    if (loaded == null) return;
    final nextRow = switch (field) {
      InstallmentAmountField.principal => row.copyWith(principal: value),
      InstallmentAmountField.interest => row.copyWith(interest: value),
      InstallmentAmountField.fee => row.copyWith(fee: value),
    };
    _setLoaded(
      loaded.copyWith(
        draft: [
          for (final current in loaded.draft)
            if (current.periodNo == row.periodNo) nextRow else current,
        ],
        manualPatchedPeriodNos: {
          ...loaded.manualPatchedPeriodNos,
          row.periodNo,
        },
      ),
    );
  }

  void editScheduleDate(InstallmentContractDraftRow row, DateTime value) {
    if (row.status != InstallmentScheduleStatus.pending) return;
    final loaded = _loadedOrNull();
    if (loaded == null) return;
    final nextRow = row.copyWith(date: value);
    _setLoaded(
      loaded.copyWith(
        draft: [
          for (final current in loaded.draft)
            if (current.periodNo == row.periodNo) nextRow else current,
        ],
        manualPatchedPeriodNos: {
          ...loaded.manualPatchedPeriodNos,
          row.periodNo,
        },
      ),
    );
  }

  Future<SubmitOutcome> submit() async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidSubmit('合同尚未加载');
    return _submitStages(loaded);
  }

  void _invalidateCreditContractProviders(String liabilityAccountId) {
    ref
      ..invalidate(installmentContractProvider(contractId))
      ..invalidate(installmentSchedulesProvider(contractId))
      ..invalidate(installmentRepaymentsProvider(contractId))
      ..invalidate(installmentMetricsProvider(contractId))
      ..invalidate(installmentContractsByAccountProvider(liabilityAccountId))
      ..invalidate(creditAccountOverviewProvider(liabilityAccountId));
  }

  InstallmentContractEditLoaded? _loadedOrNull() {
    final value = state.asData?.value;
    return value is InstallmentContractEditLoaded ? value : null;
  }

  void _updateLoaded(
    InstallmentContractEditLoaded Function(InstallmentContractEditLoaded loaded)
    update,
  ) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;
    _setLoaded(update(loaded));
  }

  void _setLoaded(InstallmentContractEditLoaded loaded) {
    state = AsyncData(loaded);
  }

  UiActionOutcome<void> _invalidAction(String message) {
    return UiActionOutcome.failure(_invalidCommandError(message));
  }

  SubmitOutcome _invalidSubmit(String message) {
    return SubmitOutcome.failure(_invalidCommandError(message));
  }

  UiError _invalidCommandError(String message) {
    return UiError(
      code: CreditErrorCode.contractInvalidCommand.code,
      message: message,
    );
  }
}
