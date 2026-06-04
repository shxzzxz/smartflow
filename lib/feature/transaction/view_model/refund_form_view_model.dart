import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'refund_form_view_model.g.dart';

@riverpod
class RefundFormViewModel extends _$RefundFormViewModel {
  @override
  Future<RefundFormState> build(String parentTransactionId) async {
    final accounts = await ref.watch(
      accountsForUsageProvider(AccountUsage.settlement).future,
    );
    final accountsById = await ref.watch(accountsByIdProvider.future);
    final detail = await ref.watch(
      transactionDetailProvider(parentTransactionId).future,
    );
    if (detail == null) {
      return RefundFormState.notFound(accounts: accounts);
    }
    final defaultAccountId = effectiveRefundToAccountId(
      selectedId: null,
      parentSettlementAccountId: parentSettlementAccountIdForRefund(
        detail,
        accountsById,
      ),
      accounts: accounts,
    );
    final refunded = detail.refundedTotal ?? Money.zero();
    return RefundFormState.loaded(
      accounts: accounts,
      remaining: detail.transaction.primaryAmount - refunded,
      refundToAccountId: defaultAccountId,
      occurredAt: DateTime.now(),
    );
  }

  void setAmountText(String value) =>
      _update((state) => state.copyWith(amountText: value));

  void setNoteText(String value) =>
      _update((state) => state.copyWith(noteText: value));

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setRefundToAccountId(String? value) =>
      _update((state) => state.copyWith(refundToAccountId: value));

  Future<SubmitOutcome> submit() async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('退款表单尚未加载');
    }
    final amount = _parsePositiveMoney(current.amountText);
    if (amount == null) return _invalidCommand('请输入有效退款金额');
    final refundToAccountId = _selectedId(
      current.refundToAccountId,
      current.accounts,
    );
    if (refundToAccountId == null) return _invalidCommand('请选择退款账户');

    _update((state) => state.copyWith(submitting: true));
    try {
      await ref
          .read(transactionPostingAppServiceProvider)
          .createRefund(
            CreateRefundCommand(
              amount: amount,
              parentTransactionId: parentTransactionId,
              refundToAccountId: refundToAccountId,
              occurredAt: current.occurredAt,
              note: trimToNull(current.noteText),
            ),
          );
      ref.invalidate(transactionDetailProvider(parentTransactionId));
      ref.invalidate(accountsByIdProvider);
      ref.invalidate(accountsForUsageProvider(AccountUsage.settlement));
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _update(RefundFormState Function(RefundFormState) update) {
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

enum RefundFormStatus { loaded, notFound }

class RefundFormState {
  const RefundFormState({
    required this.status,
    required this.accounts,
    required this.amountText,
    required this.noteText,
    required this.occurredAt,
    required this.submitting,
    this.remaining,
    this.refundToAccountId,
  });

  factory RefundFormState.loaded({
    required List<Account> accounts,
    required Money remaining,
    required DateTime occurredAt,
    String? refundToAccountId,
  }) {
    return RefundFormState(
      status: RefundFormStatus.loaded,
      accounts: accounts,
      remaining: remaining,
      amountText: '',
      noteText: '',
      occurredAt: occurredAt,
      refundToAccountId: refundToAccountId,
      submitting: false,
    );
  }

  factory RefundFormState.notFound({required List<Account> accounts}) {
    return RefundFormState(
      status: RefundFormStatus.notFound,
      accounts: accounts,
      amountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      submitting: false,
    );
  }

  final RefundFormStatus status;
  final List<Account> accounts;
  final Money? remaining;
  final String amountText;
  final String noteText;
  final DateTime occurredAt;
  final String? refundToAccountId;
  final bool submitting;

  bool get isLoaded => status == RefundFormStatus.loaded;

  RefundFormState copyWith({
    String? amountText,
    String? noteText,
    DateTime? occurredAt,
    Object? refundToAccountId = _sentinel,
    bool? submitting,
  }) {
    return RefundFormState(
      status: status,
      accounts: accounts,
      remaining: remaining,
      amountText: amountText ?? this.amountText,
      noteText: noteText ?? this.noteText,
      occurredAt: occurredAt ?? this.occurredAt,
      refundToAccountId:
          refundToAccountId == _sentinel
              ? this.refundToAccountId
              : refundToAccountId as String?,
      submitting: submitting ?? this.submitting,
    );
  }
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
