import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import 'installment_repayment_mode.dart';

part 'installment_repayment_form_view_model.g.dart';

@riverpod
class InstallmentRepaymentFormViewModel
    extends _$InstallmentRepaymentFormViewModel {
  @override
  Future<InstallmentRepaymentFormState> build(
    InstallmentRepaymentFormArgs args,
  ) async {
    final contract = await ref.watch(
      installmentContractProvider(args.contractId).future,
    );
    final schedules = await ref.watch(
      installmentSchedulesProvider(args.contractId).future,
    );
    final accounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ).future,
    );

    if (contract == null) {
      return InstallmentRepaymentFormState.notFound(
        schedules: schedules,
        accounts: accounts,
      );
    }

    final schedule =
        args.mode == InstallmentRepaymentMode.scheduled
            ? _findSchedule(schedules, args.scheduleId)
            : null;
    if (args.mode == InstallmentRepaymentMode.scheduled && schedule == null) {
      return InstallmentRepaymentFormState.scheduleNotFound(
        contract: contract,
        schedules: schedules,
        accounts: accounts,
      );
    }

    final paidFromAccountId =
        contract.disbursementAccountId != null &&
                accounts.any((a) => a.id == contract.disbursementAccountId)
            ? contract.disbursementAccountId
            : (accounts.isEmpty ? null : accounts.first.id);

    return InstallmentRepaymentFormState.loaded(
      contract: contract,
      schedules: schedules,
      accounts: accounts,
      schedule: schedule,
      principalText: _defaultPrincipalText(
        contract,
        schedules,
        schedule,
        args.mode,
      ),
      interestText:
          schedule != null && schedule.expectedInterest.minorUnits > 0
              ? schedule.expectedInterest.format()
              : '',
      feeText:
          schedule != null && schedule.expectedFee.minorUnits > 0
              ? schedule.expectedFee.format()
              : '',
      occurredAt: DateTime.now(),
      paidFromAccountId: paidFromAccountId,
    );
  }

  void setPrincipalText(String value) =>
      _update((state) => state.copyWith(principalText: value));

  void setInterestText(String value) =>
      _update((state) => state.copyWith(interestText: value));

  void setFeeText(String value) =>
      _update((state) => state.copyWith(feeText: value));

  void setDiscountText(String value) =>
      _update((state) => state.copyWith(discountText: value));

  void setNoteText(String value) =>
      _update((state) => state.copyWith(noteText: value));

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setPaidFromAccountId(String? value) =>
      _update((state) => state.copyWith(paidFromAccountId: value));

  void setCreateTransaction(bool value) =>
      _update((state) => state.copyWith(createTransaction: value));

  Future<SubmitOutcome> submit() async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded || current.contract == null) {
      return _invalidCommand('分期还款表单尚未加载');
    }
    final principal = _parsePositiveMoney(current.principalText);
    if (principal == null) return _invalidCommand('请输入有效本金');
    final paidFromAccountId =
        current.createTransaction
            ? _selectedId(current.paidFromAccountId, current.accounts)
            : null;
    if (current.createTransaction && paidFromAccountId == null) {
      return _invalidCommand('请选择还款账户');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      final service = ref.read(repaymentAppServiceProvider);
      switch (args.mode) {
        case InstallmentRepaymentMode.scheduled:
          return _invalidCommand('期次还款请从账单还款处理');
        case InstallmentRepaymentMode.prepayment:
          await service.createContractPrepaymentRepayment(
            CreateContractPrepaymentRepaymentCommand(
              contractId: current.contract!.id,
              principal: principal,
              interest: _parseOptionalMoney(current.interestText),
              fee: _parseOptionalMoney(current.feeText),
              transactionInfo:
                  paidFromAccountId == null
                      ? null
                      : RepaymentTransactionInfo(
                        paidFromAccountId: paidFromAccountId,
                        occurredAt: current.occurredAt,
                      ),
              note: trimToNull(current.noteText),
            ),
          );
      }
      _invalidate(current.contract!);
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _invalidate(InstallmentContract contract) {
    ref.invalidate(installmentContractProvider(contract.id));
    ref.invalidate(installmentSchedulesProvider(contract.id));
    ref.invalidate(installmentRepaymentCashflowsProvider(contract.id));
    ref.invalidate(
      installmentContractsByAccountProvider(contract.liabilityAccountId),
    );
    ref.invalidate(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ),
    );
  }

  void _update(
    InstallmentRepaymentFormState Function(InstallmentRepaymentFormState)
    update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }

  SubmitOutcome _invalidCommand(String message) {
    return SubmitOutcome.failure(
      UiError(
        code: LedgerErrorCode.transactionInvalidCommand.code,
        message: message,
      ),
    );
  }
}

class InstallmentRepaymentFormArgs {
  const InstallmentRepaymentFormArgs({
    required this.contractId,
    required this.mode,
    this.scheduleId,
  });

  final String contractId;
  final InstallmentRepaymentMode mode;
  final String? scheduleId;

  @override
  bool operator ==(Object other) {
    return other is InstallmentRepaymentFormArgs &&
        other.contractId == contractId &&
        other.mode == mode &&
        other.scheduleId == scheduleId;
  }

  @override
  int get hashCode => Object.hash(contractId, mode, scheduleId);
}

enum InstallmentRepaymentFormStatus { loaded, notFound, scheduleNotFound }

class InstallmentRepaymentFormState {
  const InstallmentRepaymentFormState({
    required this.status,
    required this.schedules,
    required this.accounts,
    required this.principalText,
    required this.interestText,
    required this.feeText,
    required this.discountText,
    required this.noteText,
    required this.occurredAt,
    required this.createTransaction,
    required this.submitting,
    this.contract,
    this.schedule,
    this.paidFromAccountId,
  });

  factory InstallmentRepaymentFormState.loaded({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required List<Account> accounts,
    required DateTime occurredAt,
    InstallmentSchedule? schedule,
    String principalText = '',
    String interestText = '',
    String feeText = '',
    String discountText = '',
    String noteText = '',
    String? paidFromAccountId,
  }) {
    return InstallmentRepaymentFormState(
      status: InstallmentRepaymentFormStatus.loaded,
      contract: contract,
      schedule: schedule,
      schedules: schedules,
      accounts: accounts,
      principalText: principalText,
      interestText: interestText,
      feeText: feeText,
      discountText: discountText,
      noteText: noteText,
      occurredAt: occurredAt,
      paidFromAccountId: paidFromAccountId,
      createTransaction: true,
      submitting: false,
    );
  }

  factory InstallmentRepaymentFormState.notFound({
    required List<InstallmentSchedule> schedules,
    required List<Account> accounts,
  }) {
    return InstallmentRepaymentFormState(
      status: InstallmentRepaymentFormStatus.notFound,
      schedules: schedules,
      accounts: accounts,
      principalText: '',
      interestText: '',
      feeText: '',
      discountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      createTransaction: true,
      submitting: false,
    );
  }

  factory InstallmentRepaymentFormState.scheduleNotFound({
    required InstallmentContract contract,
    required List<InstallmentSchedule> schedules,
    required List<Account> accounts,
  }) {
    return InstallmentRepaymentFormState.notFound(
      schedules: schedules,
      accounts: accounts,
    ).copyWith(
      status: InstallmentRepaymentFormStatus.scheduleNotFound,
      contract: contract,
    );
  }

  final InstallmentRepaymentFormStatus status;
  final InstallmentContract? contract;
  final InstallmentSchedule? schedule;
  final List<InstallmentSchedule> schedules;
  final List<Account> accounts;
  final String principalText;
  final String interestText;
  final String feeText;
  final String discountText;
  final String noteText;
  final DateTime occurredAt;
  final String? paidFromAccountId;
  final bool createTransaction;
  final bool submitting;

  bool get isLoaded => status == InstallmentRepaymentFormStatus.loaded;

  InstallmentRepaymentFormState copyWith({
    InstallmentRepaymentFormStatus? status,
    Object? contract = _sentinel,
    String? principalText,
    String? interestText,
    String? feeText,
    String? discountText,
    String? noteText,
    DateTime? occurredAt,
    Object? paidFromAccountId = _sentinel,
    bool? createTransaction,
    bool? submitting,
  }) {
    return InstallmentRepaymentFormState(
      status: status ?? this.status,
      contract:
          contract == _sentinel
              ? this.contract
              : contract as InstallmentContract?,
      schedule: schedule,
      schedules: schedules,
      accounts: accounts,
      principalText: principalText ?? this.principalText,
      interestText: interestText ?? this.interestText,
      feeText: feeText ?? this.feeText,
      discountText: discountText ?? this.discountText,
      noteText: noteText ?? this.noteText,
      occurredAt: occurredAt ?? this.occurredAt,
      paidFromAccountId:
          paidFromAccountId == _sentinel
              ? this.paidFromAccountId
              : paidFromAccountId as String?,
      createTransaction: createTransaction ?? this.createTransaction,
      submitting: submitting ?? this.submitting,
    );
  }
}

String _defaultPrincipalText(
  InstallmentContract contract,
  List<InstallmentSchedule> schedules,
  InstallmentSchedule? schedule,
  InstallmentRepaymentMode mode,
) {
  if (schedule != null) return schedule.expectedPrincipal.format();
  if (mode != InstallmentRepaymentMode.prepayment) return '';
  final paidPrincipalSum = schedules
      .where((s) => s.status == InstallmentScheduleStatus.paid)
      .fold<int>(0, (sum, s) => sum + s.expectedPrincipal.minorUnits);
  final remaining = contract.principal.minorUnits - paidPrincipalSum;
  return Money(minorUnits: remaining < 0 ? 0 : remaining).format();
}

InstallmentSchedule? _findSchedule(
  List<InstallmentSchedule> schedules,
  String? id,
) {
  if (id == null) return null;
  for (final schedule in schedules) {
    if (schedule.id == id) return schedule;
  }
  return null;
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return accounts.isEmpty ? null : accounts.first.id;
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}

Money? _parseOptionalMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final money = Money.tryParse(trimmed);
  return money != null && money.minorUnits > 0 ? money : null;
}

const Object _sentinel = Object();
