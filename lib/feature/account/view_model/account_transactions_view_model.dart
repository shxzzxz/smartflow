import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../widget/business/account_lookup.dart';
import '../../../widget/business/transaction_list_presentation.dart';
import '../../shared/provider/ledger_query_providers.dart';

part 'account_transactions_view_model.g.dart';

@riverpod
AccountTransactionsState accountTransactionsViewModel(
  Ref ref,
  String accountId,
) {
  final transactions = ref.watch(transactionListProvider(accountId: accountId));
  final accountsById = ref.watch(accountsByIdProvider);

  if (transactions case AsyncError(:final error)) {
    return AccountTransactionsState.error(message: '加载失败：$error');
  }
  if (accountsById case AsyncError(:final error)) {
    return AccountTransactionsState.error(message: '加载失败：$error');
  }

  final transactionValues = transactions.value;
  final accountValues = accountsById.value;
  if (transactionValues == null || accountValues == null) {
    return const AccountTransactionsState.loading();
  }

  final accountLookup = AccountLookup(accountValues);
  return AccountTransactionsState.loaded(
    rows: [
      for (final item in transactionValues)
        buildTransactionRowPresentation(
          item: item,
          accountLookup: accountLookup,
          viewAccountId: accountId,
        ),
    ],
  );
}

sealed class AccountTransactionsState {
  const AccountTransactionsState();

  const factory AccountTransactionsState.loading() = AccountTransactionsLoading;

  const factory AccountTransactionsState.error({required String message}) =
      AccountTransactionsError;

  const factory AccountTransactionsState.loaded({
    required List<TransactionRowPresentation> rows,
  }) = AccountTransactionsLoaded;
}

final class AccountTransactionsLoading extends AccountTransactionsState {
  const AccountTransactionsLoading();
}

final class AccountTransactionsError extends AccountTransactionsState {
  const AccountTransactionsError({required this.message});

  final String message;
}

final class AccountTransactionsLoaded extends AccountTransactionsState {
  const AccountTransactionsLoaded({required this.rows});

  final List<TransactionRowPresentation> rows;
}
