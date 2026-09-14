import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../presentation/account_credit_summary_presentation.dart';
import '../view_model/account_installments_view_model.dart';
import '../widget/account_credit_summary_list.dart';

class AccountInstallmentsPage extends ConsumerWidget {
  const AccountInstallmentsPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountInstallmentsViewModelProvider(accountId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '全部分期合同'),
            Expanded(
              child: switch (state) {
                AsyncData(value: final AccountInstallmentsState value) =>
                  ListView(
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    children: [
                      AccountCreditSummaryList(
                        items: [
                          for (final contract in value.contracts)
                            installmentAccountCreditSummary(
                              contract,
                              accountKind: value.accountKind,
                            ),
                        ],
                        emptyMessage: '暂无分期合同',
                        onTap: (summary) =>
                            context.push('/installments/${summary.id}'),
                      ),
                    ],
                  ),
                AsyncData(value: null) => const Center(child: Text('账户不存在')),
                AsyncError() => const Center(child: Text('合同加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}
