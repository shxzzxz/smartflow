import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/token/spacing.dart';
import '../../../widget/business/transaction_row.dart';
import '../view_model/account_transactions_view_model.dart';

class AccountTransactionsPage extends ConsumerWidget {
  const AccountTransactionsPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountTransactionsViewModelProvider(accountId));

    return Scaffold(
      appBar: AppBar(title: const Text('账户流水')),
      body: switch (state) {
        AccountTransactionsLoaded(:final rows) =>
          rows.isEmpty
              ? const Center(child: Text('暂无账户流水'))
              : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: rows.length,
                separatorBuilder:
                    (_, _) => const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return TransactionRow(
                    presentation: row,
                    enableQuickEdit: false,
                    onTap:
                        () => context.push('/transaction/${row.transactionId}'),
                  );
                },
              ),
        AccountTransactionsError(:final message) => Center(
          child: Text(message),
        ),
        AccountTransactionsLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      },
    );
  }
}
