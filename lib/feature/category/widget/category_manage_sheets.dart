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

/// 分类行操作菜单：编辑 / 新增子分类 / 移动到… / 删除。
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
    case _CategoryAction.delete:
      await runCategoryDeleteFlow(context, ref, category: category);
  }
}

enum _CategoryAction { edit, addChild, move, delete }

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

/// 删除流程：预演 → 无引用无挂载直接确认物理删除；
/// 否则选承接分类，归档并把统计归属并入承接。
Future<void> runCategoryDeleteFlow(
  BuildContext context,
  WidgetRef ref, {
  required Account category,
}) async {
  final viewModel = ref.read(categoriesViewModelProvider.notifier);
  final previewOutcome = await viewModel.previewDeletion(category.id);
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

  if (!preview.requiresMergeTarget) {
    final childCount = preview.children.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text('删除"${category.name}"？'),
          content: Text(
            childCount == 0
                ? '该分类没有交易记录，将被彻底删除。'
                : '该分类及其 $childCount 个子分类均没有交易记录，将被一并彻底删除。',
          ),
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
    final outcome = await viewModel.deleteCategory(category.id);
    if (!context.mounted) return;
    _showDeleteOutcome(context, outcome);
    return;
  }

  final mergeTargetId = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (sheetContext) => _MergeTargetSheet(preview: preview),
  );
  if (mergeTargetId == null || !context.mounted) return;
  final outcome = await viewModel.deleteCategory(
    category.id,
    mergeTargetId: mergeTargetId,
  );
  if (!context.mounted) return;
  _showDeleteOutcome(context, outcome);
}

void _showDeleteOutcome(BuildContext context, UiActionOutcome<void> outcome) {
  final message = switch (outcome) {
    UiActionSuccess() => '分类已删除',
    UiActionFailure(:final error) => error.message,
  };
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

/// 承接分类选择：展示整树处置明细，从同类型 active 树中选归并目标。
class _MergeTargetSheet extends ConsumerStatefulWidget {
  const _MergeTargetSheet({required this.preview});

  final CategoryDeletionPreview preview;

  @override
  ConsumerState<_MergeTargetSheet> createState() => _MergeTargetSheetState();
}

class _MergeTargetSheetState extends ConsumerState<_MergeTargetSheet> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final preview = widget.preview;
    final root = preview.root.category;
    final treeAsync = ref.watch(categoryTreeProvider(root.type));
    final candidates = <(Account, bool)>[
      for (final node in treeAsync.value ?? const <CategoryNode>[])
        if (!preview.excludedTargetIds.contains(node.account.id)) ...[
          (node.account, false),
          for (final child in node.children)
            if (!preview.excludedTargetIds.contains(child.id)) (child, true),
        ],
    ];
    final archivedNames = [
      for (final node in preview.nodes)
        if (node.disposition == CategoryDeletionDisposition.archiveMerge)
          node.category.name,
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
                  Text('删除"${root.name}"', style: textStyles.sectionTitleStrong),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    _buildSummary(preview, archivedNames),
                    style: textStyles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text('选择承接分类', style: textStyles.formValue),
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
                        '没有可用的承接分类，请先新建一个同类型分类。',
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
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  child: const Text('删除并归并'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _buildSummary(
  CategoryDeletionPreview preview,
  List<String> archivedNames,
) {
  final buffer = StringBuffer()
    ..write('共 ${preview.totalEntryCount} 笔交易。删除后历史交易保留，')
    ..write('${archivedNames.join('、')}将归档并把统计并入承接分类');
  final deleted = [
    for (final node in preview.nodes)
      if (node.disposition == CategoryDeletionDisposition.physicalDelete)
        node.category.name,
  ];
  if (deleted.isNotEmpty) {
    buffer.write('；${deleted.join('、')}没有交易，将被彻底删除');
  }
  if (preview.mounts.isNotEmpty) {
    buffer.write('；另有 ${preview.mounts.length} 个已归档分类将随之转移');
  }
  buffer.write('。');
  return buffer.toString();
}
