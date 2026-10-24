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

part 'advance_form_view_model.g.dart';

final _logger = Logger('feature.transaction.advance_form');

@riverpod
class AdvanceCollectionFormViewModel extends _$AdvanceCollectionFormViewModel {
  @override
  Future<AdvanceCollectionFormState> build(String advanceTransactionId) async {
    final base = await _loadBase(ref, advanceTransactionId);
    if (base == null) {
      return AdvanceCollectionFormState.notFound(accounts: const []);
    }
    if (base.accountManaged ||
        base.receivableAccountId == null ||
        base.outstanding == null) {
      return AdvanceCollectionFormState.notEditable(accounts: base.accounts);
    }
    return AdvanceCollectionFormState.loaded(
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
    final current = state.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('垫付到账表单尚未加载');
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
      return await guardSubmit(_logger, 'Advance receipt submit', () async {
        await ref
            .read(transactionPostingAppServiceProvider)
            .createAdvanceCollection(
              CreateAdvanceCollectionCommand(
                amount: amount,
                advanceTransactionId: advanceTransactionId,
                receivableAccountId: current.receivableAccountId!,
                settlementAllocations: settlements,
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
    AdvanceCollectionFormState Function(AdvanceCollectionFormState) update,
  ) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }
}

@riverpod
class AdvanceSettlementFormViewModel extends _$AdvanceSettlementFormViewModel {
  @override
  Future<AdvanceSettlementFormState> build(String advanceTransactionId) async {
    final base = await _loadBase(ref, advanceTransactionId);
    if (base == null) {
      return AdvanceSettlementFormState.notFound(accounts: const []);
    }
    if (base.accountManaged ||
        base.receivableAccountId == null ||
        base.outstanding == null) {
      return AdvanceSettlementFormState.notEditable(accounts: base.accounts);
    }
    return AdvanceSettlementFormState.loaded(
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

  void setSelfBorne(bool value) => _update(
    (state) => state.copyWith(
      shortfallKind: value
          ? AdvanceShortfallKind.selfBorne
          : AdvanceShortfallKind.badDebt,
    ),
  );

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
  }) async {
    final current = state.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('垫付结清表单尚未加载');
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
      return await guardSubmit(_logger, 'Advance close submit', () async {
        await ref
            .read(transactionPostingAppServiceProvider)
            .settleAdvance(
              CreateAdvanceSettlementCommand(
                actualReceivedAmount: amount,
                advanceTransactionId: advanceTransactionId,
                receivableAccountId: current.receivableAccountId!,
                settlementAllocations: settlements,
                gapExpenseAllocations: gaps,
                shortfallKind: current.shortfallKind,
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
    AdvanceSettlementFormState Function(AdvanceSettlementFormState) update,
  ) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }
}

@riverpod
class AdvanceFormViewModel extends _$AdvanceFormViewModel {
  @override
  Future<AdvanceFormState> build(String advanceTransactionId) async {
    final base = await _loadUnifiedBase(ref, advanceTransactionId);
    if (base == null) {
      return AdvanceFormState.notFound(accounts: const []);
    }
    if (base.accountManaged ||
        base.receivableAccountId == null ||
        base.outstanding == null) {
      return AdvanceFormState.notEditable(accounts: base.accounts);
    }
    return AdvanceFormState.loaded(
      accounts: base.accounts,
      categoryAccounts: base.categoryAccounts,
      availableCategoryAllocations: base.availableCategoryAllocations,
      outstanding: base.outstanding!,
      receivableAccountId: base.receivableAccountId!,
      receiveAccountId: base.defaultSettlementAccountId,
      settlementAllocations: base.defaultSettlementAllocations,
      occurredAt: DateTime.now(),
      mode: AdvanceFormMode.close,
    );
  }

  void setMode(AdvanceFormMode mode) =>
      _update((state) => state.copyWith(mode: mode));

  void setCloseAdvance(bool value) =>
      setMode(value ? AdvanceFormMode.close : AdvanceFormMode.receipt);

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

  void setSelfBorne(bool value) => _update(
    (state) => state.copyWith(
      shortfallKind: value
          ? AdvanceShortfallKind.selfBorne
          : AdvanceShortfallKind.badDebt,
    ),
  );

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
  }) async {
    final current = state.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('垫付表单尚未加载');
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
    AdvanceFormState current, {
    required Money amount,
    required List<AccountAmountAllocation> settlementAllocations,
    required String noteText,
  }) async {
    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Advance receipt submit', () async {
        await ref
            .read(transactionPostingAppServiceProvider)
            .createAdvanceCollection(
              CreateAdvanceCollectionCommand(
                amount: amount,
                advanceTransactionId: advanceTransactionId,
                receivableAccountId: current.receivableAccountId!,
                settlementAllocations: settlementAllocations,
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

  Future<SubmitOutcome> _submitClose(
    AdvanceFormState current, {
    required Money amount,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    required String noteText,
  }) async {
    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Advance close submit', () async {
        await ref
            .read(transactionPostingAppServiceProvider)
            .settleAdvance(
              CreateAdvanceSettlementCommand(
                actualReceivedAmount: amount,
                advanceTransactionId: advanceTransactionId,
                receivableAccountId: current.receivableAccountId!,
                settlementAllocations: settlementAllocations,
                gapExpenseAllocations: gapExpenseAllocations,
                shortfallKind: current.shortfallKind,
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

  void _update(AdvanceFormState Function(AdvanceFormState) update) {
    final current = state.value;
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

class AccountAdvanceFormTarget {
  const AccountAdvanceFormTarget({
    required this.accountId,
    required this.scenario,
  });

  final String accountId;
  final AdvanceScenario scenario;

  @override
  bool operator ==(Object other) =>
      other is AccountAdvanceFormTarget &&
      other.accountId == accountId &&
      other.scenario == scenario;

  @override
  int get hashCode => Object.hash(accountId, scenario);
}

@riverpod
class AccountAdvanceFormViewModel extends _$AccountAdvanceFormViewModel {
  @override
  Future<AccountAdvanceFormState> build(AccountAdvanceFormTarget target) async {
    final accounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).future,
    );
    final accountLookup = await ref.watch(accountLookupProvider.future);
    final account = accountLookup.byId[target.accountId];
    if (account == null ||
        !accountMatchesUsage(account, AccountUsage.receivable)) {
      return AccountAdvanceFormState.notFound(
        target: target,
        accounts: accounts,
      );
    }
    return AccountAdvanceFormState.loaded(
      target: target,
      accounts: accounts,
      receiveAccountId: _selectedId(null, accounts),
      occurredAt: DateTime.now(),
    );
  }

  void setMode(AccountAdvanceFormMode value) =>
      _update((state) => state.copyWith(mode: value));

  void setSettlement(bool value) => setMode(
    value
        ? AccountAdvanceFormMode.settlement
        : AccountAdvanceFormMode.collection,
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

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('账户垫付表单尚未加载');
    }
    final amount = _parsePositiveMoney(amountText);
    if (amount == null) {
      return _invalidCommand(current.isSettlement ? '请输入有效实收金额' : '请输入有效到账金额');
    }
    final receiveAccountId = _selectedId(
      current.receiveAccountId,
      current.accounts,
    );
    if (receiveAccountId == null) {
      return _invalidCommand('请选择到账账户');
    }
    final settlements = current.settlementAllocations == null
        ? singleAllocation(accountId: receiveAccountId, amount: amount)
        : patchAllocations(
            current: current.settlementAllocations!,
            total: amount,
          );
    if (sumAllocations(settlements) != amount) {
      return _invalidCommand('请完成到账账户分配');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Account advance submit', () async {
        final posting = ref.read(transactionPostingAppServiceProvider);
        final note = trimToNull(noteText);
        switch (current.mode) {
          case AccountAdvanceFormMode.collection:
            await posting.createAdvanceCollection(
              CreateAdvanceCollectionCommand.account(
                amount: amount,
                receivableAccountId: current.target.accountId,
                settlementAllocations: settlements,
                occurredAt: current.occurredAt,
                scenario: current.target.scenario,
                note: note,
              ),
            );
          case AccountAdvanceFormMode.settlement:
            await posting.settleAdvance(
              CreateAdvanceSettlementCommand.account(
                actualReceivedAmount: amount,
                receivableAccountId: current.target.accountId,
                settlementAllocations: settlements,
                gapExpenseAllocations: const [],
                occurredAt: current.occurredAt,
                scenario: current.target.scenario,
                note: note,
              ),
            );
        }
        ref.invalidate(accountsByIdProvider);
        ref.invalidate(accountLookupProvider);
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

  void _update(
    AccountAdvanceFormState Function(AccountAdvanceFormState) update,
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

enum AccountAdvanceFormStatus { loaded, notFound }

enum AccountAdvanceFormMode { collection, settlement }

class AccountAdvanceFormState {
  AccountAdvanceFormState({
    required this.status,
    required this.target,
    required List<Account> accounts,
    required this.occurredAt,
    required this.submitting,
    required this.mode,
    this.receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
  }) : accounts = List.unmodifiable(accounts),
       settlementAllocations = settlementAllocations == null
           ? null
           : List.unmodifiable(settlementAllocations);

  factory AccountAdvanceFormState.loaded({
    required AccountAdvanceFormTarget target,
    required List<Account> accounts,
    required DateTime occurredAt,
    String? receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
  }) {
    return AccountAdvanceFormState(
      status: AccountAdvanceFormStatus.loaded,
      target: target,
      accounts: accounts,
      receiveAccountId: receiveAccountId,
      settlementAllocations: settlementAllocations,
      occurredAt: occurredAt,
      submitting: false,
      mode: AccountAdvanceFormMode.collection,
    );
  }

  factory AccountAdvanceFormState.notFound({
    required AccountAdvanceFormTarget target,
    required List<Account> accounts,
  }) {
    return AccountAdvanceFormState(
      status: AccountAdvanceFormStatus.notFound,
      target: target,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
      mode: AccountAdvanceFormMode.collection,
    );
  }

  final AccountAdvanceFormStatus status;
  final AccountAdvanceFormTarget target;
  final List<Account> accounts;
  final String? receiveAccountId;
  final List<AccountAmountAllocation>? settlementAllocations;
  final DateTime occurredAt;
  final bool submitting;
  final AccountAdvanceFormMode mode;

  bool get isLoaded => status == AccountAdvanceFormStatus.loaded;
  bool get isSettlement => mode == AccountAdvanceFormMode.settlement;

  String get actionLabel => switch (target.scenario) {
    AdvanceScenario.reimbursement => '报销',
    AdvanceScenario.aa => '垫付收回',
    AdvanceScenario.onBehalf => '代付收回',
  };

  AccountAdvanceFormState copyWith({
    AccountAdvanceFormMode? mode,
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    Object? settlementAllocations = _sentinel,
    bool? submitting,
  }) {
    return AccountAdvanceFormState(
      status: status,
      target: target,
      accounts: accounts,
      receiveAccountId: receiveAccountId == _sentinel
          ? this.receiveAccountId
          : receiveAccountId as String?,
      settlementAllocations: settlementAllocations == _sentinel
          ? this.settlementAllocations
          : settlementAllocations as List<AccountAmountAllocation>?,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
      mode: mode ?? this.mode,
    );
  }
}

enum AdvanceFormStatus { loaded, notFound, notEditable }

enum AdvanceFormMode { receipt, close }

class AdvanceFormState extends _AdvanceFormState {
  const AdvanceFormState({
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
    super.shortfallKind,
  });

  factory AdvanceFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required DateTime occurredAt,
    required AdvanceFormMode mode,
    String? receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
    List<Account> categoryAccounts = const [],
    List<AccountAmountAllocation> availableCategoryAllocations = const [],
  }) {
    return AdvanceFormState(
      status: AdvanceFormStatus.loaded,
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

  factory AdvanceFormState.notFound({required List<Account> accounts}) {
    return AdvanceFormState._empty(
      status: AdvanceFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory AdvanceFormState.notEditable({required List<Account> accounts}) {
    return AdvanceFormState._empty(
      status: AdvanceFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory AdvanceFormState._empty({
    required AdvanceFormStatus status,
    required List<Account> accounts,
  }) {
    return AdvanceFormState(
      status: status,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
      mode: AdvanceFormMode.close,
    );
  }

  final AdvanceFormMode mode;

  bool get isClose => mode == AdvanceFormMode.close;

  AdvanceFormState copyWith({
    AdvanceFormMode? mode,
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    Object? settlementAllocations = _sentinel,
    Object? gapExpenseAllocations = _sentinel,
    AdvanceShortfallKind? shortfallKind,
    bool? submitting,
  }) {
    return AdvanceFormState(
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
      shortfallKind: shortfallKind ?? this.shortfallKind,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
      mode: mode ?? this.mode,
    );
  }
}

class AdvanceCollectionFormState extends _AdvanceFormState {
  const AdvanceCollectionFormState({
    required super.status,
    required super.accounts,
    required super.occurredAt,
    required super.submitting,
    super.outstanding,
    super.receivableAccountId,
    super.receiveAccountId,
    super.settlementAllocations,
  });

  factory AdvanceCollectionFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required DateTime occurredAt,
    String? receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
  }) {
    return AdvanceCollectionFormState(
      status: AdvanceFormStatus.loaded,
      accounts: accounts,
      outstanding: outstanding,
      receivableAccountId: receivableAccountId,
      receiveAccountId: receiveAccountId,
      settlementAllocations: settlementAllocations,
      occurredAt: occurredAt,
      submitting: false,
    );
  }

  factory AdvanceCollectionFormState.notFound({
    required List<Account> accounts,
  }) {
    return AdvanceCollectionFormState._empty(
      status: AdvanceFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory AdvanceCollectionFormState.notEditable({
    required List<Account> accounts,
  }) {
    return AdvanceCollectionFormState._empty(
      status: AdvanceFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory AdvanceCollectionFormState._empty({
    required AdvanceFormStatus status,
    required List<Account> accounts,
  }) {
    return AdvanceCollectionFormState(
      status: status,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
    );
  }

  AdvanceCollectionFormState copyWith({
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    Object? settlementAllocations = _sentinel,
    bool? submitting,
  }) {
    return AdvanceCollectionFormState(
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

class AdvanceSettlementFormState extends _AdvanceFormState {
  const AdvanceSettlementFormState({
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
    super.shortfallKind,
  });

  factory AdvanceSettlementFormState.loaded({
    required List<Account> accounts,
    required Money outstanding,
    required String receivableAccountId,
    required DateTime occurredAt,
    String? receiveAccountId,
    List<AccountAmountAllocation>? settlementAllocations,
    List<Account> categoryAccounts = const [],
    List<AccountAmountAllocation> availableCategoryAllocations = const [],
  }) {
    return AdvanceSettlementFormState(
      status: AdvanceFormStatus.loaded,
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

  factory AdvanceSettlementFormState.notFound({
    required List<Account> accounts,
  }) {
    return AdvanceSettlementFormState._empty(
      status: AdvanceFormStatus.notFound,
      accounts: accounts,
    );
  }

  factory AdvanceSettlementFormState.notEditable({
    required List<Account> accounts,
  }) {
    return AdvanceSettlementFormState._empty(
      status: AdvanceFormStatus.notEditable,
      accounts: accounts,
    );
  }

  factory AdvanceSettlementFormState._empty({
    required AdvanceFormStatus status,
    required List<Account> accounts,
  }) {
    return AdvanceSettlementFormState(
      status: status,
      accounts: accounts,
      occurredAt: DateTime.now(),
      submitting: false,
    );
  }

  AdvanceSettlementFormState copyWith({
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    Object? settlementAllocations = _sentinel,
    Object? gapExpenseAllocations = _sentinel,
    AdvanceShortfallKind? shortfallKind,
    bool? submitting,
  }) {
    return AdvanceSettlementFormState(
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
      shortfallKind: shortfallKind ?? this.shortfallKind,
      occurredAt: occurredAt ?? this.occurredAt,
      submitting: submitting ?? this.submitting,
    );
  }
}

abstract class _AdvanceFormState {
  const _AdvanceFormState({
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
    this.shortfallKind = AdvanceShortfallKind.selfBorne,
  });

  final AdvanceFormStatus status;
  final List<Account> accounts;
  final Money? outstanding;
  final String? receivableAccountId;
  final String? receiveAccountId;
  final List<Account> categoryAccounts;
  final List<AccountAmountAllocation> availableCategoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;
  final List<AccountAmountAllocation>? gapExpenseAllocations;
  final AdvanceShortfallKind shortfallKind;
  final DateTime occurredAt;
  final bool submitting;

  bool get isLoaded => status == AdvanceFormStatus.loaded;
}

class _AdvanceBase {
  const _AdvanceBase({
    required this.accounts,
    this.accountManaged = false,
    this.outstanding,
    this.receivableAccountId,
    this.defaultSettlementAccountId,
    this.defaultSettlementAllocations,
    this.categoryAccounts = const [],
    this.availableCategoryAllocations = const [],
  });

  final List<Account> accounts;
  final bool accountManaged;
  final Money? outstanding;
  final String? receivableAccountId;
  final String? defaultSettlementAccountId;
  final List<AccountAmountAllocation>? defaultSettlementAllocations;
  final List<Account> categoryAccounts;
  final List<AccountAmountAllocation> availableCategoryAllocations;
}

Future<_AdvanceBase?> _loadBase(Ref ref, String advanceTransactionId) async {
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
  return _AdvanceBase(
    accounts: accounts,
    accountManaged:
        detail.ownership?.advanceManagement == AdvanceManagement.account,
    outstanding: detail.advanceSummary?.outstanding,
    receivableAccountId: advanceReceivableAccountId(detail, accountsById),
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
    availableCategoryAllocations:
        detail.refundSummary?.remainingCategoryAllocations ?? const [],
    categoryAccounts: _accountsForAllocations(
      detail.refundSummary?.originalCategoryAllocations ?? const [],
      accountsById,
    ),
  );
}

Future<_AdvanceBase?> _loadUnifiedBase(
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
  return _AdvanceBase(
    accounts: accounts,
    accountManaged:
        detail.ownership?.advanceManagement == AdvanceManagement.account,
    outstanding: detail.advanceSummary?.outstanding,
    receivableAccountId: advanceReceivableAccountId(detail, accountLookup.byId),
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
    availableCategoryAllocations:
        detail.refundSummary?.remainingCategoryAllocations ?? const [],
    categoryAccounts: _accountsForAllocations(
      detail.refundSummary?.originalCategoryAllocations ?? const [],
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
  _AdvanceFormState state, {
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
  _AdvanceFormState state,
  Money actual,
) {
  final outstanding = state.outstanding;
  if (outstanding == null) return null;
  final shortfall = outstanding - actual;
  if (shortfall.minorUnits <= 0) return const [];
  if (state.shortfallKind == AdvanceShortfallKind.badDebt) return const [];
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
