import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../../design_system/widget/app_surface.dart';
import '../view_model/asset_page_view_model.dart';
import '../widget/asset_view_editor_actions.dart';

class AssetViewsPage extends ConsumerWidget {
  const AssetViewsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(assetViewsProvider);
    final busy = ref.watch(assetViewManagementViewModelProvider);
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '管理视图',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新增视图',
                  onPressed: busy ? null : () => _create(context),
                ),
              ],
            ),
            Expanded(
              child: views.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, trace) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(assetViewsProvider),
                    child: const Text('视图加载失败，点击重试'),
                  ),
                ),
                data: (views) => ReorderableListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  buildDefaultDragHandles: false,
                  itemCount: views.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    final outcome = await ref
                        .read(assetViewManagementViewModelProvider.notifier)
                        .reorderViews(views, oldIndex, newIndex);
                    if (context.mounted) showAssetViewFailure(context, outcome);
                  },
                  itemBuilder: (context, index) {
                    final view = views[index];
                    return Padding(
                      key: ValueKey(view.id),
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.space12,
                      ),
                      child: AppSurface(
                        child: ListTile(
                          onTap: busy ? null : () => _edit(context, view),
                          leading: view.isBuiltin
                              ? const Icon(RemixIcons.wallet_3_line)
                              : ReorderableDelayedDragStartListener(
                                  index: index,
                                  enabled: !busy,
                                  child: const Icon(RemixIcons.draggable),
                                ),
                          title: Text(view.name),
                          subtitle: Text('${view.accountIds.length} 个账户'),
                          trailing: AppPopupMenuButton(
                            icon: RemixIcons.more_2_fill,
                            tooltip: '视图操作',
                            items: [
                              AppPopupMenuAction(
                                label: '编辑视图',
                                icon: RemixIcons.edit_line,
                                onPressed: busy
                                    ? null
                                    : () => _edit(context, view),
                              ),
                              AppPopupMenuAction(
                                label: '复制视图',
                                icon: RemixIcons.file_copy_line,
                                onPressed: busy
                                    ? null
                                    : () => _create(context, copyFrom: view),
                              ),
                              if (!view.isBuiltin)
                                AppPopupMenuAction(
                                  label: '删除视图',
                                  icon: RemixIcons.delete_bin_line,
                                  onPressed: busy
                                      ? null
                                      : () => _delete(context, ref, view),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, AssetView view) => context
      .push<String>('/assets/views/${Uri.encodeComponent(view.id)}/edit');
  Future<void> _create(BuildContext context, {AssetView? copyFrom}) async {
    final id = await context.push<String>('/assets/views/new', extra: copyFrom);
    if (id != null && context.mounted) context.pop(id);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AssetView view,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除“${view.name}”？'),
        content: const Text('删除视图会移除它的展示配置，账户和交易仍可在其他视图中查看。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final outcome = await ref
        .read(assetViewManagementViewModelProvider.notifier)
        .deleteView(view.id);
    if (context.mounted) showAssetViewFailure(context, outcome);
  }
}
