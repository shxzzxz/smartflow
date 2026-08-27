import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'reimbursement_form_view_model.g.dart';

final _logger = Logger('feature.transaction.reimbursement_form');

@riverpod
class ReimbursementReceiptFormViewModel
    extends _$ReimbursementReceiptFormViewModel {
  @override
  Future<ReimbursementReceiptFormState> build(
    String advanceTransactionId,
  ) async {
    final base = await _loadBase(ref, advanceTransactionId);
    if (base == null) {
      return ReimbursementReceiptFormState.notFound(accounts: const []);
    }
    if (base.receivableAccountId == null || base.outstanding == null) {
      return ReimbursementReceiptFormState.notEditable(accounts: base.accounts);
    }
    return ReimbursementReceiptFormState.loaded(
      accounts: base.accounts,
      outstanding: base.outstanding!,
      receivableAccountId: base.receivableAccountId!,
      receiveAccountId: base.defaultSettlementAccountId,
      settlementAllocations: base.defaultSettlementAllocations,
      occurredAt: DateTime.now(),
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

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('报销到账表单尚未加载');
    }
    final amount = _parsePositiveMoney(amountText);
    if (amount == null) return _invalidCommand('请输入有效到账金额');
    final receiveAccountId = _selectedId(
      current.receiveAccountId,
      current.accounts,
    );
    if (receiveAccountId == null) return _invalidCommand('请选择到账账户');
    final settlements = _resolveSettlementAllocations(
      current,
      accountId: receiveAccountId,
      amount: amount,
    );
    if (sumAllocations(settlements) != amount) {
      return _invalidCommand('请完成到账账户分配');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(
        _logger,
        'Reimbursement receipt submit',
        () async {
          await ref
              .read(transactionPostingAppServiceProvider)
              .createReimbursementReceipt(
                CreateReimbursementReceiptCommand(
                  amount: amount,
                  advanceTransactionId: advanceTransactionId,
                  receivableAccountId: current.receivableAccountId!,
                  settlementAllocations: settlements,
                  occurredAt: current.occurredAt,
                  note: trimToNull(noteText),
                ),
              );
          _invalidateAfterSubmit(ref, advanceTransactionId);
        },
      );
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _update(
    ReimbursementReceiptFormState Function(ReimbursementReceiptFormState)
    update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }
}

@riverpod
class ReimbursementCloseFormViewModel
    extends _$ReimbursementCloseFormViewModel {
  @override
  Future<ReimbursementCloseFormState> build(String advanceTransactionId) async {
    final base = await _loadBase(ref, advanceTransactionId);
    if (base == null) {
      return ReimbursementCloseFormState.notFound(accounts: const []);
    }
    if (base.receivableAccountId == null || base.outstanding == null) {
      return ReimbursementCloseFormState.notEditable(accounts: base.accounts);
    }
    return ReimbursementCloseFormState.loaded(
      accounts: base.accounts,
      categoryAccounts: base.categoryAccounts,
      availableCategoryAllocations: base.availableCategoryAllocations,
      outstanding: base.outstanding!,
      receivableAccountId: base.receivableAccountId!,
      receiveAccountId: base.defaultSettlementAccountId,
      settlementAllocations: base.defaultSettlementAllocations,
      occurredAt: DateTime.now(),
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
    if (current == null || !current.isLoaded) {
      return _invalidCommand('结束报销表单尚未加载');
    }
    final amount = Money.tryParse(amountText);
    if (amount == null || amount.minorUnits < 0) {
      return _invalidCommand('请输入有效实收金额');
    }
    final receiveAccountId = amount.minorUnits > 0
        ? _selectedId(current.receiveAccountId, current.accounts)
        : current.receivableAccountId;
    if (receiveAccountId == null) return _invalidCommand('请选择到账账户');
    final settlements = _resolveSettlementAllocations(
      current,
      accountId: receiveAccountId,
      amount: amount,
    );
    if (sumAllocations(settlements) != amount) {
      return _invalidCommand('请完成到账账户分配');
    }
    final gaps = _resolveGapExpenseAllocations(current, amount);
    if (gaps == null) return _invalidCommand('请完成差额分类分配');

    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Reimbursement close submit', () async {
        await ref
            .read(transactionPostingAppServiceProvider)
            .closeReimbursement(
              CloseReimbursementCommand(
                actualReceivedAmount: amount,
                advanceTransactionId: advanceTransactionId,
                receivableAccountId: current.receivableAccountId!,
                settlementAllocations: settlements,
                gapExpenseAllocations: gaps,
                occurredAt: current.occurredAt,
                note: trimToNull(noteText),
              ),
            );
        _invalidateAfterSubmit(ref, advanceTransactionId);
      });
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _update(
    ReimbursementCloseFormState Function(ReimbursementCloseFormState) update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }
}

@riverpod
class ReimbursementFormViewModel extends _$ReimbursementFormViewModel {
  @override
  Future<ReimbursementFormState> build(String advanceTransactionId) async {
    final base = await _loadUnifiedBase(ref, advanceTransactionId);
    if (base == null) {
      return ReimbursementFormState.notFound(accounts: const []);
    }
    if (base.receivableAccountId == null || base.outstanding == null) {
      return ReimbursementFormState.notEditable(accounts: base.accounts);
    }
    return ReimbursementFormState.loaded(
      accounts: base.accounts,
      categoryAccounts: base.categoryAccounts,
      availableCategoryAllocations: base.availableCategoryAllocations,
      outstanding: base.outstanding!,
      receivableAccountId: base.receivableAccountId!,
      receiveAccountId: base.defaultSettlementAccountId,
      settlementAllocations: base.defaultSettlementAllocations,
      occurredAt: DateTime.now(),
      mode: ReimbursementFormMode.close,
    );
  }

  void setMode(ReimbursementFormMode mode) =>
      _update((state) => state.copyWith(mode: mode));

  void setCloseReimbursement(bool value) => setMode(
    value ? ReimbursementFormMode.close : ReimbursementFormMode.receipt,
  );

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
    if (current == null || !current.isLoaded) {
      return _invalidCommand('报销表单尚未加载');
    }
    final amount = Money.tryParse(amountText);
    if (amount == null) {
      return _invalidCommand(current.isClose ? '请输入有效实收金额' : '请输入有效到账金额');
    }

    final receiveAccountId = _selectedId(
      current.receiveAccountId,
      current.accounts,
    );
    if (current.isClose) {
      if (amount.minorUnits < 0) {
        return _invalidCommand('请输入有效实收金额');
      }
      final resolvedAccountId = amount.minorUnits > 0
          ? receiveAccountId
          : current.receivableAccountId;
      if (resolvedAccountId == null) {
        return _invalidCommand('请选择到账账户');
      }
      final settlements = _resolveSettlementAllocations(
        current,
        accountId: resolvedAccountId,
        amount: amount,
      );
      if (sumAllocations(settlements) != amount) {
        return _invalidCommand('请完成到账账户分配');
      }
      final gaps = _resolveGapExpenseAllocations(current, amount);
      if (gaps == null) return _invalidCommand('请完成差额分类分配');
      return _submitClose(
        current,
        amount: amount,
        settlementAllocations: settlements,
        gapExpenseAllocations: gaps,
        noteText: noteText,
      );
    }

    if (amount.minorUnits <= 0) {
      return _invalidCommand('请输入有效到账金额');
    }
    final outstanding = current.outstanding;
    if (outstanding != null && amount.minorUnits > outstanding.minorUnits) {
      return _invalidCommand('到账金额不能超过剩余应收');
    }
    if (receiveAccountId == null) {
      return _invalidCommand('请选择到账账户');
    }
    final settlements = _resolveSettlementAllocations(
      current,
      accountId: receiveAccountId,
      amount: amount,
    );
    if (sumAllocations(settlements) != amount) {
      return _invalidCommand('请完成到账账户分配');
    }
    return _submitReceipt(
      current,
      amount: amount,
      settlementAllocations: settlements,
      noteText: noteText,
    );
  }

  Future<SubmitOutcome> _submitReceipt(
    ReimbursementFormState current, {
    required Money amount,
    required List<AccountAmountAllocation> settlementAllocations,
    required String noteText,
  }) async {
    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(
        _logger,
        'Reimbursement receipt submit',
        () async {
          await ref
              .read(transactionPostingAppServiceProvider)
              .createReimbursementReceipt(
                CreateReimbursementReceiptCommand(
                  amount: amount,
                  advanceTransactionId: advanceTransactionId,
                  receivableAccountId: current.receivableAccountId!,
                  settlementAllocations: settlementAllocations,
                  occurredAt: current.occurredAt,
                  note: trimToNull(noteText),
                ),
              );
          _invalidateAfterSubmit(ref, advanceTransactionId);
        },
      );
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  Future<SubmitOutcome> _submitClose(
    ReimbursementFormState current, {
    required Money amount,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    required String noteText,
  }) async {
    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Reimbursement close submit', () async {
        await ref
            .read(transactionPostingAppServiceProvider)
            .closeReimbursement(
              CloseReimbursementCommand(
                actualReceivedAmount: amount,
                advanceTransactionId: advanceTransactionId,
                receivableAccountId: current.receivableAccountId!,
                settlementAllocations: settlementAllocations,
                gapExpenseAllocations: gapExpenseAllocations,
                occurredAt: current.occurredAt,
                note: trimToNull(noteText),
              ),
            );
        _invalidateAfterSubmit(ref, advanceTransactionId);
      });
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  void _update(ReimbursementFormState Function(ReimbursementFormState) update) {
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

enum ReimbursementFormStatus { loaded, notFound, notEditable }

enum ReimbursementFormMode { receipt, close }

class ReimbursementFormState extends _ReimbursementFormState {
  const ReimbursementFormState({
    required super.status,
    required super.accounts,
    required super.occurredAt,
    required super.submitting,
    required this.mode,
    super.outstanding,
    super.receivableAccountId,
    super.receiveAccountId,
    super.categoryAccounts,
    super.availableCategoryAllocations,
    super.settlementAllocations,
    super.gapExpenseAllocations,
  });

  factory ReimbursementFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required DateTime occurredAt,
    required ReimbursementFormMode mode,
    String? receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
    List<Account> categoryAccounts = const [],
    List<AccountAmountAllocation> availableCategoryAllocations = const [],
  }) {
    return ReimbursementFormState(
      status: ReimbursementFormStatus.loaded,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      settlementAllocations: settlementAllocations,
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      occurredAt: occurredAt,
      submitting: false,
      mode: mode,
    );
  }

  factory ReimbursementFormState.notFound({required List<Account> accounts}) {
    return ReimbursementFormState._empty(
      status: ReimbursementFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory ReimbursementFormState.notEditable({
    required List<Account> accounts,
  }) {
    return ReimbursementFormState._empty(
      status: ReimbursementFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory ReimbursementFormState._empty({
    required ReimbursementFormStatus status,
    required List<Account> accounts,
  }) {
    return ReimbursementFormState(
      status: status,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
      mode: ReimbursementFormMode.close,
    );
  }

  final ReimbursementFormMode mode;

  bool get isClose => mode == ReimbursementFormMode.close;

  ReimbursementFormState copyWith({
    ReimbursementFormMode? mode,
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    Object? settlementAllocations = _sentinel,
    Object? gapExpenseAllocations = _sentinel,
    bool? submitting,
  }) {
    return ReimbursementFormState(
      status: status,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId == _sentinel
          ? this.receiveAccountId
          : receiveAccountId as String?,
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      settlementAllocations: settlementAllocations == _sentinel
          ? this.settlementAllocations
          : settlementAllocations as List<AccountAmountAllocation>?,
      gapExpenseAllocations: gapExpenseAllocations == _sentinel
          ? this.gapExpenseAllocations
          : gapExpenseAllocations as List<AccountAmountAllocation>?,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
      mode: mode ?? this.mode,
    );
  }
}

class ReimbursementReceiptFormState extends _ReimbursementFormState {
  const ReimbursementReceiptFormState({
    required super.status,
    required super.accounts,
    required super.occurredAt,
    required super.submitting,
    super.outstanding,
    super.receivableAccountId,
    super.receiveAccountId,
    super.settlementAllocations,
  });

  factory ReimbursementReceiptFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required DateTime occurredAt,
    String? receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
  }) {
    return ReimbursementReceiptFormState(
      status: ReimbursementFormStatus.loaded,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      settlementAllocations: settlementAllocations,
      occurredAt: occurredAt,
      submitting: false,
    );
  }

  factory ReimbursementReceiptFormState.notFound({
    required List<Account> accounts,
  }) {
    return ReimbursementReceiptFormState._empty(
      status: ReimbursementFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory ReimbursementReceiptFormState.notEditable({
    required List<Account> accounts,
  }) {
    return ReimbursementReceiptFormState._empty(
      status: ReimbursementFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory ReimbursementReceiptFormState._empty({
    required ReimbursementFormStatus status,
    required List<Account> accounts,
  }) {
    return ReimbursementReceiptFormState(
      status: status,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
    );
  }

  ReimbursementReceiptFormState copyWith({
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    Object? settlementAllocations = _sentinel,
    bool? submitting,
  }) {
    return ReimbursementReceiptFormState(
      status: status,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId == _sentinel
          ? this.receiveAccountId
          : receiveAccountId as String?,
      settlementAllocations: settlementAllocations == _sentinel
          ? this.settlementAllocations
          : settlementAllocations as List<AccountAmountAllocation>?,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
    );
  }
}

class ReimbursementCloseFormState extends _ReimbursementFormState {
  const ReimbursementCloseFormState({
    required super.status,
    required super.accounts,
    required super.occurredAt,
    required super.submitting,
    super.outstanding,
    super.receivableAccountId,
    super.receiveAccountId,
    super.categoryAccounts,
    super.availableCategoryAllocations,
    super.settlementAllocations,
    super.gapExpenseAllocations,
  });

  factory ReimbursementCloseFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required DateTime occurredAt,
    String? receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
    List<Account> categoryAccounts = const [],
    List<AccountAmountAllocation> availableCategoryAllocations = const [],
  }) {
    return ReimbursementCloseFormState(
      status: ReimbursementFormStatus.loaded,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      settlementAllocations: settlementAllocations,
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      occurredAt: occurredAt,
      submitting: false,
    );
  }

  factory ReimbursementCloseFormState.notFound({
    required List<Account> accounts,
  }) {
    return ReimbursementCloseFormState._empty(
      status: ReimbursementFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory ReimbursementCloseFormState.notEditable({
    required List<Account> accounts,
  }) {
    return ReimbursementCloseFormState._empty(
      status: ReimbursementFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory ReimbursementCloseFormState._empty({
    required ReimbursementFormStatus status,
    required List<Account> accounts,
  }) {
    return ReimbursementCloseFormState(
      status: status,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
    );
  }

  ReimbursementCloseFormState copyWith({
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    Object? settlementAllocations = _sentinel,
    Object? gapExpenseAllocations = _sentinel,
    bool? submitting,
  }) {
    return ReimbursementCloseFormState(
      status: status,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId == _sentinel
          ? this.receiveAccountId
          : receiveAccountId as String?,
      categoryAccounts: categoryAccounts,
      availableCategoryAllocations: availableCategoryAllocations,
      settlementAllocations: settlementAllocations == _sentinel
          ? this.settlementAllocations
          : settlementAllocations as List<AccountAmountAllocation>?,
      gapExpenseAllocations: gapExpenseAllocations == _sentinel
          ? this.gapExpenseAllocations
          : gapExpenseAllocations as List<AccountAmountAllocation>?,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
    );
  }
}

abstract class _ReimbursementFormState {
  const _ReimbursementFormState({
    required this.status,
    required this.accounts,
    required this.occurredAt,
    required this.submitting,
    this.outstanding,
    this.receivableAccountId,
    this.receiveAccountId,
    this.categoryAccounts = const [],
    this.availableCategoryAllocations = const [],
    this.settlementAllocations,
    this.gapExpenseAllocations,
  });

  final ReimbursementFormStatus status;
  final List<Account> accounts;
  final Money? outstanding;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final List<Account> categoryAccounts;
  final List<AccountAmountAllocation> availableCategoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;
  final List<AccountAmountAllocation>? gapExpenseAllocations;
  final DateTime occurredAt;
  final bool submitting;

  bool get isLoaded => status == ReimbursementFormStatus.loaded;
}

class _ReimbursementBase {
  const _ReimbursementBase({
    required this.accounts,
    this.outstanding,
    this.receivableAccountId,
    this.defaultSettlementAccountId,
    this.defaultSettlementAllocations,
    this.categoryAccounts = const [],
    this.availableCategoryAllocations = const [],
  });

  final List<Account> accounts;
  final Money? outstanding;
  final String? receivableAccountId;
  final String? defaultSettlementAccountId;
  final List<AccountAmountAllocation>? defaultSettlementAllocations;
  final List<Account> categoryAccounts;
  final List<AccountAmountAllocation> availableCategoryAllocations;
}

Future<_ReimbursementBase?> _loadBase(
  Ref ref,
  String advanceTransactionId,
) async {
  final accounts = await ref.watch(
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.settlement,
    ).future,
  );
  final accountsById = await ref.watch(accountsByIdProvider.future);
  final detail = await ref.watch(
    transactionDetailProvider(advanceTransactionId).future,
  );
  if (detail == null) return null;
  return _ReimbursementBase(
    accounts: accounts,
    outstanding: detail.reimbursementSummary?.outstanding,
    receivableAccountId: reimbursementReceivableAccountId(detail, accountsById),
    defaultSettlementAccountId: effectiveRefundToAccountId(
      selectedId: null,
      parentSettlementAccountId: parentSettlementAccountIdForRefund(
        detail,
        accountsById,
      ),
      accounts: accounts,
    ),
    defaultSettlementAllocations: defaultSettlementAllocationsForRefund(
      detail: detail,
      accounts: accounts,
    ),
    availableCategoryAllocations: detail
        .remainingRefundableCategoryAllocations(),
    categoryAccounts: _accountsForAllocations(
      detail.refundableCategoryAllocations,
      accountsById,
    ),
  );
}

Future<_ReimbursementBase?> _loadUnifiedBase(
  Ref ref,
  String advanceTransactionId,
) async {
  final accounts = await ref.watch(
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.settlement,
    ).future,
  );
  final accountLookup = await ref.watch(accountLookupProvider.future);
  final detail = await ref.watch(
    transactionDetailProvider(advanceTransactionId).future,
  );
  if (detail == null) return null;
  return _ReimbursementBase(
    accounts: accounts,
    outstanding: detail.reimbursementSummary?.outstanding,
    receivableAccountId: reimbursementReceivableAccountId(
      detail,
      accountLookup.byId,
    ),
    defaultSettlementAccountId: effectiveRefundToAccountId(
      selectedId: null,
      parentSettlementAccountId: parentSettlementAccountIdForRefund(
        detail,
        accountLookup.byId,
      ),
      accounts: accounts,
    ),
    defaultSettlementAllocations: defaultSettlementAllocationsForRefund(
      detail: detail,
      accounts: accounts,
    ),
    availableCategoryAllocations: detail
        .remainingRefundableCategoryAllocations(),
    categoryAccounts: _accountsForAllocations(
      detail.refundableCategoryAllocations,
      accountLookup.byId,
    ),
  );
}

void _invalidateAfterSubmit(Ref ref, String advanceTransactionId) {
  ref.invalidate(transactionDetailProvider(advanceTransactionId));
  ref.invalidate(accountsByIdProvider);
  ref.invalidate(
    accountsForSelectionPurposeProvider(AccountSelectionPurpose.settlement),
  );
}

SubmitOutcome _invalidCommand(String message) {
  return SubmitOutcome.failure(
    UiError(
      code: LedgerErrorCode.transactionInvalidCommand.code,
      message: message,
    ),
  );
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return accounts.isEmpty ? null : accounts.first.id;
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}

List<AccountAmountAllocation> _resolveSettlementAllocations(
  _ReimbursementFormState state, {
  required String accountId,
  required Money amount,
}) {
  final allocations = state.settlementAllocations;
  if (amount.minorUnits == 0) {
    return singleAllocation(accountId: accountId, amount: amount);
  }
  return allocations == null
      ? singleAllocation(accountId: accountId, amount: amount)
      : patchAllocations(current: allocations, total: amount);
}

List<AccountAmountAllocation>? _resolveGapExpenseAllocations(
  _ReimbursementFormState state,
  Money actual,
) {
  final outstanding = state.outstanding;
  if (outstanding == null) return null;
  final shortfall = outstanding - actual;
  if (shortfall.minorUnits <= 0) return const [];
  final allocations = switch (state.gapExpenseAllocations) {
    final allocations? => patchAllocations(
      current: allocations,
      total: shortfall,
    ),
    null when state.availableCategoryAllocations.length == 1 => [
      state.availableCategoryAllocations.single.copyWith(amount: shortfall),
    ],
    null => null,
  };
  if (allocations == null || sumAllocations(allocations) != shortfall) {
    return null;
  }
  if (!allocationsFitAvailable(
    requested: allocations,
    available: state.availableCategoryAllocations,
  )) {
    return null;
  }
  return allocations;
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
