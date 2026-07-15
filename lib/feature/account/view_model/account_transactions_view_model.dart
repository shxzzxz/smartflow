import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/ledger/ledger_query_api.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../../shared/provider/ledger_query_providers.dart';

part 'account_transactions_view_model.g.dart';

const accountTransactionPageSize = 20;

@riverpod
class AccountTransactionPaging extends _$AccountTransactionPaging {
  @override
  int build(String accountId) => 1;

  void loadMore() => state += 1;
}

@riverpod
class AccountTransactionsViewModel extends _$AccountTransactionsViewModel {
  List<TransactionListReadModel> _previousItems = const [];

  @override
  AccountTransactionsState build(String accountId) {
    final pageCount = ref.watch(accountTransactionPagingProvider(accountId));
    final limit = pageCount * accountTransactionPageSize;
    final transactions = ref.watch(
      transactionListProvider(accountId: accountId, limit: limit),
    );
    final accountsById = ref.watch(accountsByIdProvider);

    if (accountsById case AsyncError()) {
      return const AccountTransactionsState.error(message: '加载失败，请稍后重试');
    }

    final accountValues = accountsById.value;
    if (accountValues == null) {
      return const AccountTransactionsState.loading();
    }

    if (_previousItems.isNotEmpty && transactions.isLoading) {
      return _loaded(
        items: _previousItems,
        accountLookup: AccountLookup(accountValues),
        hasMore: true,
        isLoadingMore: true,
      );
    }

    return switch (transactions) {
      AsyncData(:final value) => _loaded(
        items: _previousItems = value,
        accountLookup: AccountLookup(accountValues),
        hasMore: value.length == limit,
        isLoadingMore: false,
      ),
      AsyncError() =>
        _previousItems.isEmpty
            ? const AccountTransactionsState.error(message: '加载失败，请稍后重试')
            : _loaded(
              items: _previousItems,
              accountLookup: AccountLookup(accountValues),
              hasMore: true,
              isLoadingMore: false,
              loadMoreErrorMessage: '加载更多交易失败，请重试',
            ),
      AsyncLoading() =>
        _previousItems.isEmpty
            ? const AccountTransactionsState.loading()
            : _loaded(
              items: _previousItems,
              accountLookup: AccountLookup(accountValues),
              hasMore: true,
              isLoadingMore: true,
            ),
    };
  }

  void loadMore() {
    if (state case AccountTransactionsLoaded(
      hasMore: true,
      isLoadingMore: false,
      :final loadMoreErrorMessage,
    )) {
      if (loadMoreErrorMessage != null) {
        final pageCount = ref.read(accountTransactionPagingProvider(accountId));
        ref.invalidate(
          transactionListProvider(
            accountId: accountId,
            limit: pageCount * accountTransactionPageSize,
          ),
        );
        return;
      }
      ref.read(accountTransactionPagingProvider(accountId).notifier).loadMore();
    }
  }

  AccountTransactionsLoaded _loaded({
    required List<TransactionListReadModel> items,
    required AccountLookup accountLookup,
    required bool hasMore,
    required bool isLoadingMore,
    String? loadMoreErrorMessage,
  }) {
    return AccountTransactionsLoaded(
      groups: groupTransactionsByDay(
        items: items,
        accountLookup: accountLookup,
        viewAccountId: accountId,
      ),
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
    );
  }
}

sealed class AccountTransactionsState {
  const AccountTransactionsState();

  const factory AccountTransactionsState.loading() = AccountTransactionsLoading;

  const factory AccountTransactionsState.error({required String message}) =
      AccountTransactionsError;

  const factory AccountTransactionsState.loaded({
    required List<TransactionDayGroup> groups,
    required bool hasMore,
    required bool isLoadingMore,
    String? loadMoreErrorMessage,
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
  const AccountTransactionsLoaded({
    required this.groups,
    required this.hasMore,
    required this.isLoadingMore,
    this.loadMoreErrorMessage,
  });

  final List<TransactionDayGroup> groups;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;

  List<TransactionRowPresentation> get rows => [
    for (final group in groups) ...group.rows,
  ];
}
