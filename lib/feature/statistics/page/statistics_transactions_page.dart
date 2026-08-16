import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../widget/business/transaction/transaction_feed.dart';
import '../view_model/statistics_view_model.dart';

class StatisticsTransactionsPage extends ConsumerWidget {
  const StatisticsTransactionsPage({
    required this.title,
    required this.category,
    required this.settlementAccountId,
    required this.tagId,
    required this.untaggedOnly,
    required this.occurredFrom,
    required this.occurredUntil,
    required this.scope,
    super.key,
  });

  final String title;
  final CategorySelection? category;
  final String? settlementAccountId;
  final String? tagId;
  final bool untaggedOnly;
  final DateTime? occurredFrom;
  final DateTime occurredUntil;
  final StatisticsDrilldownScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cutoffDate = occurredUntil.subtract(const Duration(microseconds: 1));
    final content = ref.watch(
      statisticsTransactionsContentProvider(
        category: category,
        settlementAccountId: settlementAccountId,
        tagId: tagId,
        untaggedOnly: untaggedOnly,
        occurredFrom: occurredFrom,
        occurredUntil: occurredUntil,
        scope: scope,
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: title,
              subtitle:
                  occurredFrom == null
                      ? '截至${cutoffDate.year}年${cutoffDate.month}月的贡献流水'
                      : '${occurredFrom!.year}年${occurredFrom!.month}月贡献流水',
            ),
            Expanded(
              child: switch (content) {
                StatisticsTransactionsContentLoaded(:final groups) =>
                  TransactionFeedScrollView(
                    groups: groups,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space16,
                      AppSpacing.space8,
                      AppSpacing.space16,
                      AppSpacing.space24,
                    ),
                    showDailyTotals: false,
                    emptyMessage: '该分类暂无贡献流水',
                  ),
                StatisticsTransactionsContentError(:final message) => Center(
                  child: Text(message),
                ),
                StatisticsTransactionsContentLoading() => const Center(
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
