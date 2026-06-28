import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/credit/credit_query_api.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../../credit/provider/bill_query_providers.dart';
import '../../credit/provider/installment_query_providers.dart';
import '../../shared/provider/ledger_query_providers.dart';
import 'account_view.dart';
import 'account_views_provider.dart';

part 'account_detail_view_model.g.dart';

@riverpod
AccountDetailPageState accountDetailViewModel(Ref ref, String accountId) {
  final account = ref.watch(accountViewProvider(accountId));
  final transactions = ref.watch(transactionListProvider(accountId: accountId));
  final accountsById = ref.watch(accountsByIdProvider);

  if (account case AsyncError(:final error)) {
    return AccountDetailPageState.error(message: '加载失败：$error');
  }
  if (transactions case AsyncError(:final error)) {
    return AccountDetailPageState.error(message: '加载失败：$error');
  }
  if (accountsById case AsyncError(:final error)) {
    return AccountDetailPageState.error(message: '加载失败：$error');
  }
  if (account case AsyncData(value: null)) {
    return const AccountDetailPageState.notFound();
  }

  final accountValue = account.value;
  final transactionValues = transactions.value;
  final accountLookupValues = accountsById.value;
  if (accountValue == null ||
      transactionValues == null ||
      accountLookupValues == null) {
    return const AccountDetailPageState.loading();
  }

  return AccountDetailPageState.loaded(
    account: accountValue,
    transactionGroups: groupTransactionsByDay(
      items: transactionValues,
      accountLookup: AccountLookup(accountLookupValues),
    ),
    contracts: _contractsStateFor(ref, accountValue),
    bills: _billsStateFor(ref, accountValue),
  );
}

AccountContractsState _contractsStateFor(Ref ref, AccountView account) {
  if (!account.isLiability) {
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

AccountBillsState _billsStateFor(Ref ref, AccountView account) {
  if (!account.isCreditLiability) {
    return const AccountBillsState.notApplicable();
  }

  return switch (ref.watch(billSummariesByAccountProvider(account.id))) {
    AsyncData(value: final bills) => AccountBillsState.loaded(bills: bills),
    AsyncError(:final error) => AccountBillsState.error(message: '$error'),
    _ => const AccountBillsState.loading(),
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
    required List<TransactionDayGroup> transactionGroups,
    required AccountContractsState contracts,
    required AccountBillsState bills,
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
    required this.bills,
  });

  final AccountView account;
  final List<TransactionDayGroup> transactionGroups;
  final AccountContractsState contracts;
  final AccountBillsState bills;
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
