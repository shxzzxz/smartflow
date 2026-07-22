import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'reimbursement_edit_form_view_model.g.dart';

@riverpod
class ReimbursementEditFormViewModel extends _$ReimbursementEditFormViewModel {
  @override
  Future<ReimbursementEditFormState> build(String transactionId) async {
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
      return ReimbursementEditFormState.notFound(
        transactionId: transactionId,
        accounts: accounts,
      );
    }

    final transaction = detail.transaction;
    final kind = switch (transaction.businessPurpose) {
      BusinessPurpose.reimbursementReceipt => ReimbursementEditKind.receipt,
      BusinessPurpose.reimbursementClose => ReimbursementEditKind.close,
      _ => null,
    };
    final parentTransactionId = transaction.parentTransactionId;
    if (kind == null || parentTransactionId == null) {
      return ReimbursementEditFormState.notFound(
        transactionId: transactionId,
        accounts: accounts,
      );
    }

    final parentDetail = await ref.watch(
      transactionDetailProvider(parentTransactionId).future,
    );
    final summary = parentDetail?.reimbursementSummary;
    if (parentDetail == null || summary == null) {
      return ReimbursementEditFormState.notFound(
        transactionId: transactionId,
        parentTransactionId: parentTransactionId,
        kind: kind,
        accounts: accounts,
      );
    }
    if (kind == ReimbursementEditKind.receipt && summary.isClosed) {
      return ReimbursementEditFormState.notEditable(
        transactionId: transactionId,
        parentTransactionId: parentTransactionId,
        kind: kind,
        accounts: accounts,
        reason: '报销已结束，请先删除结束报销',
      );
    }

    final receivableAccountId =
        reimbursementReceivableAccountId(parentDetail, accountsById) ??
        settlementAccountId(detail, accountsById, EntryDirection.credit);
    if (receivableAccountId == null) {
      return ReimbursementEditFormState.notEditable(
        transactionId: transactionId,
        parentTransactionId: parentTransactionId,
        kind: kind,
        accounts: accounts,
        reason: '无法定位报销账户，暂时无法编辑',
      );
    }

    final outstandingBeforeTransaction = switch (kind) {
      ReimbursementEditKind.receipt =>
        summary.advanceAmount -
            summary.receivedAmount +
            transaction.primaryAmount,
      ReimbursementEditKind.close => _closeOutstanding(detail),
    };
    final amount = switch (kind) {
      ReimbursementEditKind.receipt => transaction.primaryAmount,
      ReimbursementEditKind.close => _closeActualAmount(detail),
    };
    return ReimbursementEditFormState.loaded(
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      kind: kind,
      accounts: accounts,
      outstandingBeforeTransaction: outstandingBeforeTransaction,
      receivableAccountId: receivableAccountId,
      receiveAccountId: settlementAccountId(
        detail,
        accountsById,
        EntryDirection.debit,
      ),
      occurredAt: transaction.occurredAt,
      amountText: formatMoney(amount, style: MoneyFormatStyle.plain),
      noteText: transaction.note ?? '',
    );
  }

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setReceiveAccountId(String? value) =>
      _update((state) => state.copyWith(receiveAccountId: value));

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded || current.kind == null) {
      return _invalidCommand('报销编辑表单尚未加载');
    }
    final kind = current.kind!;
    final amount = Money.tryParse(amountText);
    if (amount == null ||
        (kind == ReimbursementEditKind.receipt
            ? amount.minorUnits <= 0
            : amount.minorUnits < 0)) {
      return _invalidCommand(
        kind == ReimbursementEditKind.receipt ? '请输入有效到账金额' : '请输入有效实收金额',
      );
    }
    final receiveAccountId = _selectedId(
      current.receiveAccountId,
      current.accounts,
    );
    final requiresReceiveAccount =
        kind == ReimbursementEditKind.receipt || amount.minorUnits > 0;
    if (requiresReceiveAccount && receiveAccountId == null) {
      return _invalidCommand('请选择到账账户');
    }
    final resolvedReceiveAccountId =
        requiresReceiveAccount
            ? receiveAccountId!
            : current.receivableAccountId;
    if (resolvedReceiveAccountId == null) {
      return _invalidCommand('无法定位报销账户');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      final editService = ref.read(transactionEditAppServiceProvider);
      switch (kind) {
        case ReimbursementEditKind.receipt:
          await editService.editReimbursementReceipt(
            EditReimbursementReceiptCommand(
              transactionId: current.transactionId,
              amount: amount,
              receivableAccountId: current.receivableAccountId,
              receiveAccountId: resolvedReceiveAccountId,
              occurredAt: current.occurredAt,
              note: _stringPatch(trimToNull(noteText)),
            ),
          );
        case ReimbursementEditKind.close:
          await editService.editReimbursementClose(
            EditReimbursementCloseCommand(
              transactionId: current.transactionId,
              actualReceivedAmount: amount,
              receivableAccountId: current.receivableAccountId,
              receiveAccountId: resolvedReceiveAccountId,
              occurredAt: current.occurredAt,
              note: _stringPatch(trimToNull(noteText)),
            ),
          );
      }
      ref.invalidate(transactionDetailProvider(current.transactionId));
      ref.invalidate(transactionDetailProvider(current.parentTransactionId));
      ref.invalidate(accountsByIdProvider);
      ref.invalidate(
        accountsForSelectionPurposeProvider(AccountSelectionPurpose.settlement),
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

  void _update(
    ReimbursementEditFormState Function(ReimbursementEditFormState) update,
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

enum ReimbursementEditKind { receipt, close }

enum ReimbursementEditFormStatus { loaded, notFound, notEditable }

class ReimbursementEditFormState {
  ReimbursementEditFormState({
    required this.status,
    required this.transactionId,
    required this.parentTransactionId,
    required this.kind,
    required List<Account> accounts,
    required this.occurredAt,
    required this.amountText,
    required this.noteText,
    required this.submitting,
    this.outstandingBeforeTransaction,
    this.receivableAccountId,
    this.receiveAccountId,
    this.unavailableReason,
  }) : accounts = List.unmodifiable(accounts);

  factory ReimbursementEditFormState.loaded({
    required String transactionId,
    required String parentTransactionId,
    required ReimbursementEditKind kind,
    required List<Account> accounts,
    required Money outstandingBeforeTransaction,
    required String receivableAccountId,
    required DateTime occurredAt,
    required String amountText,
    required String noteText,
    String? receiveAccountId,
  }) {
    return ReimbursementEditFormState(
      status: ReimbursementEditFormStatus.loaded,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      kind: kind,
      accounts: accounts,
      outstandingBeforeTransaction: outstandingBeforeTransaction,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      occurredAt: occurredAt,
      amountText: amountText,
      noteText: noteText,
      submitting: false,
    );
  }

  factory ReimbursementEditFormState.notFound({
    required String transactionId,
    required List<Account> accounts,
    String? parentTransactionId,
    ReimbursementEditKind? kind,
  }) {
    return ReimbursementEditFormState(
      status: ReimbursementEditFormStatus.notFound,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId ?? transactionId,
      kind: kind,
      accounts: accounts,
      occurredAt: DateTime.now(),
      amountText: '',
      noteText: '',
      submitting: false,
    );
  }

  factory ReimbursementEditFormState.notEditable({
    required String transactionId,
    required String parentTransactionId,
    required ReimbursementEditKind kind,
    required List<Account> accounts,
    required String reason,
  }) {
    return ReimbursementEditFormState(
      status: ReimbursementEditFormStatus.notEditable,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      kind: kind,
      accounts: accounts,
      unavailableReason: reason,
      occurredAt: DateTime.now(),
      amountText: '',
      noteText: '',
      submitting: false,
    );
  }

  final ReimbursementEditFormStatus status;
  final String transactionId;
  final String parentTransactionId;
  final ReimbursementEditKind? kind;
  final List<Account> accounts;
  final Money? outstandingBeforeTransaction;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final String? unavailableReason;
  final DateTime occurredAt;
  final String amountText;
  final String noteText;
  final bool submitting;

  bool get isLoaded => status == ReimbursementEditFormStatus.loaded;

  ReimbursementEditFormState copyWith({
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    bool? submitting,
  }) {
    return ReimbursementEditFormState(
      status: status,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      kind: kind,
      accounts: accounts,
      outstandingBeforeTransaction: outstandingBeforeTransaction,
      receivableAccountId: receivableAccountId,
      receiveAccountId:
          receiveAccountId == _sentinel
              ? this.receiveAccountId
              : receiveAccountId as String?,
      unavailableReason: unavailableReason,
      occurredAt: occurredAt ?? this.occurredAt,
      amountText: amountText,
      noteText: noteText,
      submitting: submitting ?? this.submitting,
    );
  }
}

Money _closeOutstanding(TransactionDetail detail) {
  return _detailAmount(detail, TransactionDetailType.reimbursementCloseMain) ??
      Money.zero();
}

Money _closeActualAmount(TransactionDetail detail) {
  final outstanding = _closeOutstanding(detail);
  final gapIncome =
      _detailAmount(detail, TransactionDetailType.reimbursementGapIncome) ??
      Money.zero();
  final gapExpense =
      _detailAmount(detail, TransactionDetailType.reimbursementGapExpense) ??
      Money.zero();
  return outstanding + gapIncome - gapExpense;
}

Money? _detailAmount(TransactionDetail detail, TransactionDetailType type) {
  for (final record in detail.details) {
    if (record.type == type) return record.amount;
  }
  return null;
}

Patch<String?> _stringPatch(String? value) {
  return value == null
      ? const Patch<String?>.clear()
      : Patch<String?>.set(value);
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return null;
}

const Object _sentinel = Object();
