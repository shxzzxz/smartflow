import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../shared/presentation/account_lookup.dart';
import '../../shared/presentation/transaction_list_presentation.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/provider/tag_providers.dart';

part 'filtered_transactions_view_model.g.dart';

const filteredTransactionPageSize = 20;

enum FilteredTransactionTarget { category, tag }

@riverpod
class FilteredTransactionPaging extends _$FilteredTransactionPaging {
  @override
  int build(FilteredTransactionTarget target, String targetId) => 1;

  void loadMore() => state += 1;
}

@riverpod
Stream<List<TransactionReadModel>> filteredTransactions(
  Ref ref,
  FilteredTransactionTarget target,
  String targetId,
  int limit,
) async* {
  final lookup = await ref.watch(accountLookupProvider.future);
  final categoryIds = switch (target) {
    FilteredTransactionTarget.category => _resolvedCategoryIds(
      targetId,
      lookup,
    ),
    FilteredTransactionTarget.tag => null,
  };

  yield* ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          match: TransactionFactMatch(categoryAccountIds: categoryIds),
          tagIds: target == FilteredTransactionTarget.tag ? {targetId} : null,
          topLevelOnly: true,
          limit: limit,
        ),
      );
}

@riverpod
class FilteredTransactionsViewModel extends _$FilteredTransactionsViewModel {
  List<TransactionReadModel> _previousItems = const [];

  @override
  FilteredTransactionsState build(
    FilteredTransactionTarget target,
    String targetId,
  ) {
    final pageCount = ref.watch(
      filteredTransactionPagingProvider(target, targetId),
    );
    final limit = pageCount * filteredTransactionPageSize;
    final transactions = ref.watch(
      filteredTransactionsProvider(target, targetId, limit),
    );
    final accountLookup = ref.watch(accountLookupProvider);
    final tags = target == FilteredTransactionTarget.tag
        ? ref.watch(tagListProvider)
        : null;

    if (accountLookup case AsyncError()) {
      return const FilteredTransactionsState.error(message: '加载失败，请稍后重试');
    }
    if (tags case AsyncError()) {
      return const FilteredTransactionsState.error(message: '加载失败，请稍后重试');
    }

    final lookup = accountLookup.value;
    if (lookup == null || (tags != null && tags.value == null)) {
      return const FilteredTransactionsState.loading();
    }

    final metadata = _metadata(target, targetId, lookup, tags?.value);
    if (metadata == null) {
      return FilteredTransactionsState.error(
        message: target == FilteredTransactionTarget.category
            ? '分类不存在或已停用'
            : '标签不存在',
      );
    }

    if (_previousItems.isNotEmpty && transactions.isLoading) {
      return _loaded(
        metadata: metadata,
        items: _previousItems,
        accountLookup: lookup,
        hasMore: true,
        isLoadingMore: true,
      );
    }

    return switch (transactions) {
      AsyncData(:final value) => _loaded(
        metadata: metadata,
        items: _previousItems = value,
        accountLookup: lookup,
        hasMore: value.length == limit,
        isLoadingMore: false,
      ),
      AsyncError() =>
        _previousItems.isEmpty
            ? const FilteredTransactionsState.error(message: '加载失败，请稍后重试')
            : _loaded(
                metadata: metadata,
                items: _previousItems,
                accountLookup: lookup,
                hasMore: true,
                isLoadingMore: false,
                loadMoreErrorMessage: '加载更多交易失败，请重试',
              ),
      AsyncLoading() => const FilteredTransactionsState.loading(),
    };
  }

  void loadMore() {
    if (state case FilteredTransactionsLoaded(
      hasMore: true,
      isLoadingMore: false,
      :final loadMoreErrorMessage,
    )) {
      if (loadMoreErrorMessage != null) {
        final pageCount = ref.read(
          filteredTransactionPagingProvider(target, targetId),
        );
        ref.invalidate(
          filteredTransactionsProvider(
            target,
            targetId,
            pageCount * filteredTransactionPageSize,
          ),
        );
        return;
      }
      ref
          .read(filteredTransactionPagingProvider(target, targetId).notifier)
          .loadMore();
    }
  }

  FilteredTransactionsLoaded _loaded({
    required _FilteredTransactionMetadata metadata,
    required List<TransactionReadModel> items,
    required AccountLookup accountLookup,
    required bool hasMore,
    required bool isLoadingMore,
    String? loadMoreErrorMessage,
  }) {
    return FilteredTransactionsLoaded(
      title: metadata.title,
      subtitle: metadata.subtitle,
      emptyMessage: metadata.emptyMessage,
      groups: groupTransactionsByDay(
        items: items,
        accountLookup: accountLookup,
        amountSource: metadata.amountSource,
      ),
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
    );
  }
}

_FilteredTransactionMetadata? _metadata(
  FilteredTransactionTarget target,
  String targetId,
  AccountLookup accountLookup,
  List<TagView>? tags,
) {
  switch (target) {
    case FilteredTransactionTarget.category:
      final category = accountLookup.find(targetId);
      if (category == null ||
          !category.type.isCategory ||
          category.isArchived) {
        return null;
      }
      return _FilteredTransactionMetadata(
        title: category.name,
        subtitle: '分类交易',
        emptyMessage: '该分类暂无交易',
        amountSource: const TransactionGroupAmountSource(),
      );
    case FilteredTransactionTarget.tag:
      TagView? selectedTag;
      for (final tag in tags ?? const <TagView>[]) {
        if (tag.id == targetId) {
          selectedTag = tag;
          break;
        }
      }
      if (selectedTag == null) return null;
      return _FilteredTransactionMetadata(
        title: selectedTag.name,
        subtitle: '标签交易',
        emptyMessage: '该标签暂无交易',
        amountSource: const TransactionGroupAmountSource(),
      );
  }
}

Set<String> _resolvedCategoryIds(
  String categoryId,
  AccountLookup accountLookup,
) {
  final category = accountLookup.find(categoryId);
  if (category == null) return const {};
  final selection = category.parentId == null
      ? CategorySelection.withDescendants(categoryId)
      : CategorySelection.ownOnly(categoryId);
  return resolveCategoryAccountIds([selection], accountLookup.byId);
}

class _FilteredTransactionMetadata {
  const _FilteredTransactionMetadata({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.amountSource,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final TransactionListAmountSource amountSource;
}

sealed class FilteredTransactionsState {
  const FilteredTransactionsState();

  const factory FilteredTransactionsState.loading() =
      FilteredTransactionsLoading;

  const factory FilteredTransactionsState.error({required String message}) =
      FilteredTransactionsError;

  const factory FilteredTransactionsState.loaded({
    required String title,
    required String subtitle,
    required String emptyMessage,
    required List<TransactionDayGroup> groups,
    required bool hasMore,
    required bool isLoadingMore,
    String? loadMoreErrorMessage,
  }) = FilteredTransactionsLoaded;
}

final class FilteredTransactionsLoading extends FilteredTransactionsState {
  const FilteredTransactionsLoading();
}

final class FilteredTransactionsError extends FilteredTransactionsState {
  const FilteredTransactionsError({required this.message});

  final String message;
}

final class FilteredTransactionsLoaded extends FilteredTransactionsState {
  const FilteredTransactionsLoaded({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.groups,
    required this.hasMore,
    required this.isLoadingMore,
    this.loadMoreErrorMessage,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<TransactionDayGroup> groups;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;

  List<TransactionRowPresentation> get rows => [
    for (final group in groups) ...group.rows,
  ];
}
