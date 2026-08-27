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

part 'reimbursement_edit_form_view_model.g.dart';

final _logger = Logger('feature.transaction.reimbursement_edit_form');

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

    final transaction = detail;
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
        summary.outstanding + transaction.primaryAmount,
      ReimbursementEditKind.close => _closeOutstanding(detail),
    };
    final amount = switch (kind) {
      ReimbursementEditKind.receipt => transaction.primaryAmount,
      ReimbursementEditKind.close => _closeActualAmount(detail),
    };
    final availableCategories = parentDetail
        .remainingRefundableCategoryAllocations();
    final parentCategories = parentDetail.refundableCategoryAllocations;
    return ReimbursementEditFormState.loaded(
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      kind: kind,
      accounts: accounts,
      categoryAccounts: _accountsForAllocations(parentCategories, accountsById),
      availableCategoryAllocations: availableCategories,
      settlementAllocations: _allocationsOf(
        detail,
        TransactionRole.settlementIn,
      ),
      gapExpenseAllocations: _allocationsOf(
        detail,
        TransactionRole.reimbursementGapExpense,
      ),
      outstandingBeforeTransaction: outstandingBeforeTransaction,
      receivableAccountId: receivableAccountId,
      receiveAccountId: _positiveSettlementInAccountId(detail),
      occurredAt: transaction.occurredAt,
      amountText: formatMoney(amount, style: MoneyFormatStyle.plain),
      noteText: transaction.note ?? '',
    );
  }

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setReceiveAccountId(String? value) => _update(
    (state) =>
        state.copyWith(receiveAccountId: value, settlementAllocations: null),
  );

  void setSettlementAllocations(List<AccountAmountAllocation> allocations) =>
      _update(
        (state) => state.copyWith(
          settlementAllocations: allocations,
          receiveAccountId: allocations.isEmpty
              ? null
              : allocations.first.accountId,
        ),
      );

  void setGapExpenseAllocations(List<AccountAmountAllocation> allocations) =>
      _update((state) => state.copyWith(gapExpenseAllocations: allocations));

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
    final resolvedReceiveAccountId = requiresReceiveAccount
        ? receiveAccountId!
        : current.receivableAccountId;
    if (resolvedReceiveAccountId == null) {
      return _invalidCommand('无法定位报销账户');
    }
    final settlements = !requiresReceiveAccount
        ? singleAllocation(accountId: resolvedReceiveAccountId, amount: amount)
        : current.settlementAllocations == null
        ? singleAllocation(accountId: resolvedReceiveAccountId, amount: amount)
        : patchAllocations(
            current: current.settlementAllocations!,
            total: amount,
          );
    if (sumAllocations(settlements) != amount) {
      return _invalidCommand('请完成到账账户分配');
    }
    final shortfall =
        (current.outstandingBeforeTransaction ?? Money.zero()) - amount;
    final gaps = kind == ReimbursementEditKind.close && shortfall.minorUnits > 0
        ? switch (current.gapExpenseAllocations) {
            final allocations? => patchAllocations(
              current: allocations,
              total: shortfall,
            ),
            null when current.availableCategoryAllocations.length == 1 => [
              current.availableCategoryAllocations.single.copyWith(
                amount: shortfall,
              ),
            ],
            null => null,
          }
        : const <AccountAmountAllocation>[];
    final requiredGap =
        kind == ReimbursementEditKind.close && shortfall.minorUnits > 0
        ? shortfall
        : Money.zero();
    if (gaps == null ||
        sumAllocations(gaps) != requiredGap ||
        !allocationsFitAvailable(
          requested: gaps,
          available: current.availableCategoryAllocations,
        )) {
      return _invalidCommand('请完成差额分类分配');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(
        _logger,
        'Reimbursement edit form submit',
        () async {
          final editService = ref.read(transactionEditAppServiceProvider);
          switch (kind) {
            case ReimbursementEditKind.receipt:
              await editService.editReimbursementReceipt(
                EditReimbursementReceiptCommand(
                  transactionId: current.transactionId,
                  amount: amount,
                  receivableAccountId: current.receivableAccountId,
                  settlementAllocations: settlements,
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
                  settlementAllocations: settlements,
                  gapExpenseAllocations: gaps,
                  occurredAt: current.occurredAt,
                  note: _stringPatch(trimToNull(noteText)),
                ),
              );
          }
          ref.invalidate(transactionDetailProvider(current.transactionId));
          ref.invalidate(
            transactionDetailProvider(current.parentTransactionId),
          );
          ref.invalidate(accountsByIdProvider);
          ref.invalidate(
            accountsForSelectionPurposeProvider(
              AccountSelectionPurpose.settlement,
            ),
          );
        },
      );
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

String? _positiveSettlementInAccountId(TransactionReadModel detail) {
  for (final line in detail.linesOf(TransactionRole.settlementIn)) {
    if (line.amount.minorUnits > 0) return line.accountId;
  }
  return null;
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
    required List<Account> categoryAccounts,
    required List<AccountAmountAllocation> availableCategoryAllocations,
    required List<AccountAmountAllocation>? settlementAllocations,
    required List<AccountAmountAllocation>? gapExpenseAllocations,
    required this.occurredAt,
    required this.amountText,
    required this.noteText,
    required this.submitting,
    this.outstandingBeforeTransaction,
    this.receivableAccountId,
    this.receiveAccountId,
    this.unavailableReason,
  }) : accounts = List.unmodifiable(accounts),
       categoryAccounts = List.unmodifiable(categoryAccounts),
       availableCategoryAllocations = List.unmodifiable(
         availableCategoryAllocations,
       ),
       settlementAllocations = settlementAllocations == null
           ? null
           : List.unmodifiable(settlementAllocations),
       gapExpenseAllocations = gapExpenseAllocations == null
           ? null
           : List.unmodifiable(gapExpenseAllocations);

  factory ReimbursementEditFormState.loaded({
    required String transactionId,
    required String parentTransactionId,
    required ReimbursementEditKind kind,
    required List<Account> accounts,
    required List<Account> categoryAccounts,
    required List<AccountAmountAllocation> availableCategoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
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
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      settlementAllocations: settlementAllocations,
      gapExpenseAllocations: gapExpenseAllocations,
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
      categoryAccounts: const [],
      availableCategoryAllocations: const [],
      settlementAllocations: const [],
      gapExpenseAllocations: const [],
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
      categoryAccounts: const [],
      availableCategoryAllocations: const [],
      settlementAllocations: const [],
      gapExpenseAllocations: const [],
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
  final List<Account> categoryAccounts;
  final List<AccountAmountAllocation> availableCategoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;
  final List<AccountAmountAllocation>? gapExpenseAllocations;
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
    Object? settlementAllocations = _sentinel,
    Object? gapExpenseAllocations = _sentinel,
    bool? submitting,
  }) {
    return ReimbursementEditFormState(
      status: status,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      kind: kind,
      accounts: accounts,
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      settlementAllocations: settlementAllocations == _sentinel
          ? this.settlementAllocations
          : settlementAllocations as List<AccountAmountAllocation>?,
      gapExpenseAllocations: gapExpenseAllocations == _sentinel
          ? this.gapExpenseAllocations
          : gapExpenseAllocations as List<AccountAmountAllocation>?,
      outstandingBeforeTransaction: outstandingBeforeTransaction,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId == _sentinel
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

Money _closeOutstanding(TransactionReadModel detail) {
  return _lineAmount(detail, TransactionRole.receivable) ?? Money.zero();
}

Money _closeActualAmount(TransactionReadModel detail) {
  return detail.amountOf(TransactionRole.settlementIn);
}

Money? _lineAmount(TransactionReadModel detail, TransactionRole role) {
  for (final line in detail.lines) {
    if (line.role == role) return line.amount;
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

List<AccountAmountAllocation> _allocationsOf(
  TransactionReadModel transaction,
  TransactionRole role,
) {
  return [
    for (final line in transaction.linesOf(role))
      AccountAmountAllocation(accountId: line.accountId!, amount: line.amount),
  ];
}

List<Account> _accountsForAllocations(
  Iterable<AccountAmountAllocation> allocations,
  Map<String, Account> accountsById,
) {
  return [
    for (final allocation in allocations) ?accountsById[allocation.accountId],
  ];
}

const Object _sentinel = Object();
