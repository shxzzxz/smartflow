import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../credit/provider/bill_query_providers.dart';
import 'account_views_provider.dart';

part 'account_bills_view_model.g.dart';

@riverpod
AccountBillsPageState accountBillsViewModel(Ref ref, String accountId) {
  final account = ref.watch(accountViewProvider(accountId));
  final bills = ref.watch(billSummariesByAccountProvider(accountId));

  if (account case AsyncError()) {
    return const AccountBillsPageState.error(message: '账户加载失败，请稍后重试');
  }
  if (bills case AsyncError()) {
    return const AccountBillsPageState.error(message: '账单加载失败，请稍后重试');
  }
  if (account case AsyncData(value: null)) {
    return const AccountBillsPageState.notFound();
  }

  final accountValue = account.value;
  final billValues = bills.value;
  if (accountValue == null || billValues == null) {
    return const AccountBillsPageState.loading();
  }

  return AccountBillsPageState.loaded(
    bills: billValues,
    canGenerateHistoricalBill:
        accountValue.isCreditLiability && !accountValue.isArchived,
  );
}

sealed class AccountBillsPageState {
  const AccountBillsPageState();

  const factory AccountBillsPageState.loading() = AccountBillsPageLoading;

  const factory AccountBillsPageState.error({required String message}) =
      AccountBillsPageError;

  const factory AccountBillsPageState.notFound() = AccountBillsPageNotFound;

  const factory AccountBillsPageState.loaded({
    required List<BillSummaryReadModel> bills,
    required bool canGenerateHistoricalBill,
  }) = AccountBillsPageLoaded;
}

final class AccountBillsPageLoading extends AccountBillsPageState {
  const AccountBillsPageLoading();
}

final class AccountBillsPageError extends AccountBillsPageState {
  const AccountBillsPageError({required this.message});

  final String message;
}

final class AccountBillsPageNotFound extends AccountBillsPageState {
  const AccountBillsPageNotFound();
}

final class AccountBillsPageLoaded extends AccountBillsPageState {
  const AccountBillsPageLoaded({
    required this.bills,
    required this.canGenerateHistoricalBill,
  });

  final List<BillSummaryReadModel> bills;
  final bool canGenerateHistoricalBill;
}
