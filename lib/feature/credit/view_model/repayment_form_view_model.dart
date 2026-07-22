import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart' as credit;
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import '../provider/credit_account_query_providers.dart';

part 'repayment_form_view_model.g.dart';

@riverpod
class RepaymentFormViewModel extends _$RepaymentFormViewModel {
  @override
  Future<RepaymentFormState> build(RepaymentFormArgs args) async {
    final liabilityAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentTarget,
      ).future,
    );
    final repaymentSourceAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ).future,
    );

    final editTransactionId = args.editTransactionId;
    if (editTransactionId == null) {
      final liabilityAccountId = _selectedId(
        args.liabilityAccountId,
        liabilityAccounts,
      );
      final repaymentAccounts = _repaymentAccounts(
        repaymentSourceAccounts,
        liabilityAccountId,
      );
      return RepaymentFormState.loaded(
        liabilityAccounts: liabilityAccounts,
        repaymentSourceAccounts: repaymentSourceAccounts,
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: _selectedId(null, repaymentAccounts),
        occurredAt: DateTime.now(),
      );
    }

    final editResult = await ref
        .read(repaymentAppServiceProvider)
        .loadLiabilityRepaymentEditView(editTransactionId);
    switch (editResult.status) {
      case credit.LiabilityRepaymentEditViewLoadStatus.notFound:
        return RepaymentFormState.notFound(
          liabilityAccounts: liabilityAccounts,
          repaymentSourceAccounts: repaymentSourceAccounts,
        );
      case credit.LiabilityRepaymentEditViewLoadStatus.notEditable:
        return RepaymentFormState.notEditable(
          liabilityAccounts: liabilityAccounts,
          repaymentSourceAccounts: repaymentSourceAccounts,
        );
      case credit.LiabilityRepaymentEditViewLoadStatus.loaded:
        break;
    }
    final view = editResult.view!;
    return RepaymentFormState.loaded(
      liabilityAccounts: liabilityAccounts,
      repaymentSourceAccounts: repaymentSourceAccounts,
      principalText: view.amount.principal.format(),
      interestText: _positiveText(view.amount.interest),
      feeText: _positiveText(view.amount.fee),
      discountText: _positiveText(view.amount.discount),
      noteText: view.note ?? '',
      liabilityAccountId: view.liabilityAccountId,
      paidFromAccountId: view.paidFromAccountId,
      occurredAt: view.occurredAt,
    );
  }

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setLiabilityAccountId(String? value) => _update((current) {
    final repaymentAccounts = _repaymentAccounts(
      current.repaymentSourceAccounts,
      value,
    );
    return current.copyWith(
      liabilityAccountId: value,
      paidFromAccountId: _selectedId(
        current.paidFromAccountId,
        repaymentAccounts,
      ),
    );
  });

  void setPaidFromAccountId(String? value) =>
      _update((state) => state.copyWith(paidFromAccountId: value));

  Future<SubmitOutcome> submit({
    required String principalText,
    required String interestText,
    required String feeText,
    required String discountText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('还款表单尚未加载');
    }
    final principal = _parseNonNegativeMoney(principalText);
    if (principal == null) return _invalidCommand('请输入有效本金');
    final interest = _parseOptionalNonNegativeMoney(interestText);
    if (interest == null) return _invalidCommand('请输入有效利息');
    final fee = _parseOptionalNonNegativeMoney(feeText);
    if (fee == null) return _invalidCommand('请输入有效手续费');
    final discount = _parseOptionalNonNegativeMoney(discountText);
    if (discount == null) return _invalidCommand('请输入有效优惠');
    final cashPaid = principal + interest + fee - discount;
    if (cashPaid.minorUnits <= 0) {
      return _invalidCommand('实付金额必须大于 0');
    }
    final liabilityAccountId = _selectedId(
      current.liabilityAccountId,
      current.liabilityAccounts,
    );
    if (liabilityAccountId == null) return _invalidCommand('请选择债务账户');
    final repaymentAccounts = _repaymentAccounts(
      current.repaymentSourceAccounts,
      liabilityAccountId,
    );
    final paidFromAccountId = _selectedId(
      current.paidFromAccountId,
      repaymentAccounts,
    );
    if (paidFromAccountId == null) return _invalidCommand('请选择还款账户');

    _update((state) => state.copyWith(submitting: true));
    try {
      final service = ref.read(repaymentAppServiceProvider);
      final editTransactionId = args.editTransactionId;
      final note = trimToNull(noteText);
      final amount = credit.RepaymentAmountDto(
        principal: principal,
        interest: interest,
        fee: fee,
        discount: discount,
      );
      final result =
          editTransactionId == null
              ? await service.createLiabilityRepayment(
                credit.CreateLiabilityRepaymentCommand(
                  liabilityAccountId: liabilityAccountId,
                  paidFromAccountId: paidFromAccountId,
                  amount: amount,
                  occurredAt: current.occurredAt,
                  note: note,
                ),
              )
              : await service.editLiabilityRepayment(
                credit.EditLiabilityRepaymentCommand(
                  transactionId: editTransactionId,
                  liabilityAccountId: liabilityAccountId,
                  paidFromAccountId: paidFromAccountId,
                  amount: amount,
                  occurredAt: current.occurredAt,
                  note: note,
                ),
              );
      _invalidateAfterSubmit(
        liabilityAccountId: liabilityAccountId,
        transactionId: editTransactionId,
        newTransactionId: result.transactionId,
      );
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _invalidateAfterSubmit({
    required String liabilityAccountId,
    required String? transactionId,
    required String newTransactionId,
  }) {
    ref.invalidate(accountsByIdProvider);
    ref.invalidate(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentTarget,
      ),
    );
    ref.invalidate(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ),
    );
    ref.invalidate(installmentContractsByAccountProvider(liabilityAccountId));
    ref.invalidate(creditAccountOverviewProvider(liabilityAccountId));
    if (transactionId != null) {
      ref.invalidate(transactionDetailProvider(transactionId));
    }
    ref.invalidate(transactionDetailProvider(newTransactionId));
  }

  void _update(RepaymentFormState Function(RepaymentFormState) update) {
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

class RepaymentFormArgs {
  const RepaymentFormArgs({this.liabilityAccountId, this.editTransactionId});

  final String? liabilityAccountId;
  final String? editTransactionId;

  @override
  bool operator ==(Object other) {
    return other is RepaymentFormArgs &&
        other.liabilityAccountId == liabilityAccountId &&
        other.editTransactionId == editTransactionId;
  }

  @override
  int get hashCode => Object.hash(liabilityAccountId, editTransactionId);
}

enum RepaymentFormLoadStatus { loaded, notFound, notEditable }

class RepaymentFormState {
  const RepaymentFormState({
    required this.status,
    required this.liabilityAccounts,
    required this.repaymentSourceAccounts,
    required this.principalText,
    required this.interestText,
    required this.feeText,
    required this.discountText,
    required this.noteText,
    required this.occurredAt,
    required this.submitting,
    this.liabilityAccountId,
    this.paidFromAccountId,
  });

  factory RepaymentFormState.loaded({
    required List<Account> liabilityAccounts,
    required List<Account> repaymentSourceAccounts,
    required DateTime occurredAt,
    String principalText = '',
    String interestText = '',
    String feeText = '',
    String discountText = '',
    String noteText = '',
    String? liabilityAccountId,
    String? paidFromAccountId,
  }) {
    return RepaymentFormState(
      status: RepaymentFormLoadStatus.loaded,
      liabilityAccounts: liabilityAccounts,
      repaymentSourceAccounts: repaymentSourceAccounts,
      principalText: principalText,
      interestText: interestText,
      feeText: feeText,
      discountText: discountText,
      noteText: noteText,
      occurredAt: occurredAt,
      submitting: false,
      liabilityAccountId: liabilityAccountId,
      paidFromAccountId: paidFromAccountId,
    );
  }

  factory RepaymentFormState.notFound({
    required List<Account> liabilityAccounts,
    required List<Account> repaymentSourceAccounts,
  }) {
    return RepaymentFormState.loaded(
      liabilityAccounts: liabilityAccounts,
      repaymentSourceAccounts: repaymentSourceAccounts,
      occurredAt: DateTime.now(),
    ).copyWith(status: RepaymentFormLoadStatus.notFound);
  }

  factory RepaymentFormState.notEditable({
    required List<Account> liabilityAccounts,
    required List<Account> repaymentSourceAccounts,
  }) {
    return RepaymentFormState.loaded(
      liabilityAccounts: liabilityAccounts,
      repaymentSourceAccounts: repaymentSourceAccounts,
      occurredAt: DateTime.now(),
    ).copyWith(status: RepaymentFormLoadStatus.notEditable);
  }

  final RepaymentFormLoadStatus status;
  final List<Account> liabilityAccounts;
  final List<Account> repaymentSourceAccounts;
  final String principalText;
  final String interestText;
  final String feeText;
  final String discountText;
  final String noteText;
  final DateTime occurredAt;
  final String? liabilityAccountId;
  final String? paidFromAccountId;
  final bool submitting;

  bool get isLoaded => status == RepaymentFormLoadStatus.loaded;

  List<Account> get repaymentAccounts {
    return _repaymentAccounts(repaymentSourceAccounts, liabilityAccountId);
  }

  RepaymentFormState copyWith({
    RepaymentFormLoadStatus? status,
    String? principalText,
    String? interestText,
    String? feeText,
    String? discountText,
    String? noteText,
    DateTime? occurredAt,
    Object? liabilityAccountId = _sentinel,
    Object? paidFromAccountId = _sentinel,
    bool? submitting,
  }) {
    return RepaymentFormState(
      status: status ?? this.status,
      liabilityAccounts: liabilityAccounts,
      repaymentSourceAccounts: repaymentSourceAccounts,
      principalText: principalText ?? this.principalText,
      interestText: interestText ?? this.interestText,
      feeText: feeText ?? this.feeText,
      discountText: discountText ?? this.discountText,
      noteText: noteText ?? this.noteText,
      occurredAt: occurredAt ?? this.occurredAt,
      liabilityAccountId:
          liabilityAccountId == _sentinel
              ? this.liabilityAccountId
              : liabilityAccountId as String?,
      paidFromAccountId:
          paidFromAccountId == _sentinel
              ? this.paidFromAccountId
              : paidFromAccountId as String?,
      submitting: submitting ?? this.submitting,
    );
  }
}

List<Account> _repaymentAccounts(List<Account> accounts, String? liabilityId) {
  return accounts.where((account) => account.id != liabilityId).toList();
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return accounts.isEmpty ? null : accounts.first.id;
}

Money? _parseNonNegativeMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits >= 0 ? money : null;
}

Money? _parseOptionalNonNegativeMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  final money = Money.tryParse(trimmed);
  return money != null && money.minorUnits >= 0 ? money : null;
}

String _positiveText(Money value) {
  return value.minorUnits > 0 ? value.format() : '';
}

const Object _sentinel = Object();
