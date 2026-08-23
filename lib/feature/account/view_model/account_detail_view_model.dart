import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../credit/provider/bill_query_providers.dart';
import '../../credit/provider/credit_account_query_providers.dart';
import '../../credit/provider/installment_query_providers.dart';
import 'account_transactions_view_model.dart';
import 'account_view.dart';
import 'account_views_provider.dart';

part 'account_detail_view_model.g.dart';

final _logger = Logger('feature.account.detail');

@riverpod
class AccountDetailViewModel extends _$AccountDetailViewModel {
  @override
  AccountDetailPageState build(String accountId) {
    final account = ref.watch(accountViewProvider(accountId));
    final transactions = ref.watch(
      accountTransactionsViewModelProvider(accountId),
    );

    if (account case AsyncError()) {
      return const AccountDetailPageState.error(message: '加载失败，请稍后重试');
    }
    if (account case AsyncData(value: null)) {
      return const AccountDetailPageState.notFound();
    }

    final accountValue = account.value;
    if (accountValue == null) {
      return const AccountDetailPageState.loading();
    }

    return AccountDetailPageState.loaded(
      account: accountValue,
      actions: accountDetailActions(accountValue),
      transactions: transactions,
      contracts: _contractsStateFor(ref, accountValue),
      bills: _billsStateFor(ref, accountValue),
      creditOverview: _creditOverviewStateFor(ref, accountValue),
    );
  }

  void loadMoreTransactions() {
    ref
        .read(accountTransactionsViewModelProvider(accountId).notifier)
        .loadMore();
  }

  Future<UiActionOutcome<void>> archiveAccount() async {
    return guardUiAction(_logger, 'Account archive', () async {
      await ref
          .read(accountAppServiceProvider)
          .archiveAccount(ArchiveAccountCommand(id: accountId));
    });
  }

  Future<UiActionOutcome<void>> deletePermanently() async {
    return guardUiAction(_logger, 'Account permanent deletion', () async {
      final account = await ref
          .read(accountQueryServiceProvider)
          .findAccountById(accountId);
      final kind = account == null
          ? null
          : accountProfileKindForAccount(account);
      if (kind == AccountProfileKind.credit ||
          kind == AccountProfileKind.loan) {
        await ref
            .read(creditAccountAppServiceProvider)
            .deleteAccount(
              DeleteCreditLiabilityAccountCommand(accountId: accountId),
            );
        return;
      }
      await ref
          .read(accountAppServiceProvider)
          .deleteAccount(DeleteAccountCommand(id: accountId));
    });
  }

  Future<UiActionOutcome<void>> restoreAccount() async {
    return guardUiAction(_logger, 'Account restore', () async {
      await ref
          .read(accountAppServiceProvider)
          .restoreAccount(RestoreAccountCommand(id: accountId));
    });
  }
}

class AccountDetailAction {
  const AccountDetailAction({
    required this.label,
    required this.iconKey,
    required this.route,
  });

  final String label;
  final String iconKey;
  final String route;
}

List<AccountDetailAction> accountDetailActions(AccountView account) {
  if (account.isArchived) return const [];

  return switch (account.kind) {
    AccountProfileKind.receivable => [
      AccountDetailAction(
        label: '借出',
        iconKey: 'logout-box-r-line',
        route: _transactionRoute(
          mode: 'lending',
          queryParameters: {'toAccountId': account.id},
        ),
      ),
      AccountDetailAction(
        label: '收回',
        iconKey: 'refund-income',
        route: '/account/${account.id}/receivable-collection',
      ),
      AccountDetailAction(
        label: '坏账',
        iconKey: 'money-cny-circle-line',
        route: '/account/${account.id}/bad-debt',
      ),
    ],
    AccountProfileKind.payable => [
      AccountDetailAction(
        label: '借入',
        iconKey: 'hand-coin-line',
        route: _transactionRoute(
          mode: 'borrowing',
          queryParameters: {'liabilityAccountId': account.id},
        ),
      ),
      AccountDetailAction(
        label: '还款',
        iconKey: 'loan',
        route: '/account/${account.id}/repayment',
      ),
      AccountDetailAction(
        label: '债务豁免',
        iconKey: 'hand-heart-line',
        route: '/account/${account.id}/debt-relief',
      ),
    ],
    AccountProfileKind.fund || AccountProfileKind.reimbursement => [
      _recordTransactionAction(account),
      AccountDetailAction(
        label: '转账',
        iconKey: 'transfer',
        route: _transactionRoute(
          mode: 'transfer',
          queryParameters: {'fromAccountId': account.id},
        ),
      ),
    ],
    AccountProfileKind.credit || AccountProfileKind.loan => [
      _recordTransactionAction(account),
      AccountDetailAction(
        label: '未归属还款',
        iconKey: 'loan',
        route: '/account/${account.id}/unattributed-repayment',
      ),
      AccountDetailAction(
        label: account.isCredit ? '现金分期' : '贷款分期',
        iconKey: 'loan',
        route: '/account/${account.id}/installments/new?source=disbursement',
      ),
    ],
  };
}

AccountDetailAction _recordTransactionAction(AccountView account) {
  return AccountDetailAction(
    label: '记账',
    iconKey: 'wallet-line',
    route: _transactionRoute(
      queryParameters: {'fromAccountId': account.id, 'toAccountId': account.id},
    ),
  );
}

String _transactionRoute({
  String? mode,
  required Map<String, String> queryParameters,
}) {
  return Uri(
    path: '/transaction/new',
    queryParameters: {'mode': ?mode, ...queryParameters},
  ).toString();
}

AccountContractsState _contractsStateFor(Ref ref, AccountView account) {
  if (!account.isLiability) {
    return const AccountContractsState.notApplicable();
  }

  return switch (ref.watch(installmentContractsByAccountProvider(account.id))) {
    AsyncData(value: final contracts) => AccountContractsState.loaded(
      contracts: contracts,
    ),
    AsyncError() => const AccountContractsState.error(message: '合同加载失败，请稍后重试'),
    _ => const AccountContractsState.loading(),
  };
}

AccountBillsState _billsStateFor(Ref ref, AccountView account) {
  if (!account.isCreditLiability) {
    return const AccountBillsState.notApplicable();
  }

  return switch (ref.watch(billSummariesByAccountProvider(account.id))) {
    AsyncData(value: final bills) => AccountBillsState.loaded(
      bills: bills.take(2).toList(),
    ),
    AsyncError() => const AccountBillsState.error(message: '账单加载失败，请稍后重试'),
    _ => const AccountBillsState.loading(),
  };
}

AccountCreditOverviewState _creditOverviewStateFor(
  Ref ref,
  AccountView account,
) {
  if (!account.isCreditLiability) {
    return const AccountCreditOverviewState.notApplicable();
  }

  return switch (ref.watch(creditAccountOverviewProvider(account.id))) {
    AsyncData(value: final overview) =>
      overview == null
          ? const AccountCreditOverviewState.notApplicable()
          : AccountCreditOverviewState.loaded(overview: overview),
    AsyncError() => const AccountCreditOverviewState.error(
      message: '欠款信息加载失败，请稍后重试',
    ),
    _ => const AccountCreditOverviewState.loading(),
  };
}

sealed class AccountDetailPageState {
  const AccountDetailPageState();

  const factory AccountDetailPageState.loading() = AccountDetailLoading;

  const factory AccountDetailPageState.error({required String message}) =
      AccountDetailError;

  const factory AccountDetailPageState.notFound() = AccountDetailNotFound;

  const factory AccountDetailPageState.loaded({
    required AccountView account,
    required List<AccountDetailAction> actions,
    required AccountTransactionsState transactions,
    required AccountContractsState contracts,
    required AccountBillsState bills,
    required AccountCreditOverviewState creditOverview,
  }) = AccountDetailLoaded;
}

final class AccountDetailLoading extends AccountDetailPageState {
  const AccountDetailLoading();
}

final class AccountDetailError extends AccountDetailPageState {
  const AccountDetailError({required this.message});

  final String message;
}

final class AccountDetailNotFound extends AccountDetailPageState {
  const AccountDetailNotFound();
}

final class AccountDetailLoaded extends AccountDetailPageState {
  const AccountDetailLoaded({
    required this.account,
    required this.actions,
    required this.transactions,
    required this.contracts,
    required this.bills,
    required this.creditOverview,
  });

  final AccountView account;
  final List<AccountDetailAction> actions;
  final AccountTransactionsState transactions;
  final AccountContractsState contracts;
  final AccountBillsState bills;
  final AccountCreditOverviewState creditOverview;
}

sealed class AccountContractsState {
  const AccountContractsState();

  const factory AccountContractsState.notApplicable() =
      AccountContractsNotApplicable;

  const factory AccountContractsState.loading() = AccountContractsLoading;

  const factory AccountContractsState.error({required String message}) =
      AccountContractsError;

  const factory AccountContractsState.loaded({
    required List<InstallmentContractReadModel> contracts,
  }) = AccountContractsLoaded;
}

final class AccountContractsNotApplicable extends AccountContractsState {
  const AccountContractsNotApplicable();
}

final class AccountContractsLoading extends AccountContractsState {
  const AccountContractsLoading();
}

final class AccountContractsError extends AccountContractsState {
  const AccountContractsError({required this.message});

  final String message;
}

final class AccountContractsLoaded extends AccountContractsState {
  const AccountContractsLoaded({required this.contracts});

  final List<InstallmentContractReadModel> contracts;
}

sealed class AccountBillsState {
  const AccountBillsState();

  const factory AccountBillsState.notApplicable() = AccountBillsNotApplicable;

  const factory AccountBillsState.loading() = AccountBillsLoading;

  const factory AccountBillsState.error({required String message}) =
      AccountBillsError;

  const factory AccountBillsState.loaded({
    required List<BillSummaryReadModel> bills,
  }) = AccountBillsLoaded;
}

final class AccountBillsNotApplicable extends AccountBillsState {
  const AccountBillsNotApplicable();
}

final class AccountBillsLoading extends AccountBillsState {
  const AccountBillsLoading();
}

final class AccountBillsError extends AccountBillsState {
  const AccountBillsError({required this.message});

  final String message;
}

final class AccountBillsLoaded extends AccountBillsState {
  const AccountBillsLoaded({required this.bills});

  final List<BillSummaryReadModel> bills;
}

sealed class AccountCreditOverviewState {
  const AccountCreditOverviewState();

  const factory AccountCreditOverviewState.notApplicable() =
      AccountCreditOverviewNotApplicable;

  const factory AccountCreditOverviewState.loading() =
      AccountCreditOverviewLoading;

  const factory AccountCreditOverviewState.error({required String message}) =
      AccountCreditOverviewError;

  const factory AccountCreditOverviewState.loaded({
    required CreditAccountOverviewReadModel overview,
  }) = AccountCreditOverviewLoaded;
}

final class AccountCreditOverviewNotApplicable
    extends AccountCreditOverviewState {
  const AccountCreditOverviewNotApplicable();
}

final class AccountCreditOverviewLoading extends AccountCreditOverviewState {
  const AccountCreditOverviewLoading();
}

final class AccountCreditOverviewError extends AccountCreditOverviewState {
  const AccountCreditOverviewError({required this.message});

  final String message;
}

final class AccountCreditOverviewLoaded extends AccountCreditOverviewState {
  const AccountCreditOverviewLoaded({required this.overview});

  final CreditAccountOverviewReadModel overview;
}
