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
  var _batch = const FilteredTransactionBatchState();

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

  void enterBatchMode(String transactionId) {
    if (target != FilteredTransactionTarget.category ||
        _batch.active ||
        state is! FilteredTransactionsLoaded) {
      return;
    }
    _setBatch(
      FilteredTransactionBatchState(
        active: true,
        selectedIds: Set.unmodifiable({transactionId}),
      ),
    );
  }

  void exitBatchMode() {
    if (_batch.submitting) return;
    _setBatch(const FilteredTransactionBatchState());
  }

  void setTransactionSelected(String transactionId, bool selected) {
    if (!_batch.active || _batch.submitting) return;
    final ids = {..._batch.selectedIds};
    if (selected) {
      ids.add(transactionId);
    } else {
      ids.remove(transactionId);
    }
    _setBatch(_batch.copyWith(selectedIds: ids));
  }

  void toggleSelectAll() {
    final current = state;
    if (!_batch.active ||
        _batch.submitting ||
        current is! FilteredTransactionsLoaded) {
      return;
    }
    final ids = current.visibleTransactionIds;
    final selected = _batch.selectedIds.intersection(ids);
    final next = {..._batch.selectedIds};
    if (selected.length == ids.length) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
    }
    _setBatch(_batch.copyWith(selectedIds: next));
  }

  Future<List<TagView>> loadTags() {
    return ref.read(tagApplicationServiceProvider).listTags();
  }

  Future<TransactionCleanupResult> deleteTransactions(Set<String> ids) async {
    _setBatch(_batch.copyWith(submitting: true));
    try {
      final result = await ref
          .read(transactionBatchOperationAppServiceProvider)
          .deleteTransactions(
            BatchDeleteTransactionsCommand(transactionIds: ids),
          );
      if (ref.mounted && result.skippedGroupCount == 0) {
        _setBatch(const FilteredTransactionBatchState());
      }
      return result;
    } finally {
      if (ref.mounted) _setBatch(_batch.copyWith(submitting: false));
    }
  }

  Future<TransactionBatchTagResult> updateTags({
    required Set<String> ids,
    required TransactionTagBatchOperation operation,
    required Set<String> tagIds,
  }) async {
    _setBatch(_batch.copyWith(submitting: true));
    try {
      return await ref
          .read(transactionBatchOperationAppServiceProvider)
          .updateTags(
            BatchTransactionTagsCommand(
              transactionIds: ids,
              operation: operation,
              tagIds: tagIds,
            ),
          );
    } finally {
      if (ref.mounted) _setBatch(_batch.copyWith(submitting: false));
    }
  }

  void _setBatch(FilteredTransactionBatchState batch) {
    _batch = batch;
    final current = state;
    if (current is FilteredTransactionsLoaded) {
      state = current.copyWith(batch: batch);
    }
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
      batch: _batch,
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
    FilteredTransactionBatchState batch,
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
    this.batch = const FilteredTransactionBatchState(),
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<TransactionDayGroup> groups;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final FilteredTransactionBatchState batch;

  Set<String> get visibleTransactionIds => {
    for (final row in rows) row.transactionId,
  };

  Set<String> get selectedVisibleIds =>
      batch.selectedIds.intersection(visibleTransactionIds);

  FilteredTransactionsLoaded copyWith({FilteredTransactionBatchState? batch}) {
    return FilteredTransactionsLoaded(
      title: title,
      subtitle: subtitle,
      emptyMessage: emptyMessage,
      groups: groups,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
      batch: batch ?? this.batch,
    );
  }

  List<TransactionRowPresentation> get rows => [
    for (final group in groups) ...group.rows,
  ];
}

class FilteredTransactionBatchState {
  const FilteredTransactionBatchState({
    this.active = false,
    this.submitting = false,
    this.selectedIds = const {},
  });

  final bool active;
  final bool submitting;
  final Set<String> selectedIds;

  FilteredTransactionBatchState copyWith({
    bool? submitting,
    Set<String>? selectedIds,
  }) {
    return FilteredTransactionBatchState(
      active: active,
      submitting: submitting ?? this.submitting,
      selectedIds: Set.unmodifiable(selectedIds ?? this.selectedIds),
    );
  }
}
