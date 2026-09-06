import '../../../design_system/widget/app_popup_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_product_view_model.dart';
import '../presentation/loan_calculator_presentation.dart';

class InstallmentProductsPage extends ConsumerWidget {
  const InstallmentProductsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(installmentProductsViewModelProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '分期产品'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => context.push('/installment-products/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('新建产品'),
                ),
              ),
            ),
            Expanded(
              child: products.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(installmentProductsViewModelProvider),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const Center(child: Text('创建常用分期产品，借款时直接选择'))
                    : ListView(
                        children: [
                          for (final p in items) _row(context, ref, p),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    InstallmentProductReadModel p,
  ) => ListTile(
    title: Text('${p.name}${p.archived ? '（已归档）' : ''}'),
    subtitle: Text(
      p.stages
          .map(
            (s) =>
                s.method == null ? '免还期' : loanRepaymentMethodLabel(s.method!),
          )
          .join(' → '),
    ),
    onTap: () => context.push('/installment-products/${p.id}/edit'),
    trailing: AppPopupMenuButton(
      tooltip: '产品操作',
      icon: Icons.more_vert,
      items: [
        AppPopupMenuAction(
          label: '复制产品',
          onPressed: () =>
              context.push('/installment-products/${p.id}/edit?copy=true'),
        ),
        AppPopupMenuAction(
          label: p.archived ? '恢复产品' : '归档产品',
          onPressed: () async {
            final outcome = await ref
                .read(installmentProductsViewModelProvider.notifier)
                .archive(p.id, !p.archived);
            if (context.mounted) _showFailure(context, outcome);
          },
        ),
        AppPopupMenuAction(
          label: '删除未使用产品',
          onPressed: () async {
            final outcome = await ref
                .read(installmentProductsViewModelProvider.notifier)
                .delete(p.id);
            if (context.mounted) _showFailure(context, outcome);
          },
        ),
      ],
    ),
  );
  void _showFailure(BuildContext context, UiActionOutcome<void> outcome) {
    if (outcome case UiActionFailure<void>(:final error) when context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
