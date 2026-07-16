import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import '../provider/credit_account_query_providers.dart';

part 'installment_detail_view_model.g.dart';

@riverpod
class InstallmentDetailViewModel extends _$InstallmentDetailViewModel {
  @override
  Future<InstallmentDetailState> build(String contractId) async {
    final contract = await ref.watch(
      installmentContractProvider(contractId).future,
    );
    if (contract == null) return const InstallmentDetailNotFound();

    final schedules = await ref.watch(
      installmentSchedulesProvider(contractId).future,
    );
    final repayments = await ref.watch(
      installmentRepaymentsProvider(contractId).future,
    );
    return InstallmentDetailLoaded(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
    );
  }

  Future<UiActionOutcome<void>> deleteContract() async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('合同尚未加载');
    try {
      await ref
          .read(installmentAppServiceProvider)
          .deleteContract(
            DeleteContractCommand(contractId: loaded.contract.id),
          );
      ref.invalidate(
        installmentContractsByAccountProvider(
          loaded.contract.liabilityAccountId,
        ),
      );
      ref.invalidate(
        creditAccountOverviewProvider(loaded.contract.liabilityAccountId),
      );
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }

  Future<UiActionOutcome<void>> revertRepayment(String repaymentId) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('合同尚未加载');
    try {
      await ref
          .read(repaymentAppServiceProvider)
          .deleteRepayment(
            DeleteCreditRepaymentCommand(repaymentId: repaymentId),
          );
      _invalidateContract(loaded.contract);
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }

  Future<UiActionOutcome<void>> skipSchedule(String scheduleId) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('合同尚未加载');
    try {
      await ref
          .read(installmentAppServiceProvider)
          .skipSchedule(
            SkipInstallmentScheduleCommand(
              contractId: loaded.contract.id,
              scheduleId: scheduleId,
            ),
          );
      _invalidateContract(loaded.contract);
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }

  Future<UiActionOutcome<void>> restoreSchedule(String scheduleId) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('合同尚未加载');
    try {
      await ref
          .read(installmentAppServiceProvider)
          .restoreSchedule(
            RestoreInstallmentScheduleCommand(
              contractId: loaded.contract.id,
              scheduleId: scheduleId,
            ),
          );
      _invalidateContract(loaded.contract);
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }

  Future<UiActionOutcome<ContractStatusValidationResult>>
  validateContractStatuses() async {
    final loaded = _loadedOrNull();
    if (loaded == null) {
      return UiActionOutcome.failure(
        UiError(
          code: CreditErrorCode.contractInvalidCommand.code,
          message: '合同尚未加载',
        ),
      );
    }
    try {
      final result = await ref
          .read(installmentAppServiceProvider)
          .validateContractStatuses(
            ValidateContractStatusesCommand(contractId: loaded.contract.id),
          );
      _invalidateContract(loaded.contract);
      return UiActionOutcome.success(result);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }

  InstallmentDetailLoaded? _loadedOrNull() {
    final current = state.asData?.value;
    return current is InstallmentDetailLoaded ? current : null;
  }

  void _invalidateContract(InstallmentContractReadModel contract) {
    ref
      ..invalidate(installmentContractProvider(contract.id))
      ..invalidate(installmentSchedulesProvider(contract.id))
      ..invalidate(installmentRepaymentsProvider(contract.id))
      ..invalidate(installmentMetricsProvider(contract.id))
      ..invalidate(
        installmentContractsByAccountProvider(contract.liabilityAccountId),
      )
      ..invalidate(creditAccountOverviewProvider(contract.liabilityAccountId));
  }

  UiActionOutcome<void> _invalidAction(String message) {
    return UiActionOutcome.failure(
      UiError(
        code: CreditErrorCode.contractInvalidCommand.code,
        message: message,
      ),
    );
  }
}

sealed class InstallmentDetailState {
  const InstallmentDetailState();
}

class InstallmentDetailNotFound extends InstallmentDetailState {
  const InstallmentDetailNotFound();
}

class InstallmentDetailLoaded extends InstallmentDetailState {
  const InstallmentDetailLoaded({
    required this.contract,
    required this.schedules,
    required this.repayments,
  });

  final InstallmentContractReadModel contract;
  final List<InstallmentScheduleReadModel> schedules;
  final List<ContractRepayment> repayments;

  List<InstallmentScheduleItemState> get scheduleItems => [
    for (final schedule in schedules)
      InstallmentScheduleItemState(
        schedule: schedule,
        action: switch (schedule.status) {
          InstallmentScheduleStatus.pending => InstallmentScheduleAction.skip,
          InstallmentScheduleStatus.skipped =>
            InstallmentScheduleAction.restore,
          InstallmentScheduleStatus.partiallyPaid ||
          InstallmentScheduleStatus.paid => null,
        },
      ),
  ];

  int get remainingPrincipalMinor {
    final remaining = schedules
        .where(
          (s) =>
              s.status == InstallmentScheduleStatus.pending ||
              s.status == InstallmentScheduleStatus.partiallyPaid,
        )
        .fold<int>(0, (sum, schedule) {
          return sum + schedule.expectedPrincipal.minorUnits;
        });
    return remaining < 0 ? 0 : remaining;
  }

  int get paidInterestMinor {
    return repayments.fold<int>(0, (sum, repayment) {
      return sum + repayment.interest.minorUnits;
    });
  }

  int get paidFeeMinor {
    return repayments.fold<int>(0, (sum, repayment) {
      return sum + repayment.fee.minorUnits;
    });
  }
}

enum InstallmentScheduleAction { skip, restore }

class InstallmentScheduleItemState {
  const InstallmentScheduleItemState({
    required this.schedule,
    required this.action,
  });

  final InstallmentScheduleReadModel schedule;
  final InstallmentScheduleAction? action;
}
