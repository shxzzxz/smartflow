import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../view_model/asset_views_provider.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../../widget/business/shared/name_dialog.dart';
import '../view_model/account_organization_view_model.dart';

Future<void> showAccountGroupManagerSheet(
  BuildContext context, {
  required String viewId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AccountGroupManagerSheet(viewId: viewId),
  );
}

class _AccountGroupManagerSheet extends ConsumerWidget {
  const _AccountGroupManagerSheet({required this.viewId});
  final String viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(assetViewGroupsProvider(viewId));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: switch (groupsAsync) {
          AsyncData(value: final groups) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space20,
                  vertical: AppSpacing.space8,
                ),
                child: Row(
                  children: [
                    Text(
                      '管理账户分组',
                      style: context.appTextStyles.sectionTitleStrong,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _createGroup(context, ref),
                      icon: const Icon(RemixIcons.add_line),
                      label: const Text('新建分组'),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.space20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('长按并拖动可调整分组顺序'),
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: groups.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorderGroups(context, ref, groups, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      key: ValueKey(group.id),
                      leading: ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Icon(RemixIcons.draggable),
                      ),
                      title: Text(group.name),
                      trailing: PopupMenuButton<_AccountGroupAction>(
                        position: PopupMenuPosition.under,
                        onSelected: (action) => _handleAction(
                          context,
                          ref,
                          group: group,
                          action: action,
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _AccountGroupAction.rename,
                            child: Text('重命名'),
                          ),
                          PopupMenuItem(
                            value: _AccountGroupAction.delete,
                            child: Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          AsyncError() => const Center(child: Text('分组加载失败，请稍后重试')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await _requestGroupName(context, title: '新建分组');
    if (name == null || !context.mounted) return;
    final outcome = await ref
        .read(accountOrganizationViewModelProvider(viewId).notifier)
        .createGroup(name);
    if (!context.mounted) return;
    _showGroupOutcome(context, outcome, successMessage: '分组已创建');
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref, {
    required AssetViewGroup group,
    required _AccountGroupAction action,
  }) async {
    switch (action) {
      case _AccountGroupAction.rename:
        final name = await _requestGroupName(
          context,
          title: '重命名分组',
          initialValue: group.name,
        );
        if (name == null || !context.mounted) return;
        final outcome = await ref
            .read(accountOrganizationViewModelProvider(viewId).notifier)
            .renameGroup(group.id, name);
        if (!context.mounted) return;
        _showGroupOutcome(context, outcome, successMessage: '分组已重命名');
      case _AccountGroupAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('删除“${group.name}”？'),
            content: const Text('该分组中的账户会变为未分组，账户本身不会被删除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final outcome = await ref
            .read(accountOrganizationViewModelProvider(viewId).notifier)
            .deleteGroup(group.id);
        if (!context.mounted) return;
        _showGroupOutcome(context, outcome, successMessage: '分组已删除');
    }
  }

  Future<void> _reorderGroups(
    BuildContext context,
    WidgetRef ref,
    List<AssetViewGroup> groups,
    int oldIndex,
    int newIndex,
  ) async {
    final ordered = [...groups];
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    final outcome = await ref
        .read(accountOrganizationViewModelProvider(viewId).notifier)
        .reorderGroups([for (final group in ordered) group.id]);
    if (!context.mounted) return;
    _showGroupOutcome(context, outcome, successMessage: '分组顺序已更新');
  }
}

enum _AccountGroupAction { rename, delete }

Future<String?> _requestGroupName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) => promptName(
  context,
  title: title,
  hintText: '请输入分组名称',
  initialText: initialValue,
  maxLength: 120,
);

void _showGroupOutcome(
  BuildContext context,
  UiActionOutcome<void> outcome, {
  required String successMessage,
}) {
  if (!context.mounted) return;
  final message = switch (outcome) {
    UiActionSuccess() => successMessage,
    UiActionFailure(:final error) => error.message,
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
