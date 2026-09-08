import '../../../design_system/widget/app_popup_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
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
            AppPageHeader(
              title: '分期产品',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新建产品',
                  onPressed: () => context.push('/installment-products/new'),
                ),
              ],
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
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.space16,
                          AppSpacing.space4,
                          AppSpacing.space16,
                          AppSpacing.space24,
                        ),
                        children: [
                          for (final p in items) ...[
                            _row(context, ref, p),
                            const SizedBox(height: AppSpacing.space12),
                          ],
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
  ) {
    return AppSurface(
      border: true,
      child: InkWell(
        onTap: () => context.push('/installment-products/${p.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.space16,
            top: AppSpacing.space8,
            right: AppSpacing.space8,
            bottom: AppSpacing.space8,
          ),
          child: Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${p.name}${p.archived ? '（已归档）' : ''}'),
                  subtitle: Text(
                    p.stages
                        .map(
                          (s) => s.method == null
                              ? '免还期'
                              : loanRepaymentMethodLabel(s.method!),
                        )
                        .join(' → '),
                  ),
                ),
              ),
              AppPopupMenuButton(
                tooltip: '产品操作',
                icon: Icons.more_vert,
                items: [
                  AppPopupMenuAction(
                    label: '复制产品',
                    onPressed: () => context.push(
                      '/installment-products/${p.id}/edit?copy=true',
                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showFailure(BuildContext context, UiActionOutcome<void> outcome) {
    if (outcome case UiActionFailure<void>(:final error) when context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
