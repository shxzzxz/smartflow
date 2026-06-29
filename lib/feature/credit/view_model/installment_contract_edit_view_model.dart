import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import 'installment_contract_edit_state.dart';

part 'installment_contract_edit_view_model.g.dart';

@riverpod
class InstallmentContractEditViewModel
    extends _$InstallmentContractEditViewModel {
  static const _generator = InstallmentScheduleGenerator();

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
      paidCount:
          schedules
              .where((s) => s.status == InstallmentScheduleStatus.paid)
              .length,
      firstRepaymentDate: contract.firstRepaymentDate,
      lastRepaymentDate: contract.lastRepaymentDate,
      method: contract.repaymentMethod,
      ratePeriod: contract.interestRatePeriod ?? InterestRatePeriod.monthly,
      accrualMethod: contract.interestAccrualMethod,
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

  void setFirstRepaymentDate(DateTime value) {
    _updateLoaded((loaded) => loaded.copyWith(firstRepaymentDate: value));
  }

  void setLastRepaymentDate(DateTime value) {
    _updateLoaded((loaded) => loaded.copyWith(lastRepaymentDate: value));
  }

  void setMethod(InstallmentRepaymentMethod value) {
    _updateLoaded((loaded) => loaded.copyWith(method: value));
  }

  void setRatePeriod(InterestRatePeriod value) {
    _updateLoaded((loaded) => loaded.copyWith(ratePeriod: value));
  }

  void setAccrualMethod(InterestAccrualMethod value) {
    _updateLoaded((loaded) => loaded.copyWith(accrualMethod: value));
  }

  UiActionOutcome<void> recalculate({
    required String totalPeriodsText,
    required String rateText,
    required String feeText,
    required String overrideInstallmentText,
  }) {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('合同尚未加载');

    final totalPeriods = int.tryParse(totalPeriodsText.trim());
    if (totalPeriods == null || totalPeriods <= 0) {
      return _invalidAction('请输入有效期数');
    }
    if (totalPeriods < loaded.paidCount + 1) {
      return _invalidAction('期数必须不小于已还期数 + 1');
    }
    if (totalPeriods > 1 &&
        !loaded.lastRepaymentDate.isAfter(loaded.firstRepaymentDate)) {
      return _invalidAction('末期还款日必须晚于首期还款日');
    }

    final ratePpm = _parseRatePpm(rateText);
    final feeMinor = _parseOptionalMoney(feeText).minorUnits;
    final overrideMinor =
        loaded.method == InstallmentRepaymentMethod.equalInstallment
            ? _parseOptionalOverride(overrideInstallmentText)
            : null;

    final paidRows =
        loaded.draft
            .where((r) => r.status == InstallmentScheduleStatus.paid)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final pendingRows =
        loaded.draft
            .where((r) => r.status == InstallmentScheduleStatus.pending)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    if (pendingRows.isEmpty) {
      return _invalidAction('没有可重算的待还期次');
    }

    final paidPrincipalMinor = paidRows.fold<int>(
      0,
      (acc, row) => acc + row.principal.minorUnits,
    );
    final paidFeeMinor = paidRows.fold<int>(
      0,
      (acc, row) => acc + row.fee.minorUnits,
    );
    final remainingMinor =
        loaded.contract.principal.minorUnits - paidPrincipalMinor;
    if (remainingMinor < 0) return _invalidAction('剩余本金为负，无法重算');

    final anchorDate =
        paidRows.isEmpty ? loaded.contract.borrowingDate : paidRows.last.date;
    final remainingFeeMinor = feeMinor - paidFeeMinor;
    final allocations = _generator.allocate(
      remainingPrincipal: Money(minorUnits: remainingMinor),
      anchorDate: anchorDate,
      pendingDates: [for (final row in pendingRows) row.date],
      method: loaded.method,
      accrualMethod: loaded.accrualMethod,
      ratePeriod: ratePpm == null ? null : loaded.ratePeriod,
      ratePpm: ratePpm,
      remainingFeeMinor: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
      equalInstallmentOverrideMinor: overrideMinor,
    );

    final allocationByPeriod = {
      for (var i = 0; i < pendingRows.length; i++)
        pendingRows[i].periodNo: allocations[i],
    };
    final nextDraft = [
      for (final row in loaded.draft)
        if (allocationByPeriod[row.periodNo] case final allocation?)
          row.copyWith(
            principal: allocation.principal,
            interest: allocation.interest,
            fee: allocation.fee,
          )
        else
          row,
    ];

    _setLoaded(
      loaded.copyWith(
        draft: nextDraft,
        manualPatchedPeriodNos: {for (final row in pendingRows) row.periodNo},
      ),
    );
    return const UiActionOutcome.success(null);
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

  Future<SubmitOutcome> submit({
    required String totalPeriodsText,
    required String rateText,
    required String feeText,
    required String overrideInstallmentText,
  }) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidSubmit('合同尚未加载');

    final totalPeriods = int.tryParse(totalPeriodsText.trim());
    if (totalPeriods == null || totalPeriods <= 0) {
      return _invalidSubmit('请输入有效期数');
    }
    if (totalPeriods < loaded.paidCount + 1) {
      return _invalidSubmit('期数必须不小于已还期数 + 1');
    }

    final ratePpm = _parseRatePpm(rateText);
    final feeMinor = _parseOptionalMoney(feeText).minorUnits;
    final overrideMinor =
        loaded.method == InstallmentRepaymentMethod.equalInstallment
            ? _parseOptionalOverride(overrideInstallmentText)
            : null;
    final patches = [
      for (final periodNo in loaded.manualPatchedPeriodNos)
        if (loaded.draft.any((row) => row.periodNo == periodNo))
          () {
            final row = loaded.draft.firstWhere(
              (current) => current.periodNo == periodNo,
            );
            return SchedulePendingPatch(
              periodNo: periodNo,
              expectedPrincipal: row.principal,
              expectedInterest: row.interest,
              expectedFee: row.fee,
              expectedRepaymentDate: row.date,
            );
          }(),
    ];

    _setLoaded(loaded.copyWith(submitting: true));
    try {
      await ref
          .read(installmentServiceProvider)
          .updateContract(
            UpdateContractCommand(
              contractId: contractId,
              totalPeriods: totalPeriods,
              firstRepaymentDate: loaded.firstRepaymentDate,
              lastRepaymentDate: loaded.lastRepaymentDate,
              repaymentMethod: loaded.method,
              interestRatePeriod:
                  ratePpm == null
                      ? const Patch<InterestRatePeriod>.clear()
                      : Patch.set(loaded.ratePeriod),
              interestRatePpm:
                  ratePpm == null
                      ? const Patch<int>.clear()
                      : Patch.set(ratePpm),
              interestAccrualMethod: loaded.accrualMethod,
              totalFeeMinor: feeMinor,
              equalInstallmentOverrideMinor: overrideMinor,
              schedulePatches: patches,
            ),
          );
      final current = _loadedOrNull();
      if (current != null) {
        _setLoaded(current.copyWith(submitting: false));
      }
      _invalidateCreditContractProviders(loaded.contract.liabilityAccountId);
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      final current = _loadedOrNull();
      if (current != null) {
        _setLoaded(current.copyWith(submitting: false));
      }
    }
  }

  void _invalidateCreditContractProviders(String liabilityAccountId) {
    ref
      ..invalidate(installmentContractProvider(contractId))
      ..invalidate(installmentSchedulesProvider(contractId))
      ..invalidate(installmentRepaymentCashflowsProvider(contractId))
      ..invalidate(installmentMetricsProvider(contractId))
      ..invalidate(installmentContractsByAccountProvider(liabilityAccountId));
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

String installmentContractPeriodsText(InstallmentContract contract) {
  return contract.totalPeriods.toString();
}

String installmentContractRateText(InstallmentContract contract) {
  final ratePpm = contract.interestRatePpm;
  if (ratePpm == null || ratePpm <= 0) return '';
  return _trimTrailingZeros((ratePpm / 10000.0).toStringAsFixed(4));
}

String installmentContractFeeText(InstallmentContract contract) {
  if (contract.totalFeeMinor <= 0) return '';
  return Money(minorUnits: contract.totalFeeMinor).major.toString();
}

int? _parseRatePpm(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final percent = double.tryParse(trimmed);
  if (percent == null || percent <= 0) return null;
  return (percent * 10000).round();
}

Money _parseOptionalMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  return Money.tryParse(trimmed) ?? Money.zero();
}

int? _parseOptionalOverride(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final money = Money.tryParse(trimmed);
  if (money == null || money.minorUnits <= 0) return null;
  return money.minorUnits;
}

String _trimTrailingZeros(String text) {
  if (!text.contains('.')) return text;
  var out = text;
  while (out.endsWith('0')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.endsWith('.')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}
