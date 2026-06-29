import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';

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
    final cashflows = await ref.watch(
      installmentRepaymentCashflowsProvider(contractId).future,
    );
    return InstallmentDetailLoaded(
      contract: contract,
      schedules: schedules,
      cashflows: cashflows,
    );
  }

  Future<UiActionOutcome<void>> deleteContract() async {
    final loaded = _loadedOrNull();
    if (loaded == null) return _invalidAction('合同尚未加载');
    try {
      await ref
          .read(installmentServiceProvider)
          .deleteContract(
            DeleteContractCommand(contractId: loaded.contract.id),
          );
      ref.invalidate(
        installmentContractsByAccountProvider(
          loaded.contract.liabilityAccountId,
        ),
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
          .read(repaymentServiceProvider)
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

  InstallmentDetailLoaded? _loadedOrNull() {
    final current = state.asData?.value;
    return current is InstallmentDetailLoaded ? current : null;
  }

  void _invalidateContract(InstallmentContract contract) {
    ref
      ..invalidate(installmentContractProvider(contract.id))
      ..invalidate(installmentSchedulesProvider(contract.id))
      ..invalidate(installmentRepaymentCashflowsProvider(contract.id))
      ..invalidate(installmentMetricsProvider(contract.id))
      ..invalidate(
        installmentContractsByAccountProvider(contract.liabilityAccountId),
      );
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
    required this.cashflows,
  });

  final InstallmentContract contract;
  final List<InstallmentSchedule> schedules;
  final List<RepaymentCashflow> cashflows;

  int get remainingPrincipalMinor {
    final remaining = schedules
        .where((s) => s.status == InstallmentScheduleStatus.pending)
        .fold<int>(0, (sum, schedule) {
          return sum + schedule.expectedPrincipal.minorUnits;
        });
    return remaining < 0 ? 0 : remaining;
  }

  int get paidInterestMinor {
    return cashflows.fold<int>(0, (sum, cashflow) {
      return sum + cashflow.interest.minorUnits;
    });
  }

  int get paidFeeMinor {
    return cashflows.fold<int>(0, (sum, cashflow) {
      return sum + cashflow.fee.minorUnits;
    });
  }
}
