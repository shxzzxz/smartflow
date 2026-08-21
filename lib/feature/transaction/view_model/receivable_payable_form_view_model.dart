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

part 'receivable_payable_form_view_model.g.dart';

final _logger = Logger('feature.transaction.receivable_payable_form');

enum ReceivablePayableFormKind { collection, badDebt, debtRelief }

class ReceivablePayableFormArgs {
  const ReceivablePayableFormArgs({
    required this.kind,
    this.accountId,
    this.transactionId,
  });

  final ReceivablePayableFormKind kind;
  final String? accountId;
  final String? transactionId;

  @override
  bool operator ==(Object other) =>
      other is ReceivablePayableFormArgs &&
      other.kind == kind &&
      other.accountId == accountId &&
      other.transactionId == transactionId;

  @override
  int get hashCode => Object.hash(kind, accountId, transactionId);
}

@riverpod
class ReceivablePayableFormViewModel extends _$ReceivablePayableFormViewModel {
  @override
  Future<ReceivablePayableFormState> build(
    ReceivablePayableFormArgs args,
  ) async {
    final accountsById = await ref.watch(accountsByIdProvider.future);
    final receiveAccounts =
        args.kind == ReceivablePayableFormKind.collection
            ? await ref.watch(
              accountsForSelectionPurposeProvider(
                AccountSelectionPurpose.fund,
              ).future,
            )
            : const <Account>[];
    final transactionId = args.transactionId;
    if (transactionId == null) {
      return ReceivablePayableFormState.loaded(
        kind: args.kind,
        receiveAccounts: receiveAccounts,
        accountId: args.accountId,
        receiveAccountId: _selectedId(null, receiveAccounts),
        occurredAt: DateTime.now(),
        amountText: '',
        interestText: '0.00',
        noteText: '',
        reducibleBalance: accountsById[args.accountId]?.balance ?? Money.zero(),
      );
    }

    final detail = await ref.watch(
      transactionDetailProvider(transactionId).future,
    );
    if (detail == null || !_matchesKind(detail.transaction.businessPurpose)) {
      return ReceivablePayableFormState.notFound(
        kind: args.kind,
        transactionId: transactionId,
        receiveAccounts: receiveAccounts,
      );
    }
    return _editState(detail, accountsById, receiveAccounts);
  }

  void setOccurredAt(DateTime value) =>
      _update((state) => state.copyWith(occurredAt: value));

  void setReceiveAccountId(String? value) =>
      _update((state) => state.copyWith(receiveAccountId: value));

  void setExcludeStats(bool value) =>
      _update((state) => state.copyWith(excludeStats: value));

  void setExcludeBudget(bool value) =>
      _update((state) => state.copyWith(excludeBudget: value));

  BalanceCrossingConfirmation? balanceCrossingConfirmation(String amountText) {
    final current = state.asData?.value;
    if (current == null ||
        !current.isLoaded ||
        current.kind != ReceivablePayableFormKind.collection) {
      return null;
    }
    final principal = _parsePositiveMoney(amountText);
    if (principal == null ||
        principal.minorUnits <= current.reducibleBalance.minorUnits) {
      return null;
    }
    return const BalanceCrossingConfirmation(
      title: '收回将超过当前应收',
      message: '提交后该应收账户余额将小于 0，是否继续？',
    );
  }

  Future<SubmitOutcome> submit({
    required String amountText,
    required String interestText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) {
      return _invalidCommand('表单尚未加载');
    }
    final amount = _parsePositiveMoney(amountText);
    if (amount == null) {
      return _invalidCommand('${current.amountLabel}必须大于 0');
    }
    final accountId = current.accountId;
    if (accountId == null) {
      return _invalidCommand(current.accountMissingMessage);
    }

    Money interest = Money.zero();
    String? receiveAccountId;
    if (current.kind == ReceivablePayableFormKind.collection) {
      final parsedInterest = _parseNonNegativeMoney(interestText);
      if (parsedInterest == null) {
        return _invalidCommand('利息不能小于 0');
      }
      interest = parsedInterest;
      receiveAccountId = _selectedId(
        current.receiveAccountId,
        current.receiveAccounts,
      );
      if (receiveAccountId == null) return _invalidCommand('请选择到账账户');
    }

    _update((state) => state.copyWith(submitting: true));
    try {
      return await guardSubmit(
        _logger,
        '${current.kind.name} form submit',
        () => _submitCommand(
          current: current,
          amount: amount,
          interest: interest,
          accountId: accountId,
          receiveAccountId: receiveAccountId,
          note: trimToNull(noteText),
        ),
      );
    } finally {
      _update((state) => state.copyWith(submitting: false));
    }
  }

  ReceivablePayableFormState _editState(
    TransactionDetail detail,
    Map<String, Account> accountsById,
    List<Account> receiveAccounts,
  ) {
    final transaction = detail.transaction;
    final amount = switch (args.kind) {
      ReceivablePayableFormKind.collection =>
        _detailAmount(
              detail,
              TransactionDetailType.receivableCollectionPrincipal,
            ) ??
            transaction.primaryAmount,
      ReceivablePayableFormKind.badDebt ||
      ReceivablePayableFormKind.debtRelief => transaction.primaryAmount,
    };
    final accountId = switch (args.kind) {
      ReceivablePayableFormKind.collection ||
      ReceivablePayableFormKind.badDebt => _entryForUsage(
        detail,
        accountsById,
        direction: EntryDirection.credit,
        usage: AccountUsage.receivable,
      ),
      ReceivablePayableFormKind.debtRelief => _entryForUsage(
        detail,
        accountsById,
        direction: EntryDirection.debit,
        usage: AccountUsage.liability,
      ),
    };
    final receiveAccountId =
        args.kind == ReceivablePayableFormKind.collection
            ? _entryForUsage(
              detail,
              accountsById,
              direction: EntryDirection.debit,
              usage: AccountUsage.fund,
            )
            : null;
    if (accountId == null ||
        (args.kind == ReceivablePayableFormKind.collection &&
            receiveAccountId == null)) {
      throw StateError(
        'Transaction ${transaction.id} has unresolvable account roles.',
      );
    }
    return ReceivablePayableFormState.loaded(
      kind: args.kind,
      transactionId: transaction.id,
      receiveAccounts: receiveAccounts,
      accountId: accountId,
      receiveAccountId: receiveAccountId,
      occurredAt: transaction.occurredAt,
      amountText: formatMoney(amount, style: MoneyFormatStyle.plain),
      interestText: formatMoney(
        _detailAmount(
              detail,
              TransactionDetailType.receivableCollectionInterest,
            ) ??
            Money.zero(),
        style: MoneyFormatStyle.plain,
      ),
      noteText: transaction.note ?? '',
      reducibleBalance:
          (accountsById[accountId]?.balance ?? Money.zero()) + amount,
      excludeStats: transaction.isExcludedFromStats,
      excludeBudget: transaction.isExcludedFromBudget,
    );
  }

  Future<void> _submitCommand({
    required ReceivablePayableFormState current,
    required Money amount,
    required Money interest,
    required String accountId,
    required String? receiveAccountId,
    required String? note,
  }) async {
    final posting =
        ref.read(transactionPostingAppServiceProvider)
            as ReceivableTransactionPostingAppService;
    final editing =
        ref.read(transactionEditAppServiceProvider)
            as ReceivableTransactionEditAppService;
    final transactionId = current.transactionId;
    switch (current.kind) {
      case ReceivablePayableFormKind.collection:
        if (transactionId == null) {
          await posting.createReceivableCollection(
            CreateReceivableCollectionCommand(
              principal: amount,
              interest: interest,
              receivableAccountId: accountId,
              receiveAccountId: receiveAccountId!,
              occurredAt: current.occurredAt,
              note: note,
            ),
          );
        } else {
          await editing.editReceivableCollection(
            EditReceivableCollectionCommand(
              transactionId: transactionId,
              principal: amount,
              interest: interest,
              receivableAccountId: accountId,
              receiveAccountId: receiveAccountId!,
              occurredAt: current.occurredAt,
              note: _notePatch(note),
            ),
          );
        }
      case ReceivablePayableFormKind.badDebt:
        if (transactionId == null) {
          await posting.createBadDebt(
            CreateBadDebtCommand(
              amount: amount,
              receivableAccountId: accountId,
              occurredAt: current.occurredAt,
              note: note,
              isExcludedFromStats: current.excludeStats,
              isExcludedFromBudget: current.excludeBudget,
            ),
          );
        } else {
          await editing.editBadDebt(
            EditBadDebtCommand(
              transactionId: transactionId,
              amount: amount,
              receivableAccountId: accountId,
              occurredAt: current.occurredAt,
              note: _notePatch(note),
              isExcludedFromStats: current.excludeStats,
              isExcludedFromBudget: current.excludeBudget,
            ),
          );
        }
      case ReceivablePayableFormKind.debtRelief:
        if (transactionId == null) {
          await posting.createDebtRelief(
            CreateDebtReliefCommand(
              amount: amount,
              liabilityAccountId: accountId,
              occurredAt: current.occurredAt,
              note: note,
              isExcludedFromStats: current.excludeStats,
            ),
          );
        } else {
          await editing.editDebtRelief(
            EditDebtReliefCommand(
              transactionId: transactionId,
              amount: amount,
              liabilityAccountId: accountId,
              occurredAt: current.occurredAt,
              note: _notePatch(note),
              isExcludedFromStats: current.excludeStats,
            ),
          );
        }
    }
    ref.invalidate(accountsByIdProvider);
    ref.invalidate(
      accountsForSelectionPurposeProvider(AccountSelectionPurpose.fund),
    );
    if (transactionId != null) {
      ref.invalidate(transactionDetailProvider(transactionId));
    }
  }

  bool _matchesKind(BusinessPurpose purpose) => switch (args.kind) {
    ReceivablePayableFormKind.collection =>
      purpose == BusinessPurpose.receivableCollection,
    ReceivablePayableFormKind.badDebt => purpose == BusinessPurpose.badDebt,
    ReceivablePayableFormKind.debtRelief =>
      purpose == BusinessPurpose.debtRelief,
  };

  void _update(
    ReceivablePayableFormState Function(ReceivablePayableFormState) update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(update(current));
  }

  SubmitOutcome _invalidCommand(String message) => SubmitOutcome.failure(
    UiError(
      code: LedgerErrorCode.transactionInvalidCommand.code,
      message: message,
    ),
  );
}

enum ReceivablePayableFormStatus { loaded, notFound }

class ReceivablePayableFormState {
  ReceivablePayableFormState({
    required this.status,
    required this.kind,
    required List<Account> receiveAccounts,
    required this.occurredAt,
    required this.submitting,
    required this.amountText,
    required this.interestText,
    required this.noteText,
    required this.reducibleBalance,
    required this.excludeStats,
    required this.excludeBudget,
    this.transactionId,
    this.accountId,
    this.receiveAccountId,
  }) : receiveAccounts = List.unmodifiable(receiveAccounts);

  factory ReceivablePayableFormState.loaded({
    required ReceivablePayableFormKind kind,
    required List<Account> receiveAccounts,
    required DateTime occurredAt,
    required String amountText,
    required String interestText,
    required String noteText,
    required Money reducibleBalance,
    bool excludeStats = false,
    bool excludeBudget = false,
    String? transactionId,
    String? accountId,
    String? receiveAccountId,
  }) => ReceivablePayableFormState(
    status: ReceivablePayableFormStatus.loaded,
    kind: kind,
    transactionId: transactionId,
    receiveAccounts: receiveAccounts,
    accountId: accountId,
    receiveAccountId: receiveAccountId,
    occurredAt: occurredAt,
    submitting: false,
    amountText: amountText,
    interestText: interestText,
    noteText: noteText,
    reducibleBalance: reducibleBalance,
    excludeStats: excludeStats,
    excludeBudget: excludeBudget,
  );

  factory ReceivablePayableFormState.notFound({
    required ReceivablePayableFormKind kind,
    required String transactionId,
    required List<Account> receiveAccounts,
  }) => ReceivablePayableFormState(
    status: ReceivablePayableFormStatus.notFound,
    kind: kind,
    transactionId: transactionId,
    receiveAccounts: receiveAccounts,
    occurredAt: DateTime.now(),
    submitting: false,
    amountText: '',
    interestText: '0.00',
    noteText: '',
    reducibleBalance: Money.zero(),
    excludeStats: false,
    excludeBudget: false,
  );

  final ReceivablePayableFormStatus status;
  final ReceivablePayableFormKind kind;
  final String? transactionId;
  final List<Account> receiveAccounts;
  final String? accountId;
  final String? receiveAccountId;
  final DateTime occurredAt;
  final bool submitting;
  final String amountText;
  final String interestText;
  final String noteText;
  final Money reducibleBalance;
  final bool excludeStats;
  final bool excludeBudget;

  bool get isLoaded => status == ReceivablePayableFormStatus.loaded;

  String get amountLabel => switch (kind) {
    ReceivablePayableFormKind.collection => '收回本金',
    ReceivablePayableFormKind.badDebt => '坏账本金',
    ReceivablePayableFormKind.debtRelief => '豁免本金',
  };

  String get accountMissingMessage => switch (kind) {
    ReceivablePayableFormKind.collection ||
    ReceivablePayableFormKind.badDebt => '请选择应收账户',
    ReceivablePayableFormKind.debtRelief => '请选择债务账户',
  };

  ReceivablePayableFormState copyWith({
    DateTime? occurredAt,
    Object? receiveAccountId = _sentinel,
    bool? excludeStats,
    bool? excludeBudget,
    bool? submitting,
  }) => ReceivablePayableFormState(
    status: status,
    kind: kind,
    transactionId: transactionId,
    receiveAccounts: receiveAccounts,
    accountId: accountId,
    receiveAccountId:
        receiveAccountId == _sentinel
            ? this.receiveAccountId
            : receiveAccountId as String?,
    occurredAt: occurredAt ?? this.occurredAt,
    submitting: submitting ?? this.submitting,
    amountText: amountText,
    interestText: interestText,
    noteText: noteText,
    reducibleBalance: reducibleBalance,
    excludeStats: excludeStats ?? this.excludeStats,
    excludeBudget: excludeBudget ?? this.excludeBudget,
  );
}

class BalanceCrossingConfirmation {
  const BalanceCrossingConfirmation({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

Money? _detailAmount(TransactionDetail detail, TransactionDetailType type) {
  for (final item in detail.details) {
    if (item.type == type) return item.amount;
  }
  return null;
}

String? _entryForUsage(
  TransactionDetail detail,
  Map<String, Account> accountsById, {
  required EntryDirection direction,
  required AccountUsage usage,
}) {
  String? result;
  for (final entry in detail.entries) {
    final account = accountsById[entry.accountId];
    if (entry.direction != direction ||
        account == null ||
        !accountMatchesUsage(account, usage)) {
      continue;
    }
    if (result != null) return null;
    result = account.id;
  }
  return result;
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value.trim());
  return money != null && money.minorUnits > 0 ? money : null;
}

Money? _parseNonNegativeMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  final money = Money.tryParse(trimmed);
  return money != null && money.minorUnits >= 0 ? money : null;
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id != null && accounts.any((account) => account.id == id)) return id;
  return accounts.isEmpty ? null : accounts.first.id;
}

Patch<String?> _notePatch(String? note) =>
    note == null ? const Patch<String?>.clear() : Patch.set(note);

const Object _sentinel = Object();
