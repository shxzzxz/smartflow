import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import '../provider/credit_account_query_providers.dart';

part 'installment_detail_view_model.g.dart';

final _logger = Logger('feature.credit.installment_detail');

@riverpod
class InstallmentDetailViewModel extends _$InstallmentDetailViewModel {
  @override
  Future<InstallmentDetailState> build(String contractId) async {
    final detail = await ref.watch(
      installmentDetailProvider(contractId).future,
    );
    if (detail == null) return const InstallmentDetailNotFound();

    final repricing = await ref.watch(
      installmentRepricingProvider(contractId).future,
    );
    final needsBorrowingTransaction =
        detail.installment.installmentType == InstallmentType.disbursement &&
        detail.installment.sourceRefId == null;
    final fundAccounts = needsBorrowingTransaction
        ? await ref.watch(
            accountsForSelectionPurposeProvider(
              AccountSelectionPurpose.fund,
            ).future,
          )
        : const <Account>[];
    final activities = await ref.watch(
      installmentActivitiesProvider(contractId).future,
    );
    return InstallmentDetailLoaded(
      installment: detail.installment,
      schedules: detail.schedules,
      repricing: repricing,
      activities: activities,
      fundAccounts: fundAccounts,
    );
  }

  Future<UiActionOutcome<void>> deleteInstallment() async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('分期尚未加载');
    return guardUiAction(_logger, 'Installment delete', () async {
      final command = DeleteInstallmentCommand(
        contractId: loaded.installment.id,
      );
      switch (loaded.installment.installmentType) {
        case InstallmentType.disbursement:
          await ref
              .read(disbursementInstallmentAppServiceProvider)
              .delete(command);
          break;
        case InstallmentType.purchase:
          await ref
              .read(consumptionInstallmentAppServiceProvider)
              .delete(command);
          break;
        case InstallmentType.billConversion:
          await ref
              .read(installmentContractAppServiceProvider)
              .deleteContract(
                DeleteContractCommand(contractId: loaded.installment.id),
              );
          break;
      }
      ref.invalidate(
        installmentsByAccountProvider(loaded.installment.liabilityAccountId),
      );
      ref.invalidate(
        creditAccountOverviewProvider(loaded.installment.liabilityAccountId),
      );
    });
  }

  Future<UiActionOutcome<String>> createBorrowingTransaction({
    required String receiveAccountId,
    required DateTime occurredAt,
  }) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('分期尚未加载');
    if (loaded.installment.installmentType != InstallmentType.disbursement ||
        loaded.installment.sourceRefId != null) {
      return _invalidAction('当前分期无需补建放款交易');
    }
    if (!loaded.fundAccounts.any((account) => account.id == receiveAccountId)) {
      return _invalidAction('请选择有效的到账账户');
    }
    return guardUiAction(_logger, 'Create disbursement transaction', () async {
      final result = await ref
          .read(disbursementInstallmentAppServiceProvider)
          .createBorrowingTransaction(
            CreateDisbursementTransactionCommand(
              contractId: loaded.installment.id,
              receiveAccountId: receiveAccountId,
              occurredAt: occurredAt,
            ),
          );
      _invalidateInstallment(loaded.installment);
      return result.transactionId;
    });
  }

  Future<UiActionOutcome<void>> confirmRepricing() async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('分期尚未加载');
    if (loaded.confirmingRepricing) return _invalidAction('正在确认，请稍候');
    _setConfirmingRepricing(true);
    try {
      return await guardUiAction(_logger, 'Confirm loan repricing', () async {
        await ref
            .read(installmentRepricingAppServiceProvider)
            .confirm(
              contractId,
              loaded.repricing?.unconfirmedRecordIds.toSet() ?? const {},
            );
        if (!ref.mounted) return;
        ref
          ..invalidate(installmentProvider(contractId))
          ..invalidate(installmentRepricingProvider(contractId));
      });
    } finally {
      if (ref.mounted) _setConfirmingRepricing(false);
    }
  }

  void _setConfirmingRepricing(bool value) {
    final loaded = _loadedOrNull();
    if (loaded == null) return;
    state = AsyncData(
      InstallmentDetailLoaded(
        installment: loaded.installment,
        schedules: loaded.schedules,
        repricing: loaded.repricing,
        activities: loaded.activities,
        fundAccounts: loaded.fundAccounts,
        confirmingRepricing: value,
      ),
    );
  }

  Future<UiActionOutcome<void>> revertRepayment(String repaymentId) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('分期尚未加载');
    ContractRepaymentActivity? repayment;
    for (final activity
        in loaded.activities.whereType<ContractRepaymentActivity>()) {
      if (activity.id == repaymentId) {
        repayment = activity;
        break;
      }
    }
    if (repayment == null) return _invalidAction('还款记录不属于当前分期');
    final command = DeleteCreditRepaymentCommand(repaymentId: repaymentId);
    final delete = switch (repayment.repaymentType) {
      RepaymentType.bill || RepaymentType.installment =>
        () =>
            ref.read(billRepaymentAppServiceProvider).deleteRepayment(command),
      RepaymentType.prepayment =>
        () => ref
            .read(installmentPrepaymentAppServiceProvider)
            .deleteRepayment(command),
      RepaymentType.unattributed => null,
    };
    if (delete == null) return _invalidAction('账户还款不属于当前分期');
    return guardUiAction(_logger, 'Contract repayment revert', () async {
      await delete();
      _invalidateInstallment(loaded.installment);
    });
  }

  Future<UiActionOutcome<void>> skipSchedule(String scheduleId) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('分期尚未加载');
    return guardUiAction(_logger, 'Schedule skip', () async {
      await ref
          .read(installmentPlanAppServiceProvider)
          .skipSchedule(
            SkipInstallmentScheduleCommand(
              contractId: loaded.installment.id,
              scheduleId: scheduleId,
            ),
          );
      _invalidateInstallment(loaded.installment);
    });
  }

  Future<UiActionOutcome<void>> restoreSchedule(String scheduleId) async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('分期尚未加载');
    return guardUiAction(_logger, 'Schedule restore', () async {
      await ref
          .read(installmentPlanAppServiceProvider)
          .restoreSchedule(
            RestoreInstallmentScheduleCommand(
              contractId: loaded.installment.id,
              scheduleId: scheduleId,
            ),
          );
      _invalidateInstallment(loaded.installment);
    });
  }

  Future<UiActionOutcome<ContractStatusValidationResult>>
  validateContractStatuses() async {
    final loaded = _loadedOrNull();
    if (loaded == null) {
      return UiActionOutcome.failure(
        UiError(
          code: CreditErrorCode.contractInvalidCommand.code,
          message: '分期尚未加载',
        ),
      );
    }
    return guardUiAction(_logger, 'Contract status validation', () async {
      final result = await ref
          .read(installmentStatusRepairAppServiceProvider)
          .validateAndRepair(loaded.installment.id);
      _invalidateInstallment(loaded.installment);
      return result;
    });
  }

  InstallmentDetailLoaded? _loadedOrNull() {
    final current = state.asData?.value;
    return current is InstallmentDetailLoaded ? current : null;
  }

  void _invalidateInstallment(InstallmentDTO installment) {
    ref
      ..invalidate(installmentProvider(installment.id))
      ..invalidate(installmentDetailProvider(installment.id))
      ..invalidate(installmentRepricingProvider(installment.id))
      ..invalidate(installmentActivitiesProvider(installment.id))
      ..invalidate(installmentMetricsProvider(installment.id))
      ..invalidate(
        installmentsByAccountProvider(installment.liabilityAccountId),
      )
      ..invalidate(
        creditAccountOverviewProvider(installment.liabilityAccountId),
      );
  }

  UiActionOutcome<T> _invalidAction<T>(String message) {
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
    required this.installment,
    required this.schedules,
    required this.repricing,
    required this.activities,
    this.fundAccounts = const [],
    this.confirmingRepricing = false,
  });

  final InstallmentDTO installment;
  final List<InstallmentScheduleDTO> schedules;
  final InstallmentRepricingDTO? repricing;
  final List<ContractActivity> activities;
  final List<Account> fundAccounts;
  final bool confirmingRepricing;

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
}

enum InstallmentScheduleAction { skip, restore }

class InstallmentScheduleItemState {
  const InstallmentScheduleItemState({
    required this.schedule,
    required this.action,
  });

  final InstallmentScheduleDTO schedule;
  final InstallmentScheduleAction? action;
}
