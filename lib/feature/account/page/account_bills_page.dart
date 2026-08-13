import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/account_bills_view_model.dart';
import '../widget/account_bill_list.dart';

class AccountBillsPage extends ConsumerWidget {
  const AccountBillsPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountBillsViewModelProvider(accountId));
    final canGenerateHistoricalBill =
        state is AccountBillsPageLoaded && state.canGenerateHistoricalBill;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '全部账单',
              actions: [
                if (canGenerateHistoricalBill)
                  AppHeaderIconButton(
                    onPressed: () => _generateHistoricalBill(context, ref),
                    icon: RemixIcons.file_add_line,
                    tooltip: '生成历史账单',
                  ),
              ],
            ),
            Expanded(
              child: switch (state) {
                AccountBillsPageLoaded(:final bills) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  children: [AccountBillList(bills: bills)],
                ),
                AccountBillsPageNotFound() => const Center(
                  child: Text('账户不存在'),
                ),
                AccountBillsPageError(:final message) => Center(
                  child: Text(message),
                ),
                AccountBillsPageLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateHistoricalBill(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selected = await showAppMonthPicker(
      context: context,
      initialMonth: DateTime.now(),
      lastYear: DateTime.now().year,
      title: '选择账单月份',
    );
    if (selected == null) return;
    final outcome = await ref
        .read(accountBillsViewModelProvider(accountId).notifier)
        .generateHistoricalBill(selected);
    if (!context.mounted) return;
    final message = switch (outcome) {
      UiActionSuccess<void>() => '账单已生成',
      UiActionFailure<void>(:final error) => error.message,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
