import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../widget/business/transaction/transaction_feed.dart';
import '../view_model/filtered_transactions_view_model.dart';

class FilteredTransactionsPage extends ConsumerWidget {
  const FilteredTransactionsPage({
    required this.target,
    required this.targetId,
    super.key,
  });

  final FilteredTransactionTarget target;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      filteredTransactionsViewModelProvider(target, targetId),
    );
    final title = switch (state) {
      FilteredTransactionsLoaded(:final title) => title,
      _ => '交易流水',
    };
    final subtitle = switch (state) {
      FilteredTransactionsLoaded(:final subtitle) => subtitle,
      _ => null,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title, subtitle: subtitle),
            Expanded(
              child: switch (state) {
                FilteredTransactionsLoaded(
                  :final groups,
                  :final emptyMessage,
                  :final hasMore,
                  :final isLoadingMore,
                  :final loadMoreErrorMessage,
                ) =>
                  TransactionFeedScrollView(
                    groups: groups,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space16,
                      AppSpacing.space8,
                      AppSpacing.space16,
                      AppSpacing.space24,
                    ),
                    showDailyTotals: false,
                    emptyMessage: emptyMessage,
                    hasMore: hasMore,
                    isLoadingMore: isLoadingMore,
                    loadMoreErrorMessage: loadMoreErrorMessage,
                    onLoadMore: () {
                      ref
                          .read(
                            filteredTransactionsViewModelProvider(
                              target,
                              targetId,
                            ).notifier,
                          )
                          .loadMore();
                    },
                  ),
                FilteredTransactionsError(:final message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space24),
                    child: Text(message),
                  ),
                ),
                FilteredTransactionsLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
