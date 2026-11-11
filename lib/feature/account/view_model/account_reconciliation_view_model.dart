import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/presentation/transaction_list_presentation.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/account_reconciliation_presentation.dart';
import 'account_view.dart';
import 'account_views_provider.dart';

part 'account_reconciliation_view_model.g.dart';

final _logger = Logger('feature.account.reconciliation');

@riverpod
Stream<AccountReconciliationState> accountReconciliationData(
  Ref ref,
  AccountReconciliationQuery query,
) {
  return ref.watch(accountReconciliationQueryServiceProvider).watch(query);
}

@riverpod
class AccountReconciliationSelection extends _$AccountReconciliationSelection {
  @override
  AccountReconciliationSelectionState build(String accountId) {
    final now = ref.watch(currentDateTimeProvider);
    final today = normalizeDate(now);
    return AccountReconciliationSelectionState(
      from: DateTime(today.year, today.month),
      untilInclusive: today,
      expectedBalanceText: '',
      submitting: false,
    );
  }

  void setRange(DateTime from, DateTime untilInclusive) {
    final normalizedFrom = normalizeDate(from);
    final normalizedUntil = normalizeDate(untilInclusive);
    state = state.copyWith(
      from: normalizedFrom,
      untilInclusive: normalizedUntil.isBefore(normalizedFrom)
          ? normalizedFrom
          : normalizedUntil,
    );
  }

  void setExpectedBalanceText(String value) {
    state = state.copyWith(expectedBalanceText: value);
  }

  void setSubmitting(bool value) {
    state = state.copyWith(submitting: value);
  }
}

@riverpod
class AccountReconciliationViewModel extends _$AccountReconciliationViewModel {
  @override
  AccountReconciliationPageState build(String accountId) {
    final account = ref.watch(accountViewProvider(accountId));
    final selection = ref.watch(
      accountReconciliationSelectionProvider(accountId),
    );
    final lookup = ref.watch(accountLookupProvider);
    final query = AccountReconciliationQuery(
      accountId: accountId,
      from: selection.from,
      untilInclusive: selection.untilInclusive,
    );
    final reconciliation = ref.watch(accountReconciliationDataProvider(query));
    final transactions = ref.watch(
      transactionFeedProvider(
        settlementAccountId: accountId,
        occurredFrom: query.from,
        occurredUntil: query.untilExclusive,
        limit: null,
      ),
    );

    if (account case AsyncError()) {
      return const AccountReconciliationPageState.error(
        message: '账户加载失败，请稍后重试',
      );
    }
    if (account case AsyncData(value: null)) {
      return const AccountReconciliationPageState.notFound();
    }
    final accountValue = account.value;
    if (accountValue == null || lookup.isLoading) {
      return const AccountReconciliationPageState.loading();
    }
    if (lookup case AsyncError()) {
      return const AccountReconciliationPageState.error(
        message: '账户数据加载失败，请稍后重试',
      );
    }
    if (reconciliation case AsyncError()) {
      return const AccountReconciliationPageState.error(
        message: '对账数据加载失败，请稍后重试',
      );
    }
    if (transactions case AsyncError()) {
      return const AccountReconciliationPageState.error(
        message: '账户流水加载失败，请稍后重试',
      );
    }

    final reconciliationValue = reconciliation.value;
    final transactionValue = transactions.value;
    final lookupValue = lookup.value;
    if (reconciliationValue == null ||
        transactionValue == null ||
        lookupValue == null) {
      return const AccountReconciliationPageState.loading();
    }

    final expectedBalance = Money.tryParse(selection.expectedBalanceText);
    final groups = buildAccountReconciliationDayGroups(
      entries: transactionValue,
      reconciliation: reconciliationValue,
      accountId: accountId,
      accountLookup: lookupValue,
      expectedBalance: expectedBalance,
    );
    return AccountReconciliationPageState.loaded(
      account: accountValue,
      from: selection.from,
      untilInclusive: selection.untilInclusive,
      expectedBalanceText: selection.expectedBalanceText,
      expectedBalance: expectedBalance,
      groups: groups,
      changedDayCount: reconciliationValue.changedDayCount,
      unconfirmedDayCount: reconciliationValue.hasSnapshots
          ? reconciliationValue.unconfirmedDayCount
          : 0,
      submitting: selection.submitting,
    );
  }

  Future<UiActionOutcome<void>> confirm() {
    return guardUiAction(_logger, 'Account reconciliation confirm', () async {
      final loaded = state;
      if (loaded is! AccountReconciliationLoaded || !loaded.canConfirm) {
        throw BusinessException(LedgerErrorCode.reconciliationInvalidCommand);
      }
      final selection = ref.read(
        accountReconciliationSelectionProvider(accountId).notifier,
      );
      selection.setSubmitting(true);
      try {
        await ref
            .read(accountReconciliationAppServiceProvider)
            .confirm(
              ConfirmAccountReconciliationCommand(
                accountId: accountId,
                from: loaded.from,
                untilInclusive: loaded.untilInclusive,
              ),
            );
      } finally {
        selection.setSubmitting(false);
      }
    });
  }
}

sealed class AccountReconciliationPageState {
  const AccountReconciliationPageState();

  const factory AccountReconciliationPageState.loading() =
      AccountReconciliationLoading;
  const factory AccountReconciliationPageState.notFound() =
      AccountReconciliationNotFound;
  const factory AccountReconciliationPageState.error({
    required String message,
  }) = AccountReconciliationError;
  const factory AccountReconciliationPageState.loaded({
    required AccountView account,
    required DateTime from,
    required DateTime untilInclusive,
    required String expectedBalanceText,
    required Money? expectedBalance,
    required List<TransactionDayGroup> groups,
    required int changedDayCount,
    required int unconfirmedDayCount,
    required bool submitting,
  }) = AccountReconciliationLoaded;
}

final class AccountReconciliationLoading
    extends AccountReconciliationPageState {
  const AccountReconciliationLoading();
}

final class AccountReconciliationNotFound
    extends AccountReconciliationPageState {
  const AccountReconciliationNotFound();
}

final class AccountReconciliationError extends AccountReconciliationPageState {
  const AccountReconciliationError({required this.message});

  final String message;
}

final class AccountReconciliationLoaded extends AccountReconciliationPageState {
  const AccountReconciliationLoaded({
    required this.account,
    required this.from,
    required this.untilInclusive,
    required this.expectedBalanceText,
    required this.expectedBalance,
    required this.groups,
    required this.changedDayCount,
    required this.unconfirmedDayCount,
    required this.submitting,
  });

  final AccountView account;
  final DateTime from;
  final DateTime untilInclusive;
  final String expectedBalanceText;
  final Money? expectedBalance;
  final List<TransactionDayGroup> groups;
  final int changedDayCount;
  final int unconfirmedDayCount;
  final bool submitting;

  bool get canConfirm => !submitting;
}

class AccountReconciliationSelectionState {
  const AccountReconciliationSelectionState({
    required this.from,
    required this.untilInclusive,
    required this.expectedBalanceText,
    required this.submitting,
  });

  final DateTime from;
  final DateTime untilInclusive;
  final String expectedBalanceText;
  final bool submitting;

  AccountReconciliationSelectionState copyWith({
    DateTime? from,
    DateTime? untilInclusive,
    String? expectedBalanceText,
    bool? submitting,
  }) {
    return AccountReconciliationSelectionState(
      from: from ?? this.from,
      untilInclusive: untilInclusive ?? this.untilInclusive,
      expectedBalanceText: expectedBalanceText ?? this.expectedBalanceText,
      submitting: submitting ?? this.submitting,
    );
  }
}
