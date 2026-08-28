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
    final defaultSettlementAllocations = defaultSettlementAllocationsForRefund(
      detail: detail,
      accounts: accounts,
    );
    final refundSummary = detail.refundSummary;
    final refunded = refundSummary?.refundedTotal ?? Money.zero();
    final availableCategories =
        refundSummary?.remainingCategoryAllocations ?? const [];
    final categoryAllocations =
        refundSummary?.originalCategoryAllocations ?? const [];
    return RefundFormState.loaded(
      transactionId: transactionId,
      parentTransactionId: transactionId,
      editing: false,
      accounts: accounts,
      categoryAccounts: _accountsForAllocations(
        categoryAllocations,
        accountsById,
      ),
      availableCategoryAllocations: availableCategories,
      remaining: _remainingForNewRefund(detail, refunded),
      refundToAccountId: defaultAccountId,
      settlementAllocations: defaultSettlementAllocations,
      occurredAt: DateTime.now(),
      amountText: '',
      noteText: '',
    );
  }

  Future<RefundFormState> _buildEditState({
    required String transactionId,
    required TransactionReadModel detail,
    required List<Account> accounts,
    required Map<String, Account> accountsById,
  }) async {
    final transaction = detail;
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
    final parentSummary = parentDetail.refundSummary;
    final availableCategories = parentSummary == null
        ? const <AccountAmountAllocation>[]
        : _addAllocations(
            parentSummary.remainingCategoryAllocations,
            _refundCategoryAllocations(transaction),
          );
    final parentCategories =
        parentSummary?.originalCategoryAllocations ?? const [];
    final categoryAllocations = _refundCategoryAllocations(transaction);
    final settlementAllocations = _allocationsOf(
      transaction,
      TransactionRole.settlementIn,
    );
    return RefundFormState.loaded(
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      editing: true,
      accounts: accounts,
      categoryAccounts: _accountsForAllocations(parentCategories, accountsById),
      availableCategoryAllocations: availableCategories,
      categoryAllocations: categoryAllocations,
      settlementAllocations: settlementAllocations,
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

  void setRefundToAccountId(String? value) => _update(
    (state) =>
        state.copyWith(refundToAccountId: value, settlementAllocations: null),
  );

  void setCategoryAllocations(List<AccountAmountAllocation> allocations) =>
      _update((state) => state.copyWith(categoryAllocations: allocations));

  void setSettlementAllocations(List<AccountAmountAllocation> allocations) =>
      _update(
        (state) => state.copyWith(
          settlementAllocations: allocations,
          refundToAccountId: allocations.isEmpty
              ? null
              : allocations.first.accountId,
        ),
      );

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
    final categoryAllocations = switch (current.categoryAllocations) {
      final allocations? => patchAllocations(
        current: allocations,
        total: amount,
      ),
      null when current.availableCategoryAllocations.length == 1 => [
        current.availableCategoryAllocations.single.copyWith(amount: amount),
      ],
      null => null,
    };
    if (categoryAllocations == null ||
        sumAllocations(categoryAllocations) != amount) {
      return _invalidCommand('请完成退款分类分配');
    }
    if (!allocationsFitAvailable(
      requested: categoryAllocations,
      available: current.availableCategoryAllocations,
    )) {
      return _invalidCommand('分类退款金额超过剩余可退金额');
    }
    final settlementAllocations = current.settlementAllocations == null
        ? singleAllocation(accountId: refundToAccountId, amount: amount)
        : patchAllocations(
            current: current.settlementAllocations!,
            total: amount,
          );
    if (sumAllocations(settlementAllocations) != amount) {
      return _invalidCommand('请完成退款到账分配');
    }

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
                  categoryAllocations: categoryAllocations,
                  settlementAllocations: settlementAllocations,
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
                  categoryAllocations: categoryAllocations,
                  settlementAllocations: settlementAllocations,
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
    required List<Account> categoryAccounts,
    required List<AccountAmountAllocation> availableCategoryAllocations,
    required this.occurredAt,
    required this.submitting,
    required this.amountText,
    required this.noteText,
    this.remaining,
    this.refundToAccountId,
    this.categoryAllocations,
    this.settlementAllocations,
  }) : accounts = List.unmodifiable(accounts),
       categoryAccounts = List.unmodifiable(categoryAccounts),
       availableCategoryAllocations = List.unmodifiable(
         availableCategoryAllocations,
       );

  factory RefundFormState.loaded({
    required String transactionId,
    required String parentTransactionId,
    required bool editing,
    required List<Account> accounts,
    required List<Account> categoryAccounts,
    required List<AccountAmountAllocation> availableCategoryAllocations,
    required Money remaining,
    required DateTime occurredAt,
    required String amountText,
    required String noteText,
    String? refundToAccountId,
    List<AccountAmountAllocation>? categoryAllocations,
    List<AccountAmountAllocation>? settlementAllocations,
  }) {
    return RefundFormState(
      status: RefundFormStatus.loaded,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      editing: editing,
      accounts: accounts,
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      remaining: remaining,
      occurredAt: occurredAt,
      refundToAccountId: refundToAccountId,
      categoryAllocations: categoryAllocations,
      settlementAllocations: settlementAllocations,
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
      categoryAccounts: const [],
      availableCategoryAllocations: const [],
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
      categoryAccounts: const [],
      availableCategoryAllocations: const [],
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
  final List<Account> categoryAccounts;
  final List<AccountAmountAllocation> availableCategoryAllocations;
  final Money? remaining;
  final DateTime occurredAt;
  final String? refundToAccountId;
  final List<AccountAmountAllocation>? categoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;
  final bool submitting;
  final String amountText;
  final String noteText;

  bool get isLoaded => status == RefundFormStatus.loaded;

  RefundFormState copyWith({
    DateTime? occurredAt,
    Object? refundToAccountId = _sentinel,
    Object? categoryAllocations = _sentinel,
    Object? settlementAllocations = _sentinel,
    bool? submitting,
  }) {
    return RefundFormState(
      status: status,
      transactionId: transactionId,
      parentTransactionId: parentTransactionId,
      editing: editing,
      accounts: accounts,
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      remaining: remaining,
      occurredAt: occurredAt ?? this.occurredAt,
      refundToAccountId: refundToAccountId == _sentinel
          ? this.refundToAccountId
          : refundToAccountId as String?,
      categoryAllocations: categoryAllocations == _sentinel
          ? this.categoryAllocations
          : categoryAllocations as List<AccountAmountAllocation>?,
      settlementAllocations: settlementAllocations == _sentinel
          ? this.settlementAllocations
          : settlementAllocations as List<AccountAmountAllocation>?,
      submitting: submitting ?? this.submitting,
      amountText: amountText,
      noteText: noteText,
    );
  }
}

Money _remainingForNewRefund(TransactionReadModel detail, Money refunded) {
  final summary = detail.reimbursementSummary;
  if (detail.businessPurpose == BusinessPurpose.reimbursementAdvance &&
      summary is ReimbursementSummary) {
    return summary.outstanding;
  }
  return detail.primaryAmount - refunded;
}

Money _remainingForEditedRefund(
  TransactionReadModel parentDetail,
  TransactionReadModel refund,
) {
  final summary = parentDetail.reimbursementSummary;
  final refundAmount = refund.amountOf(TransactionRole.settlementIn);
  if (parentDetail.businessPurpose == BusinessPurpose.reimbursementAdvance &&
      summary is ReimbursementSummary) {
    return summary.outstanding + refundAmount;
  }
  return parentDetail.primaryAmount -
      (parentDetail.refundSummary?.refundedTotal ?? Money.zero()) +
      refundAmount;
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

List<AccountAmountAllocation> _allocationsOf(
  TransactionReadModel transaction,
  TransactionRole role,
) {
  return [
    for (final line in transaction.linesOf(role))
      AccountAmountAllocation(accountId: line.accountId!, amount: line.amount),
  ];
}

List<AccountAmountAllocation> _refundCategoryAllocations(
  TransactionReadModel transaction,
) {
  final reimbursementCategories = transaction.linesOf(
    TransactionRole.reimbursementExpenseCategory,
  );
  final lines = reimbursementCategories.isNotEmpty
      ? reimbursementCategories
      : transaction.linesOf(TransactionRole.refundOffset);
  return [
    for (final line in lines)
      AccountAmountAllocation(accountId: line.accountId!, amount: line.amount),
  ];
}

List<AccountAmountAllocation> _addAllocations(
  Iterable<AccountAmountAllocation> first,
  Iterable<AccountAmountAllocation> second,
) {
  final amounts = <String, int>{};
  final order = <String>[];
  for (final allocation in [...first, ...second]) {
    if (!amounts.containsKey(allocation.accountId)) {
      order.add(allocation.accountId);
    }
    amounts[allocation.accountId] =
        (amounts[allocation.accountId] ?? 0) + allocation.amount.minorUnits;
  }
  return [
    for (final accountId in order)
      if ((amounts[accountId] ?? 0) > 0)
        AccountAmountAllocation(
          accountId: accountId,
          amount: Money(minorUnits: amounts[accountId]!),
        ),
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
