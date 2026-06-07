import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../widget/business/account_lookup.dart';
import '../../../widget/business/transaction_list_presentation.dart';
import '../../credit/provider/installment_query_providers.dart';
import '../../shared/provider/ledger_query_providers.dart';

part 'account_detail_view_model.g.dart';

@riverpod
AccountDetailPageState accountDetailViewModel(Ref ref, String accountId) {
  final accounts = ref.watch(accountListProvider);
  final transactions = ref.watch(transactionListProvider(accountId: accountId));
  final accountsById = ref.watch(accountsByIdProvider);

  if (accounts case AsyncError(:final error)) {
    return AccountDetailPageState.error(message: '加载失败：$error');
  }
  if (transactions case AsyncError(:final error)) {
    return AccountDetailPageState.error(message: '加载失败：$error');
  }
  if (accountsById case AsyncError(:final error)) {
    return AccountDetailPageState.error(message: '加载失败：$error');
  }

  final accountValues = accounts.value;
  final transactionValues = transactions.value;
  final accountLookupValues = accountsById.value;
  if (accountValues == null ||
      transactionValues == null ||
      accountLookupValues == null) {
    return const AccountDetailPageState.loading();
  }

  final account = _findAccount(accountValues, accountId);
  if (account == null) {
    return const AccountDetailPageState.notFound();
  }

  return AccountDetailPageState.loaded(
    account: account,
    transactionGroups: groupTransactionsByDay(
      items: transactionValues,
      accountLookup: AccountLookup(accountLookupValues),
    ),
    contracts: _contractsStateFor(ref, account),
  );
}

AccountContractsState _contractsStateFor(Ref ref, Account account) {
  if (account.type != AccountType.liability) {
    return const AccountContractsState.notApplicable();
  }

  return switch (ref.watch(installmentContractsByAccountProvider(account.id))) {
    AsyncData(value: final contracts) => AccountContractsState.loaded(
      contracts: contracts,
    ),
    AsyncError(:final error) => AccountContractsState.error(message: '$error'),
    _ => const AccountContractsState.loading(),
  };
}

sealed class AccountDetailPageState {
  const AccountDetailPageState();

  const factory AccountDetailPageState.loading() = AccountDetailLoading;

  const factory AccountDetailPageState.error({required String message}) =
      AccountDetailError;

  const factory AccountDetailPageState.notFound() = AccountDetailNotFound;

  const factory AccountDetailPageState.loaded({
    required Account account,
    required List<TransactionDayGroup> transactionGroups,
    required AccountContractsState contracts,
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
    required this.transactionGroups,
    required this.contracts,
  });

  final Account account;
  final List<TransactionDayGroup> transactionGroups;
  final AccountContractsState contracts;
}

sealed class AccountContractsState {
  const AccountContractsState();

  const factory AccountContractsState.notApplicable() =
      AccountContractsNotApplicable;

  const factory AccountContractsState.loading() = AccountContractsLoading;

  const factory AccountContractsState.error({required String message}) =
      AccountContractsError;

  const factory AccountContractsState.loaded({
    required List<InstallmentContract> contracts,
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

  final List<InstallmentContract> contracts;
}

Account? _findAccount(List<Account> accounts, String id) {
  for (final account in accounts) {
    if (account.id == id) {
      return account;
    }
  }
  return null;
}
