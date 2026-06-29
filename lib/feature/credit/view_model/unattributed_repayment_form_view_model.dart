import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart' as credit;
import '../../../application/credit/credit_query_api.dart' as credit_query;
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/credit_account_query_providers.dart';

part 'unattributed_repayment_form_view_model.g.dart';

@riverpod
class UnattributedRepaymentFormViewModel
    extends _$UnattributedRepaymentFormViewModel {
  @override
  Future<UnattributedRepaymentFormState> build(String accountId) async {
    final overview = await ref.watch(
      creditAccountOverviewProvider(accountId).future,
    );
    final repaymentSourceAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ).future,
    );

    if (overview == null) {
      return UnattributedRepaymentFormState.notFound(
        repaymentSourceAccounts: repaymentSourceAccounts,
      );
    }
    if (overview.buckets.unattributedDebt.minorUnits <= 0) {
      return UnattributedRepaymentFormState.noDebt(
        overview: overview,
        repaymentSourceAccounts: repaymentSourceAccounts,
      );
    }

    final repaymentAccounts = _repaymentAccounts(
      repaymentSourceAccounts,
      accountId,
    );
    return UnattributedRepaymentFormState.loaded(
      overview: overview,
      repaymentSourceAccounts: repaymentSourceAccounts,
      amountText: overview.buckets.unattributedDebt.format(),
      occurredAt: DateTime.now(),
      paidFromAccountId: _selectedId(null, repaymentAccounts),
    );
  }

  void setAmountText(String value) =>
      _update((state) => state.copyWith(amountText: value));

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
    if (current == null || !current.isLoaded || current.overview == null) {
      return _invalidCommand('账单外还款表单尚未加载');
    }
    final amount = _parsePositiveMoney(current.amountText);
    if (amount == null) return _invalidCommand('请输入有效还款金额');
    if (amount.minorUnits >
        current.overview!.buckets.unattributedDebt.minorUnits) {
      return _invalidCommand('还款金额不能超过账单外欠款');
    }

    final paidFromAccountId =
        current.createTransaction
            ? _selectedId(current.paidFromAccountId, current.repaymentAccounts)
            : null;
    if (current.createTransaction && paidFromAccountId == null) {
      return _invalidCommand('请选择还款账户');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      await ref
          .read(repaymentServiceProvider)
          .createUnattributedRepayment(
            credit.CreateUnattributedRepaymentCommand(
              accountId: accountId,
              amount: amount,
              transactionInfo:
                  paidFromAccountId == null
                      ? null
                      : credit.RepaymentTransactionInfo(
                        paidFromAccountId: paidFromAccountId,
                        occurredAt: current.occurredAt,
                      ),
              note: trimToNull(current.noteText),
            ),
          );
      _invalidateAfterSubmit(accountId);
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _invalidateAfterSubmit(String accountId) {
    ref.invalidate(creditAccountOverviewProvider(accountId));
    ref.invalidate(accountsByIdProvider);
    ref.invalidate(transactionListProvider(accountId: accountId));
    ref.invalidate(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ),
    );
  }

  void _update(
    UnattributedRepaymentFormState Function(UnattributedRepaymentFormState)
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

enum UnattributedRepaymentFormLoadStatus { loaded, notFound, noDebt }

class UnattributedRepaymentFormState {
  const UnattributedRepaymentFormState({
    required this.status,
    required this.repaymentSourceAccounts,
    required this.amountText,
    required this.noteText,
    required this.occurredAt,
    required this.createTransaction,
    required this.submitting,
    this.overview,
    this.paidFromAccountId,
  });

  factory UnattributedRepaymentFormState.loaded({
    required credit_query.CreditAccountOverviewReadModel overview,
    required List<Account> repaymentSourceAccounts,
    required DateTime occurredAt,
    String amountText = '',
    String noteText = '',
    String? paidFromAccountId,
  }) {
    return UnattributedRepaymentFormState(
      status: UnattributedRepaymentFormLoadStatus.loaded,
      overview: overview,
      repaymentSourceAccounts: repaymentSourceAccounts,
      amountText: amountText,
      noteText: noteText,
      occurredAt: occurredAt,
      paidFromAccountId: paidFromAccountId,
      createTransaction: true,
      submitting: false,
    );
  }

  factory UnattributedRepaymentFormState.notFound({
    required List<Account> repaymentSourceAccounts,
  }) {
    return UnattributedRepaymentFormState(
      status: UnattributedRepaymentFormLoadStatus.notFound,
      repaymentSourceAccounts: repaymentSourceAccounts,
      amountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      createTransaction: true,
      submitting: false,
    );
  }

  factory UnattributedRepaymentFormState.noDebt({
    required credit_query.CreditAccountOverviewReadModel overview,
    required List<Account> repaymentSourceAccounts,
  }) {
    return UnattributedRepaymentFormState(
      status: UnattributedRepaymentFormLoadStatus.noDebt,
      overview: overview,
      repaymentSourceAccounts: repaymentSourceAccounts,
      amountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      createTransaction: true,
      submitting: false,
    );
  }

  final UnattributedRepaymentFormLoadStatus status;
  final credit_query.CreditAccountOverviewReadModel? overview;
  final List<Account> repaymentSourceAccounts;
  final String amountText;
  final String noteText;
  final DateTime occurredAt;
  final String? paidFromAccountId;
  final bool createTransaction;
  final bool submitting;

  bool get isLoaded => status == UnattributedRepaymentFormLoadStatus.loaded;

  List<Account> get repaymentAccounts {
    return _repaymentAccounts(
      repaymentSourceAccounts,
      overview?.creditAccount.accountId,
    );
  }

  UnattributedRepaymentFormState copyWith({
    String? amountText,
    String? noteText,
    DateTime? occurredAt,
    Object? paidFromAccountId = _sentinel,
    bool? createTransaction,
    bool? submitting,
  }) {
    return UnattributedRepaymentFormState(
      status: status,
      overview: overview,
      repaymentSourceAccounts: repaymentSourceAccounts,
      amountText: amountText ?? this.amountText,
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

List<Account> _repaymentAccounts(List<Account> accounts, String? liabilityId) {
  return accounts.where((account) => account.id != liabilityId).toList();
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return accounts.isEmpty ? null : accounts.first.id;
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}

const Object _sentinel = Object();
