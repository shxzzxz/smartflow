import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/provider.dart';
import '../../../design_system/token/spacing.dart';
import '../../home/widget/transaction_row.dart';

class AccountTransactionsPage extends ConsumerWidget {
  const AccountTransactionsPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(
      transactionListProvider(accountId: accountId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('账户流水')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('暂无账户流水'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.space16),
            itemCount: items.length,
            separatorBuilder:
                (_, _) => const SizedBox(height: AppSpacing.space8),
            itemBuilder: (context, index) {
              return TransactionRow(
                item: items[index],
                enableQuickEdit: false,
                viewAccountId: accountId,
              );
            },
          );
        },
      ),
    );
  }
}
