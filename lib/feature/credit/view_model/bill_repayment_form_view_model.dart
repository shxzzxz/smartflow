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
import '../provider/bill_query_providers.dart';
import '../provider/installment_query_providers.dart';
import '../provider/credit_account_query_providers.dart';
import '../presentation/bill_item_presentation.dart';
import 'bill_repayment_allocation_view_model.dart';

part 'bill_repayment_form_view_model.g.dart';

@riverpod
class BillRepaymentFormViewModel extends _$BillRepaymentFormViewModel {
  @override
  Future<BillRepaymentFormState> build(BillRepaymentFormArgs args) async {
    final editView =
        args.repaymentId == null
            ? null
            : await ref
                .read(repaymentAppServiceProvider)
                .loadBillRepaymentEditView(args.repaymentId!);
    final billId = args.billId ?? editView?.billId;
    final repaymentSourceAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ).future,
    );

    if (billId == null || (args.repaymentId != null && editView == null)) {
      return BillRepaymentFormState.notFound(
        repaymentSourceAccounts: repaymentSourceAccounts,
      );
    }
    final detail = await ref.watch(billDetailProvider(billId).future);
    if (detail == null) {
      return BillRepaymentFormState.notFound(
        repaymentSourceAccounts: repaymentSourceAccounts,
      );
    }

    final lines = _allocationLines(detail, editing: editView?.allocations);
    if (lines.isEmpty) {
      return BillRepaymentFormState.noPending(
        summary: detail.summary,
        repaymentSourceAccounts: repaymentSourceAccounts,
      );
    }

    final pending =
        editView == null
            ? _pendingBreakdown(lines)
            : _totalAllocations(editView.allocations);
    final repaymentAccounts = _repaymentAccounts(
      repaymentSourceAccounts,
      detail.summary.accountId,
    );
    final defaultAllocations =
        editView?.allocations ??
        _allocationReview(
          lines: lines,
          mode: BillRepaymentAllocationMode.fifo,
          amount: pending,
        ).allocations;
    return BillRepaymentFormState.loaded(
      summary: detail.summary,
      lines: lines,
      repaymentSourceAccounts: repaymentSourceAccounts,
      principalText: pending.principal.format(),
      interestText: _optionalDefaultText(pending.interest),
      feeText: _optionalDefaultText(pending.fee),
      discountText: _optionalDefaultText(pending.discount),
      paidFromAccountId: _selectedId(
        editView?.paidFromAccountId,
        repaymentAccounts,
      ),
      occurredAt: editView?.occurredAt ?? DateTime.now(),
      noteText: editView?.note ?? '',
      createTransaction: editView?.hasTransaction ?? true,
      editingRepaymentId: editView?.repaymentId,
      manualAllocations: _manualAmountsFromAllocations(defaultAllocations),
    );
  }

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setPaidFromAccountId(String? value) =>
      _update((state) => state.copyWith(paidFromAccountId: value));

  void setCreateTransaction(bool value) =>
      _update((state) => state.copyWith(createTransaction: value));

  void setAllocationMode(BillRepaymentAllocationMode value) =>
      _update((state) => state.copyWith(allocationMode: value));

  void calculateAllocation({
    required String principalText,
    required String interestText,
    required String feeText,
    required String discountText,
  }) => _update((state) {
    if (state.allocationMode == BillRepaymentAllocationMode.manual) {
      return state;
    }
    final amount = _amountFromText(
      principalText: principalText,
      interestText: interestText,
      feeText: feeText,
      discountText: discountText,
    );
    if (amount == null) return state;
    final review = _allocationReview(
      lines: state.lines,
      mode: state.allocationMode,
      amount: amount,
    );
    return state.copyWith(
      manualAllocations: _manualAmountsFromAllocations(review.allocations),
    );
  });

  void setManualAllocationAmount({
    required String billItemId,
    Money? principal,
    Money? interest,
    Money? fee,
    Money? discount,
  }) {
    _update((state) {
      final current =
          state.manualAllocations[billItemId] ??
          credit.RepaymentAmountBreakdown.zero;
      return state.copyWith(
        manualAllocations: {
          ...state.manualAllocations,
          billItemId: credit.RepaymentAmountBreakdown(
            principal: principal ?? current.principal,
            interest: interest ?? current.interest,
            fee: fee ?? current.fee,
            discount: discount ?? current.discount,
          ),
        },
      );
    });
  }

  BillRepaymentAllocationReview? allocationReview({
    required String principalText,
    required String interestText,
    required String feeText,
    required String discountText,
  }) {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) return null;
    final amount = _amountFromText(
      principalText: principalText,
      interestText: interestText,
      feeText: feeText,
      discountText: discountText,
    );
    return amount == null
        ? null
        : _allocationReviewFromState(current, amount: amount);
  }

  Future<SubmitOutcome> submit({
    required String principalText,
    required String interestText,
    required String feeText,
    required String discountText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('账单还款表单尚未加载');
    }
    final principal = _parseOptionalNonNegativeMoney(principalText);
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
    final paidFromAccountId =
        current.createTransaction
            ? _selectedId(current.paidFromAccountId, current.repaymentAccounts)
            : null;
    if (current.createTransaction && paidFromAccountId == null) {
      return _invalidCommand('请选择还款账户');
    }

    final amount = credit.RepaymentAmountBreakdown(
      principal: principal,
      interest: interest,
      fee: fee,
      discount: discount,
    );
    final review = _allocationReviewFromState(current, amount: amount);
    if (review == null) return _invalidCommand('请输入有效分摊金额');
    if (review.allocations.isEmpty ||
        review.totalAllocated.cashPaid.minorUnits <= 0) {
      return _invalidCommand('账单没有可还明细');
    }
    if (_hasNonZeroPart(review.unallocated)) {
      return _invalidCommand('分摊合计必须等于还款金额');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      final service = ref.read(repaymentAppServiceProvider);
      if (current.editingRepaymentId == null) {
        await service.createBillRepayment(
          credit.CreateBillRepaymentCommand(
            billId: current.summary!.id,
            allocations: review.allocations,
            transactionInfo:
                paidFromAccountId == null
                    ? null
                    : credit.RepaymentTransactionInfo(
                      paidFromAccountId: paidFromAccountId,
                      occurredAt: current.occurredAt,
                    ),
            note: trimToNull(noteText),
          ),
        );
      } else {
        await service.editBillRepayment(
          credit.EditBillRepaymentCommand(
            repaymentId: current.editingRepaymentId!,
            allocations: review.allocations,
            transactionInfo:
                paidFromAccountId == null
                    ? null
                    : credit.RepaymentTransactionInfo(
                      paidFromAccountId: paidFromAccountId,
                      occurredAt: current.occurredAt,
                      note: trimToNull(noteText),
                    ),
            note: trimToNull(noteText),
          ),
        );
      }
      _invalidateAfterSubmit(accountId: current.summary!.accountId);
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _invalidateAfterSubmit({required String accountId}) {
    ref.invalidate(billDetailProvider(state.requireValue.summary!.id));
    ref.invalidate(billSummariesByAccountProvider(accountId));
    ref.invalidate(accountsByIdProvider);
    ref.invalidate(transactionListProvider(accountId: accountId));
    ref.invalidate(installmentContractsByAccountProvider(accountId));
    ref.invalidate(creditAccountOverviewProvider(accountId));
    ref.invalidate(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentSource,
      ),
    );
  }

  void _update(BillRepaymentFormState Function(BillRepaymentFormState) update) {
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

enum BillRepaymentFormLoadStatus { loaded, notFound, noPending }

class BillRepaymentFormState {
  const BillRepaymentFormState({
    required this.status,
    required this.repaymentSourceAccounts,
    required this.lines,
    required this.principalText,
    required this.interestText,
    required this.feeText,
    required this.discountText,
    required this.noteText,
    required this.occurredAt,
    required this.createTransaction,
    required this.allocationMode,
    required this.manualAllocations,
    required this.submitting,
    this.summary,
    this.paidFromAccountId,
    this.editingRepaymentId,
  });

  factory BillRepaymentFormState.loaded({
    required credit_query.BillSummaryReadModel summary,
    required List<BillRepaymentAllocationLine> lines,
    required List<Account> repaymentSourceAccounts,
    required DateTime occurredAt,
    String principalText = '',
    String interestText = '',
    String feeText = '',
    String discountText = '',
    String noteText = '',
    String? paidFromAccountId,
    Map<String, credit.RepaymentAmountBreakdown> manualAllocations = const {},
    bool createTransaction = true,
    String? editingRepaymentId,
  }) {
    return BillRepaymentFormState(
      status: BillRepaymentFormLoadStatus.loaded,
      summary: summary,
      lines: lines,
      repaymentSourceAccounts: repaymentSourceAccounts,
      principalText: principalText,
      interestText: interestText,
      feeText: feeText,
      discountText: discountText,
      noteText: noteText,
      occurredAt: occurredAt,
      paidFromAccountId: paidFromAccountId,
      createTransaction: createTransaction,
      editingRepaymentId: editingRepaymentId,
      allocationMode: BillRepaymentAllocationMode.fifo,
      manualAllocations: manualAllocations,
      submitting: false,
    );
  }

  factory BillRepaymentFormState.notFound({
    required List<Account> repaymentSourceAccounts,
  }) {
    return BillRepaymentFormState(
      status: BillRepaymentFormLoadStatus.notFound,
      repaymentSourceAccounts: repaymentSourceAccounts,
      lines: const [],
      principalText: '',
      interestText: '',
      feeText: '',
      discountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      createTransaction: true,
      allocationMode: BillRepaymentAllocationMode.fifo,
      manualAllocations: const {},
      submitting: false,
    );
  }

  factory BillRepaymentFormState.noPending({
    required credit_query.BillSummaryReadModel summary,
    required List<Account> repaymentSourceAccounts,
  }) {
    return BillRepaymentFormState(
      status: BillRepaymentFormLoadStatus.noPending,
      summary: summary,
      repaymentSourceAccounts: repaymentSourceAccounts,
      lines: const [],
      principalText: '',
      interestText: '',
      feeText: '',
      discountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      createTransaction: true,
      allocationMode: BillRepaymentAllocationMode.fifo,
      manualAllocations: const {},
      submitting: false,
    );
  }

  final BillRepaymentFormLoadStatus status;
  final credit_query.BillSummaryReadModel? summary;
  final List<Account> repaymentSourceAccounts;
  final List<BillRepaymentAllocationLine> lines;

  /// Controller initialization snapshot. User edits remain in the View.
  final String principalText;
  final String interestText;
  final String feeText;
  final String discountText;
  final String noteText;
  final DateTime occurredAt;
  final String? paidFromAccountId;
  final String? editingRepaymentId;
  final bool createTransaction;
  final BillRepaymentAllocationMode allocationMode;
  final Map<String, credit.RepaymentAmountBreakdown> manualAllocations;
  final bool submitting;

  bool get isLoaded => status == BillRepaymentFormLoadStatus.loaded;

  List<Account> get repaymentAccounts {
    final accountId = summary?.accountId;
    return _repaymentAccounts(repaymentSourceAccounts, accountId);
  }

  credit.RepaymentAmountBreakdown get pendingBreakdown =>
      _pendingBreakdown(lines);

  credit.RepaymentAmountBreakdown manualAllocation(String billItemId) {
    return manualAllocations[billItemId] ??
        credit.RepaymentAmountBreakdown.zero;
  }

  BillRepaymentFormState copyWith({
    DateTime? occurredAt,
    Object? paidFromAccountId = _sentinel,
    bool? createTransaction,
    BillRepaymentAllocationMode? allocationMode,
    Map<String, credit.RepaymentAmountBreakdown>? manualAllocations,
    bool? submitting,
  }) {
    return BillRepaymentFormState(
      status: status,
      summary: summary,
      repaymentSourceAccounts: repaymentSourceAccounts,
      lines: lines,
      principalText: principalText,
      interestText: interestText,
      feeText: feeText,
      discountText: discountText,
      noteText: noteText,
      occurredAt: occurredAt ?? this.occurredAt,
      paidFromAccountId:
          paidFromAccountId == _sentinel
              ? this.paidFromAccountId
              : paidFromAccountId as String?,
      editingRepaymentId: editingRepaymentId,
      createTransaction: createTransaction ?? this.createTransaction,
      allocationMode: allocationMode ?? this.allocationMode,
      manualAllocations: manualAllocations ?? this.manualAllocations,
      submitting: submitting ?? this.submitting,
    );
  }
}

List<BillRepaymentAllocationLine> _allocationLines(
  credit_query.BillDetailReadModel detail, {
  List<credit.BillRepaymentAllocation>? editing,
}) {
  final editingByItem = {
    for (final allocation
        in editing ?? const <credit.BillRepaymentAllocation>[])
      allocation.billItemId: allocation.allocated,
  };
  return [
    for (final item in detail.items)
      if (item.status == credit.BillItemStatus.pending ||
          item.status == credit.BillItemStatus.partiallyPaid ||
          editingByItem.containsKey(item.id))
        if (detail.summary.status != credit.BillStatus.open ||
            item.itemType == credit.BillItemType.consumption)
          BillRepaymentAllocationLine(
            billItemId: item.id,
            itemType: item.itemType,
            label: billItemLabel(item),
            expected: credit.RepaymentAmountBreakdown(
              principal: item.expectedPrincipal,
              interest: item.expectedInterest,
              fee: item.expectedFee,
              discount: Money.zero(),
            ),
            alreadyAllocated: _subtractDto(
              item.allocated,
              editingByItem[item.id] ?? credit.RepaymentAmountDto.zero,
            ),
          ),
  ];
}

BillRepaymentAllocationReview _allocationReview({
  required List<BillRepaymentAllocationLine> lines,
  required BillRepaymentAllocationMode mode,
  required credit.RepaymentAmountBreakdown amount,
}) {
  final allocator = BillRepaymentAllocationViewModel(lines: lines);
  final review = allocator.suggest(mode: mode, amount: amount);
  if (!_hasPositivePart(review.unallocated) || lines.isEmpty) {
    return review;
  }

  final allocations = {
    for (final allocation in review.allocations)
      allocation.billItemId: allocation.allocated,
  };
  final targetId =
      allocations.isNotEmpty ? allocations.keys.first : lines.first.billItemId;
  allocations[targetId] = _add(allocations[targetId], review.unallocated);
  return allocator.reviewManual(
    amount: amount,
    allocations: [
      for (final line in lines)
        if (allocations[line.billItemId] != null)
          credit.BillRepaymentAllocation(
            billItemId: line.billItemId,
            allocated: allocations[line.billItemId]!,
          ),
    ],
  );
}

BillRepaymentAllocationReview? _allocationReviewFromState(
  BillRepaymentFormState state, {
  required credit.RepaymentAmountBreakdown amount,
}) {
  final allocations = <credit.BillRepaymentAllocation>[];
  for (final line in state.lines) {
    final manual = state.manualAllocation(line.billItemId);
    final allocated = credit.RepaymentAmountDto(
      principal: manual.principal,
      interest: manual.interest,
      fee: manual.fee,
      discount: manual.discount,
    );
    if (!_hasPositiveAmount(allocated)) continue;
    allocations.add(
      credit.BillRepaymentAllocation(
        billItemId: line.billItemId,
        allocated: allocated,
      ),
    );
  }

  return BillRepaymentAllocationViewModel(
    lines: state.lines,
  ).reviewManual(amount: amount, allocations: allocations);
}

Map<String, credit.RepaymentAmountBreakdown> _manualAmountsFromAllocations(
  List<credit.BillRepaymentAllocation> allocations,
) {
  return {
    for (final allocation in allocations)
      allocation.billItemId: credit.RepaymentAmountBreakdown(
        principal: allocation.allocated.principal,
        interest: allocation.allocated.interest,
        fee: allocation.allocated.fee,
        discount: allocation.allocated.discount,
      ),
  };
}

credit.RepaymentAmountBreakdown? _amountFromText({
  required String principalText,
  required String interestText,
  required String feeText,
  required String discountText,
}) {
  final principal = _parseOptionalNonNegativeMoney(principalText);
  final interest = _parseOptionalNonNegativeMoney(interestText);
  final fee = _parseOptionalNonNegativeMoney(feeText);
  final discount = _parseOptionalNonNegativeMoney(discountText);
  if (principal == null ||
      interest == null ||
      fee == null ||
      discount == null) {
    return null;
  }
  return credit.RepaymentAmountBreakdown(
    principal: principal,
    interest: interest,
    fee: fee,
    discount: discount,
  );
}

credit.RepaymentAmountBreakdown _pendingBreakdown(
  List<BillRepaymentAllocationLine> lines,
) {
  return lines.fold(
    credit.RepaymentAmountBreakdown.zero,
    (sum, line) =>
        sum +
        credit.RepaymentAmountBreakdown(
          principal: Money(minorUnits: line.remainingPrincipal),
          interest: Money(minorUnits: line.remainingInterest),
          fee: Money(minorUnits: line.remainingFee),
          discount: Money.zero(),
        ),
  );
}

credit.RepaymentAmountDto _add(
  credit.RepaymentAmountDto? current,
  credit.RepaymentAmountBreakdown addition,
) {
  final value = current ?? credit.RepaymentAmountDto.zero;
  return credit.RepaymentAmountDto(
    principal: value.principal + addition.principal,
    interest: value.interest + addition.interest,
    fee: value.fee + addition.fee,
    discount: value.discount + addition.discount,
  );
}

bool _hasPositivePart(credit.RepaymentAmountBreakdown value) {
  return value.principal.minorUnits > 0 ||
      value.interest.minorUnits > 0 ||
      value.fee.minorUnits > 0 ||
      value.discount.minorUnits > 0;
}

bool _hasPositiveAmount(credit.RepaymentAmountDto value) {
  return value.principal.minorUnits > 0 ||
      value.interest.minorUnits > 0 ||
      value.fee.minorUnits > 0 ||
      value.discount.minorUnits > 0;
}

bool _hasNonZeroPart(credit.RepaymentAmountBreakdown value) {
  return value.principal.minorUnits != 0 ||
      value.interest.minorUnits != 0 ||
      value.fee.minorUnits != 0 ||
      value.discount.minorUnits != 0;
}

List<Account> _repaymentAccounts(List<Account> accounts, String? liabilityId) {
  return accounts.where((account) => account.id != liabilityId).toList();
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return accounts.isEmpty ? null : accounts.first.id;
}

Money? _parseOptionalNonNegativeMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  final money = Money.tryParse(trimmed);
  return money != null && money.minorUnits >= 0 ? money : null;
}

credit.RepaymentAmountBreakdown _totalAllocations(
  Iterable<credit.BillRepaymentAllocation> allocations,
) {
  return allocations.fold(
    credit.RepaymentAmountBreakdown.zero,
    (sum, allocation) =>
        sum +
        credit.RepaymentAmountBreakdown(
          principal: allocation.allocated.principal,
          interest: allocation.allocated.interest,
          fee: allocation.allocated.fee,
          discount: allocation.allocated.discount,
        ),
  );
}

class BillRepaymentFormArgs {
  const BillRepaymentFormArgs.create(this.billId) : repaymentId = null;

  const BillRepaymentFormArgs.edit(this.repaymentId) : billId = null;

  final String? billId;
  final String? repaymentId;

  @override
  bool operator ==(Object other) =>
      other is BillRepaymentFormArgs &&
      other.billId == billId &&
      other.repaymentId == repaymentId;

  @override
  int get hashCode => Object.hash(billId, repaymentId);
}

credit.RepaymentAmountDto _subtractDto(
  credit.RepaymentAmountDto left,
  credit.RepaymentAmountDto right,
) {
  return credit.RepaymentAmountDto(
    principal: left.principal - right.principal,
    interest: left.interest - right.interest,
    fee: left.fee - right.fee,
    discount: left.discount - right.discount,
  );
}

String _optionalDefaultText(Money money) {
  return money.minorUnits > 0 ? money.format() : '';
}

const Object _sentinel = Object();
