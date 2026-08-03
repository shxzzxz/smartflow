import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/business_icon_bubble.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/categories_view_model.dart';

/// 分类行操作菜单：编辑 / 新增子分类 / 移动到… / 迁移交易 / 删除。
Future<void> showCategoryActionSheet(
  BuildContext context,
  WidgetRef ref, {
  required Account category,
  required bool hasActiveChildren,
  required List<CategoryNode> tree,
}) async {
  final action = await showModalBottomSheet<_CategoryAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      final isRoot = category.parentId == null;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: BusinessIconBubble(
                size: AppSpacing.space32,
                child: BusinessIcon(iconKey: category.iconKey, size: 24),
              ),
              title: Text(category.name),
              subtitle: isRoot ? null : const Text('子分类'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(RemixIcons.edit_line),
              title: const Text('编辑'),
              onTap: () => Navigator.of(sheetContext).pop(_CategoryAction.edit),
            ),
            if (isRoot)
              ListTile(
                leading: const Icon(RemixIcons.add_line),
                title: const Text('新增子分类'),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_CategoryAction.addChild),
              ),
            if (!hasActiveChildren)
              ListTile(
                leading: const Icon(RemixIcons.folder_transfer_line),
                title: const Text('移动到…'),
                onTap:
                    () =>
                        Navigator.of(sheetContext).pop(_CategoryAction.move),
              ),
            ListTile(
              leading: const Icon(RemixIcons.swap_line),
              title: const Text('迁移交易'),
              onTap:
                  () =>
                      Navigator.of(sheetContext).pop(_CategoryAction.migrate),
            ),
            ListTile(
              leading: Icon(RemixIcons.delete_bin_line, color: colors.error),
              title: Text('删除', style: TextStyle(color: colors.error)),
              onTap:
                  () => Navigator.of(sheetContext).pop(_CategoryAction.delete),
            ),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _CategoryAction.edit:
      context.push('/category/${category.id}/edit');
    case _CategoryAction.addChild:
      final uri = Uri(
        path: '/category/new',
        queryParameters: {
          'type': category.type.name,
          'parentId': category.id,
        },
      );
      context.push(uri.toString());
    case _CategoryAction.move:
      await showCategoryMoveSheet(context, ref, category: category, tree: tree);
    case _CategoryAction.migrate:
      await runCategoryMigrationFlow(context, ref, category: category);
    case _CategoryAction.delete:
      await runCategoryDeleteFlow(context, ref, category: category);
  }
}

enum _CategoryAction { edit, addChild, move, migrate, delete }

/// 快捷移动：改父分类（active 二层树内），复用 editCategory 链路。
Future<void> showCategoryMoveSheet(
  BuildContext context,
  WidgetRef ref, {
  required Account category,
  required List<CategoryNode> tree,
}) async {
  final rootTargets = [
    for (final node in tree)
      if (node.account.id != category.id &&
          node.account.id != category.parentId)
        node.account,
  ];
  final canPromote = category.parentId != null;
  if (rootTargets.isEmpty && !canPromote) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('没有可移动到的分类')));
    return;
  }

  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Text(
                '移动"${category.name}"到',
                style: sheetContext.appTextStyles.sectionTitleStrong,
              ),
            ),
            if (canPromote)
              ListTile(
                leading: const Icon(RemixIcons.corner_up_right_line),
                title: const Text('设为一级分类'),
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
            for (final target in rootTargets)
              ListTile(
                leading: BusinessIconBubble(
                  size: AppSpacing.space32,
                  child: BusinessIcon(iconKey: target.iconKey, size: 24),
                ),
                title: Text(target.name),
                onTap: () => Navigator.of(sheetContext).pop(target.id),
              ),
          ],
        ),
      );
    },
  );
  if (selected == null || !context.mounted) return;

  final outcome = await ref
      .read(categoriesViewModelProvider.notifier)
      .moveCategory(
        category.id,
        newParentId: selected.isEmpty ? null : selected,
      );
  if (!context.mounted) return;
  if (outcome case UiActionFailure(:final error)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }
}

/// 迁移流程：选同类型活跃目标分类，把命中源分类的全部交易组改到目标分类。
/// 迁移与删除不捆绑，迁移完成后由用户自行再次发起删除。
Future<void> runCategoryMigrationFlow(
  BuildContext context,
  WidgetRef ref, {
  required Account category,
}) async {
  final targetId = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _MigrationTargetSheet(source: category),
  );
  if (targetId == null || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('迁移"${category.name}"的交易？'),
        content: const Text('该分类的全部交易将改到所选分类，历史统计随之变化；任何一笔失败都会整体回滚。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('迁移'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;

  final outcome = await ref
      .read(categoriesViewModelProvider.notifier)
      .migrateTransactions(
        sourceCategoryId: category.id,
        targetCategoryId: targetId,
      );
  if (!context.mounted) return;
  final message = switch (outcome) {
    UiActionSuccess(:final value) =>
      value.migratedGroupCount == 0
          ? '该分类没有需要迁移的交易'
          : '已迁移 ${value.migratedGroupCount} 笔交易',
    UiActionFailure(:final error) => error.message,
  };
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

/// 删除流程：预演 → 有子分类或有交易引用则拒绝并提示；否则确认后物理删除。
Future<void> runCategoryDeleteFlow(
  BuildContext context,
  WidgetRef ref, {
  required Account category,
}) async {
  final previewOutcome = await ref
      .read(categoriesViewModelProvider.notifier)
      .previewDeletion(category.id);
  if (!context.mounted) return;

  final CategoryDeletionPreview preview;
  switch (previewOutcome) {
    case UiActionFailure(:final error):
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    case UiActionSuccess(:final value):
      preview = value;
  }

  if (preview.childCount > 0) {
    await _showDeleteBlockedDialog(
      context,
      title: '无法删除"${category.name}"',
      message: '该分类还有 ${preview.childCount} 个子分类。请先迁移或删除全部子分类，再删除一级分类。',
    );
    return;
  }
  if (preview.transactionRefCount > 0) {
    await _showDeleteBlockedDialog(
      context,
      title: '无法删除"${category.name}"',
      message:
          '该分类被 ${preview.transactionRefCount} 处交易引用。'
          '请先使用"迁移交易"把交易改到其它分类，再删除该分类。',
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text('删除"${category.name}"？'),
        content: const Text('该分类没有交易记录，将被彻底删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  final outcome = await ref
      .read(categoriesViewModelProvider.notifier)
      .deleteCategory(category.id);
  if (!context.mounted) return;
  final message = switch (outcome) {
    UiActionSuccess() => '分类已删除',
    UiActionFailure(:final error) => error.message,
  };
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _showDeleteBlockedDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

/// 迁移目标选择：同类型活跃分类树，一级、二级皆可选，排除源分类自身。
class _MigrationTargetSheet extends ConsumerStatefulWidget {
  const _MigrationTargetSheet({required this.source});

  final Account source;

  @override
  ConsumerState<_MigrationTargetSheet> createState() =>
      _MigrationTargetSheetState();
}

class _MigrationTargetSheetState extends ConsumerState<_MigrationTargetSheet> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final source = widget.source;
    final treeAsync = ref.watch(categoryTreeProvider(source.type));
    final candidates = <(Account, bool)>[
      for (final node in treeAsync.value ?? const <CategoryNode>[]) ...[
        if (node.account.id != source.id) (node.account, false),
        for (final child in node.children)
          if (child.id != source.id) (child, true),
      ],
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space20,
                0,
                AppSpacing.space20,
                AppSpacing.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '迁移"${source.name}"的交易到',
                    style: textStyles.sectionTitleStrong,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    '所有引用该分类的交易将改为所选分类。',
                    style: textStyles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (candidates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.space20),
                      child: Text(
                        '没有可用的目标分类，请先新建一个同类型分类。',
                        style: textStyles.listSupporting.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final (candidate, isChild) in candidates)
                    ListTile(
                      contentPadding: EdgeInsets.only(
                        left:
                            isChild
                                ? AppSpacing.space48
                                : AppSpacing.space16,
                        right: AppSpacing.space16,
                      ),
                      leading: BusinessIconBubble(
                        size: AppSpacing.space32,
                        child: BusinessIcon(
                          iconKey: candidate.iconKey,
                          size: 24,
                        ),
                      ),
                      title: Text(candidate.name),
                      trailing: Icon(
                        _selectedId == candidate.id
                            ? RemixIcons.checkbox_circle_fill
                            : RemixIcons.checkbox_blank_circle_line,
                        color:
                            _selectedId == candidate.id
                                ? colors.primary
                                : colors.onSurfaceVariant,
                      ),
                      onTap:
                          () => setState(() => _selectedId = candidate.id),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space20,
                AppSpacing.space12,
                AppSpacing.space20,
                AppSpacing.space16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(_selectedId),
                  child: const Text('迁移交易'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
