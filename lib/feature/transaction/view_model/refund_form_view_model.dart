import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'refund_form_view_model.g.dart';

final _logger = Logger('feature.transaction.refund_form');

@riverpod
class RefundFormViewModel extends _$RefundFormViewModel {
  @override
  Future<RefundFormState> build(
    String transactionId, {
    bool editing = false,
  }) async {
    final accounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).future,
    );
    final accountsById = await ref.watch(accountsByIdProvider.future);
    final detail = await ref.watch(
      transactionDetailProvider(transactionId).future,
    );
    if (detail == null) {
      return RefundFormState.notFound(
        accounts: accounts,
        transactionId: transactionId,
        editing: editing,
      );
    }
    if (editing) {
      return _buildEditState(
        transactionId: transactionId,
        detail: detail,
        accounts: accounts,
        accountsById: accountsById,
      );
    }
    final defaultAccountId = effectiveRefundToAccountId(
      selectedId: null,
      parentSettlementAccountId: parentSettlementAccountIdForRefund(
        detail,
        accountsById,
      ),
      accounts: accounts,
    );
    final refunded = _refundedTotal(detail);
    return RefundFormState.loaded(
      transactionId: transactionId,
      parentTransactionId: transactionId,
      editing: false,
      accounts: accounts,
      remaining: _remainingForNewRefund(detail, refunded),
      refundToAccountId: defaultAccountId,
      occurredAt: DateTime.now(),
      amountText: '',
      noteText: '',
    );
  }

  Future<RefundFormState> _buildEditState({
    required String transactionId,
    required TransactionDetail detail,
    required List<Account> accounts,
    required Map<String, Account> accountsById,
  }) async {
    final transaction = detail.transaction;
    final parentTransactionId = transaction.parentTransactionId;
    if (transaction.businessPurpose != BusinessPurpose.refund ||
        parentTransactionId == null) {
      return RefundFormState.notFound(
        accounts: accounts,
        transactionId: transactionId,
        editing: true,
      );
    }
    final parentDetail = await ref.watch(
      transactionDetailProvider(parentTransactionId).future,
    );
    if (parentDetail == null) {
      return RefundFormState.notFound(
        accounts: accounts,
        transactionId: transactionId,
        editing: true,
      );
    }
    if (parentDetail.reimbursementSummary?.isClosed ?? false) {
      return RefundFormState.notEditable(
        accounts: accounts,
        transactionId: transactionId,
        parentTransactionId: parentTransactionId,
      );
    }
    final selectedAccountId = settlementAccountId(
      detail,
      accountsById,
      EntryDirection.debit,
    );
    final refundToAccountId = effectiveRefundToAccountId(
      selectedId: selectedAccountId,
      parentSettlementAccountId: parentSettlementAccountIdForRefund(
        parentDetail,
        accountsById,
      ),
      accounts: accounts,
    );
    final remaining = _remainingForEditedRefund(parentDetail, transaction);
    return RefundFormState.loaded(
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      editing: true,
      accounts: accounts,
      remaining: remaining,
      refundToAccountId: refundToAccountId,
      occurredAt: transaction.occurredAt,
      amountText: formatMoney(
        transaction.primaryAmount,
        style: MoneyFormatStyle.plain,
      ),
      noteText: transaction.note ?? '',
    );
  }

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setRefundToAccountId(String? value) =>
      _update((state) => state.copyWith(refundToAccountId: value));

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('退款表单尚未加载');
    }
    final amount = _parsePositiveMoney(amountText);
    if (amount == null) return _invalidCommand('请输入有效退款金额');
    final refundToAccountId = _selectedId(
      current.refundToAccountId,
      current.accounts,
    );
    if (refundToAccountId == null) return _invalidCommand('请选择退款账户');

    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Refund form submit', () async {
        if (current.editing) {
          await ref
              .read(transactionEditAppServiceProvider)
              .editRefund(
                EditRefundCommand(
                  transactionId: current.transactionId,
                  amount: amount,
                  refundToAccountId: refundToAccountId,
                  occurredAt: current.occurredAt,
                  note: _stringPatch(trimToNull(noteText)),
                ),
              );
        } else {
          await ref
              .read(transactionPostingAppServiceProvider)
              .createRefund(
                CreateRefundCommand(
                  amount: amount,
                  parentTransactionId: current.parentTransactionId,
                  refundToAccountId: refundToAccountId,
                  occurredAt: current.occurredAt,
                  note: trimToNull(noteText),
                ),
              );
        }
        ref.invalidate(transactionDetailProvider(current.transactionId));
        ref.invalidate(transactionDetailProvider(current.parentTransactionId));
        ref.invalidate(accountsByIdProvider);
        ref.invalidate(
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.settlement,
          ),
        );
      });
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

enum RefundFormStatus { loaded, notFound, notEditable }

class RefundFormState {
  RefundFormState({
    required this.status,
    required this.transactionId,
    required this.parentTransactionId,
    required this.editing,
    required List<Account> accounts,
    required this.occurredAt,
    required this.submitting,
    required this.amountText,
    required this.noteText,
    this.remaining,
    this.refundToAccountId,
  }) : accounts = List.unmodifiable(accounts);

  factory RefundFormState.loaded({
    required String transactionId,
    required String parentTransactionId,
    required bool editing,
    required List<Account> accounts,
    required Money remaining,
    required DateTime occurredAt,
    required String amountText,
    required String noteText,
    String? refundToAccountId,
  }) {
    return RefundFormState(
      status: RefundFormStatus.loaded,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      editing: editing,
      accounts: accounts,
      remaining: remaining,
      occurredAt: occurredAt,
      refundToAccountId: refundToAccountId,
      submitting: false,
      amountText: amountText,
      noteText: noteText,
    );
  }

  factory RefundFormState.notFound({
    required List<Account> accounts,
    required String transactionId,
    required bool editing,
  }) {
    return RefundFormState(
      status: RefundFormStatus.notFound,
      transactionId: transactionId,
      parentTransactionId: transactionId,
      editing: editing,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
      amountText: '',
      noteText: '',
    );
  }

  factory RefundFormState.notEditable({
    required List<Account> accounts,
    required String transactionId,
    required String parentTransactionId,
  }) {
    return RefundFormState(
      status: RefundFormStatus.notEditable,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      editing: true,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
      amountText: '',
      noteText: '',
    );
  }

  final RefundFormStatus status;
  final String transactionId;
  final String parentTransactionId;
  final bool editing;
  final List<Account> accounts;
  final Money? remaining;
  final DateTime occurredAt;
  final String? refundToAccountId;
  final bool submitting;
  final String amountText;
  final String noteText;

  bool get isLoaded => status == RefundFormStatus.loaded;

  RefundFormState copyWith({
    DateTime? occurredAt,
    Object? refundToAccountId = _sentinel,
    bool? submitting,
  }) {
    return RefundFormState(
      status: status,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      editing: editing,
      accounts: accounts,
      remaining: remaining,
      occurredAt: occurredAt ?? this.occurredAt,
      refundToAccountId:
          refundToAccountId == _sentinel
              ? this.refundToAccountId
              : refundToAccountId as String?,
      submitting: submitting ?? this.submitting,
      amountText: amountText,
      noteText: noteText,
    );
  }
}

Money _refundedTotal(TransactionDetail detail) {
  final refundChildren = detail.children.where(
    (child) => child.businessPurpose == BusinessPurpose.refund,
  );
  if (refundChildren.isNotEmpty) {
    return refundChildren.fold(
      Money.zero(),
      (sum, child) => sum + child.primaryAmount,
    );
  }
  return detail.refundedTotal ?? Money.zero();
}

Money _remainingForNewRefund(TransactionDetail detail, Money refunded) {
  final summary = detail.reimbursementSummary;
  if (detail.transaction.businessPurpose ==
          BusinessPurpose.reimbursementAdvance &&
      summary is ReimbursementSummary) {
    return summary.outstanding;
  }
  return detail.transaction.primaryAmount - refunded;
}

Money _remainingForEditedRefund(
  TransactionDetail parentDetail,
  Transaction refund,
) {
  final summary = parentDetail.reimbursementSummary;
  if (parentDetail.transaction.businessPurpose ==
          BusinessPurpose.reimbursementAdvance &&
      summary is ReimbursementSummary) {
    return summary.outstanding + refund.primaryAmount;
  }
  return parentDetail.transaction.primaryAmount -
      _refundedTotal(parentDetail) +
      refund.primaryAmount;
}

Patch<String?> _stringPatch(String? value) {
  return value == null
      ? const Patch<String?>.clear()
      : Patch<String?>.set(value);
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
