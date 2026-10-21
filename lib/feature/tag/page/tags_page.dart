import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/shared/name_dialog.dart';
import '../../../widget/business/shared/transaction_reference_target_sheet.dart';
import '../../../widget/business/tag/tag_search_field.dart';
import '../../shared/provider/tag_providers.dart';

final _logger = Logger('feature.tag');

/// 标签词表管理：新建、重命名、合并、迁移、排序与删除。
/// 删除标签会解除全部交易引用，确认时展示使用数量。
class TagsPage extends ConsumerStatefulWidget {
  const TagsPage({super.key});

  @override
  ConsumerState<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends ConsumerState<TagsPage> {
  late final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTagIds = {};
  var _searchQuery = '';
  var _batchMode = false;
  var _batchProcessing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tagsAsync = ref.watch(tagListProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: _batchMode ? '批量操作标签' : '标签管理',
              actions: _batchMode
                  ? [
                      AppHeaderIconButton(
                        onPressed: _batchProcessing ? null : _leaveBatchMode,
                        icon: RemixIcons.close_line,
                        tooltip: '取消批量操作',
                      ),
                      AppPopupMenuButton(
                        tooltip: '更多批量操作',
                        icon: RemixIcons.more_2_line,
                        items: [
                          AppPopupMenuAction(
                            label: '合并到…',
                            icon: RemixIcons.git_merge_line,
                            onPressed:
                                _selectedTagIds.isEmpty || _batchProcessing
                                ? null
                                : () => _retargetSelectedTags(
                                    context,
                                    TransactionReferenceOperation.merge,
                                  ),
                          ),
                          AppPopupMenuAction(
                            label: '迁移到…',
                            icon: RemixIcons.arrow_left_right_line,
                            onPressed:
                                _selectedTagIds.isEmpty || _batchProcessing
                                ? null
                                : () => _retargetSelectedTags(
                                    context,
                                    TransactionReferenceOperation.migrate,
                                  ),
                          ),
                        ],
                      ),
                      AppHeaderIconButton(
                        onPressed: _selectedTagIds.isEmpty || _batchProcessing
                            ? null
                            : () => _deleteSelectedTags(context),
                        icon: RemixIcons.delete_bin_line,
                        tooltip: '删除已选标签',
                      ),
                    ]
                  : [
                      AppHeaderIconButton(
                        onPressed: _enterBatchMode,
                        icon: RemixIcons.list_check_3,
                        tooltip: '批量操作标签',
                      ),
                      AppHeaderIconButton(
                        onPressed: () => _createTag(context, ref),
                        icon: RemixIcons.add_circle_line,
                        tooltip: '新建标签',
                      ),
                    ],
            ),
            Expanded(
              child: tagsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const Center(child: Text('标签加载失败，请稍后重试。')),
                data: (tags) => _buildTagContent(context, ref, tags, colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagContent(
    BuildContext context,
    WidgetRef ref,
    List<TagView> tags,
    ColorScheme colors,
  ) {
    final filteredTags = _filterTags(tags);

    if (tags.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space8,
            AppSpacing.space20,
            AppSpacing.space8,
          ),
          child: TagSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            enabled: !_batchProcessing,
          ),
        ),
        if (_batchMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space20,
              0,
              AppSpacing.space12,
              AppSpacing.space4,
            ),
            child: Row(
              children: [
                Expanded(child: Text('已选 ${_selectedTagIds.length} 个标签')),
                TextButton(
                  onPressed: filteredTags.isEmpty || _batchProcessing
                      ? null
                      : () => _toggleAll(filteredTags),
                  child: Text(_allSelected(filteredTags) ? '取消全选结果' : '全选结果'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _batchMode
              ? _buildBatchTagList(context, filteredTags)
              : filteredTags.isEmpty
              ? Center(
                  child: Text(
                    '没有匹配的标签',
                    style: context.appTextStyles.inputText,
                  ),
                )
              : _buildTagList(context, ref, filteredTags, tags),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: const Icon(RemixIcons.price_tag_3_line),
        title: '暂无标签',
        action: _batchMode
            ? null
            : FilledButton.icon(
                onPressed: () => _createTag(context, ref),
                icon: const Icon(RemixIcons.add_line),
                label: const Text('新建标签'),
              ),
      ),
    );
  }

  Widget _buildTagList(
    BuildContext context,
    WidgetRef ref,
    List<TagView> tags,
    List<TagView> allTags,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space20,
        AppSpacing.space24,
        AppSpacing.space20,
        AppSpacing.space48,
      ),
      children: [
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < tags.length; i++) ...[
                _TagRow(
                  tag: tags[i],
                  onTap: () {
                    final uri = Uri(path: '/tags/${tags[i].id}/transactions');
                    context.push(uri.toString());
                  },
                  canMoveUp:
                      allTags.indexWhere((tag) => tag.id == tags[i].id) > 0,
                  canMoveDown:
                      allTags.indexWhere((tag) => tag.id == tags[i].id) <
                      allTags.length - 1,
                  onMoveUp: () => ref
                      .read(tagApplicationServiceProvider)
                      .moveTag(id: tags[i].id, delta: -1),
                  onMoveDown: () => ref
                      .read(tagApplicationServiceProvider)
                      .moveTag(id: tags[i].id, delta: 1),
                  onRename: () => _renameTag(context, ref, tags[i]),
                  onMerge: () => _retargetTag(
                    context,
                    ref,
                    tags[i],
                    allTags,
                    TransactionReferenceOperation.merge,
                  ),
                  onMigrate: () => _retargetTag(
                    context,
                    ref,
                    tags[i],
                    allTags,
                    TransactionReferenceOperation.migrate,
                  ),
                  onDelete: () => _deleteTag(context, ref, tags[i]),
                ),
                if (i < tags.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(
                      left: AppSpacing.space16,
                      right: AppSpacing.space16,
                    ),
                    child: Divider(height: 1),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchTagList(BuildContext context, List<TagView> tags) {
    if (tags.isEmpty) {
      return Center(
        child: Text('没有匹配的标签', style: context.appTextStyles.inputText),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space20,
        AppSpacing.space8,
        AppSpacing.space20,
        AppSpacing.space48,
      ),
      children: [
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < tags.length; i++) ...[
                CheckboxListTile(
                  value: _selectedTagIds.contains(tags[i].id),
                  onChanged: _batchProcessing
                      ? null
                      : (_) => _toggleTag(tags[i].id),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                  ),
                  title: Text(
                    tags[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.formValue,
                  ),
                  subtitle: Text('${tags[i].usageCount} 笔交易'),
                ),
                if (i < tags.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.space16,
                    ),
                    child: Divider(height: 1),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<TagView> _filterTags(List<TagView> tags) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return tags;
    return [
      for (final tag in tags)
        if (tag.name.toLowerCase().contains(query)) tag,
    ];
  }

  bool _allSelected(List<TagView> tags) {
    return tags.isNotEmpty &&
        tags.every((tag) => _selectedTagIds.contains(tag.id));
  }

  void _enterBatchMode() {
    setState(() {
      _batchMode = true;
      _batchProcessing = false;
      _selectedTagIds.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _leaveBatchMode() {
    setState(() {
      _batchMode = false;
      _batchProcessing = false;
      _selectedTagIds.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _toggleTag(String id) {
    setState(() {
      if (!_selectedTagIds.remove(id)) _selectedTagIds.add(id);
    });
  }

  void _toggleAll(List<TagView> tags) {
    setState(() {
      if (_allSelected(tags)) {
        _selectedTagIds.removeAll(tags.map((tag) => tag.id));
      } else {
        _selectedTagIds.addAll(tags.map((tag) => tag.id));
      }
    });
  }

  Future<void> _deleteSelectedTags(BuildContext context) async {
    if (_selectedTagIds.isEmpty || _batchProcessing) return;

    final service = ref.read(tagApplicationServiceProvider);
    late final List<TagView> tags;
    try {
      tags = await service.listTags();
    } catch (error, stackTrace) {
      _logger.severe('Tag list load failed.', error, stackTrace);
      if (context.mounted) _showMessage(context, '标签加载失败，请稍后重试');
      return;
    }
    final selected = tags
        .where((tag) => _selectedTagIds.contains(tag.id))
        .toList(growable: false);
    if (selected.isEmpty || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除标签'),
        content: Text('确定删除选中的 ${selected.length} 个标签？删除后这些标签在交易上的引用也会被解除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _batchProcessing = true);
    try {
      await service.deleteTags({for (final tag in selected) tag.id});
      if (!context.mounted) return;
      _leaveBatchMode();
    } catch (error, stackTrace) {
      _logger.severe('Tag batch delete failed.', error, stackTrace);
      if (!context.mounted) return;
      setState(() => _batchProcessing = false);
      _showMessage(context, '批量删除失败，请稍后重试');
    }
  }

  Future<void> _retargetSelectedTags(
    BuildContext context,
    TransactionReferenceOperation operation,
  ) async {
    if (_selectedTagIds.isEmpty || _batchProcessing) return;

    final service = ref.read(tagApplicationServiceProvider);
    late final List<TagView> tags;
    try {
      tags = await service.listTags();
    } catch (error, stackTrace) {
      _logger.severe('Tag list load failed.', error, stackTrace);
      if (context.mounted) _showMessage(context, '标签加载失败，请稍后重试');
      return;
    }
    final selected = [
      for (final tag in tags)
        if (_selectedTagIds.contains(tag.id)) tag,
    ];
    final targets = [
      for (final tag in tags)
        if (!_selectedTagIds.contains(tag.id))
          TransactionReferenceTarget(
            id: tag.id,
            name: tag.name,
            usageCount: tag.usageCount,
          ),
    ];
    if (selected.isEmpty || !context.mounted) return;
    if (targets.isEmpty) {
      _showMessage(context, '没有其他标签可${operation.label}');
      return;
    }

    final target = await showTransactionReferenceTargetSheet(
      context,
      sourceDescription: '选中的 ${selected.length} 个标签',
      entityLabel: '标签',
      operation: operation,
      candidates: targets,
    );
    if (target == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('批量${operation.label}标签'),
        content: Text(
          operation == TransactionReferenceOperation.merge
              ? '将把选中的 ${selected.length} 个标签所关联的交易改指向'
                    '「${target.name}」，并删除这些源标签。'
              : '将把选中的 ${selected.length} 个标签所关联的交易改指向'
                    '「${target.name}」，并保留这些源标签。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(operation.label),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _batchProcessing = true);
    try {
      final sourceIds = {for (final tag in selected) tag.id};
      if (operation == TransactionReferenceOperation.merge) {
        await service.mergeTags(sourceIds: sourceIds, targetId: target.id);
      } else {
        await service.migrateTags(sourceIds: sourceIds, targetId: target.id);
      }
      if (!context.mounted) return;
      _leaveBatchMode();
    } catch (error, stackTrace) {
      _logger.severe('Tag batch retarget failed.', error, stackTrace);
      if (!context.mounted) return;
      setState(() => _batchProcessing = false);
      _showMessage(context, '批量${operation.label}失败，请稍后重试');
    }
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final name = await promptName(context, title: '新建标签', hintText: '标签名称');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(tagApplicationServiceProvider).createTag(name);
  }

  Future<void> _renameTag(
    BuildContext context,
    WidgetRef ref,
    TagView tag,
  ) async {
    final name = await promptName(
      context,
      title: '重命名标签',
      hintText: '标签名称',
      initialText: tag.name,
    );
    if (name == null || name.trim().isEmpty || name.trim() == tag.name) return;
    try {
      await ref
          .read(tagApplicationServiceProvider)
          .renameTag(id: tag.id, name: name);
    } on StateError {
      if (!context.mounted) return;
      _showMessage(context, '已有同名标签：${name.trim()}');
    }
  }

  Future<void> _retargetTag(
    BuildContext context,
    WidgetRef ref,
    TagView tag,
    List<TagView> all,
    TransactionReferenceOperation operation,
  ) async {
    final others = [
      for (final item in all)
        if (item.id != tag.id)
          TransactionReferenceTarget(
            id: item.id,
            name: item.name,
            usageCount: item.usageCount,
          ),
    ];
    if (others.isEmpty) {
      _showMessage(context, '没有其他标签可${operation.label}');
      return;
    }
    final target = await showTransactionReferenceTargetSheet(
      context,
      sourceDescription: '「${tag.name}」',
      entityLabel: '标签',
      operation: operation,
      candidates: others,
    );
    if (target == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${operation.label}标签'),
        content: Text(
          operation == TransactionReferenceOperation.merge
              ? '将把「${tag.name}」的 ${tag.usageCount} 笔交易改指向'
                    '「${target.name}」，并删除「${tag.name}」。'
              : '将把「${tag.name}」的 ${tag.usageCount} 笔交易改指向'
                    '「${target.name}」，并保留「${tag.name}」。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(operation.label),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = ref.read(tagApplicationServiceProvider);
    try {
      if (operation == TransactionReferenceOperation.merge) {
        await service.mergeTags(sourceIds: {tag.id}, targetId: target.id);
      } else {
        await service.migrateTags(sourceIds: {tag.id}, targetId: target.id);
      }
    } catch (error, stackTrace) {
      _logger.severe('Tag ${operation.name} failed.', error, stackTrace);
      if (context.mounted) {
        _showMessage(context, '${operation.label}失败，请稍后重试');
      }
    }
  }

  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    TagView tag,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text(
          tag.usageCount > 0
              ? '「${tag.name}」正在 ${tag.usageCount} 笔交易上使用，'
                    '删除后这些交易将不再携带该标签。'
              : '「${tag.name}」没有被任何交易使用。',
        ),
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
    if (confirmed != true) return;
    await ref.read(tagApplicationServiceProvider).deleteTag(tag.id);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.onTap,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRename,
    required this.onMerge,
    required this.onMigrate,
    required this.onDelete,
  });

  final TagView tag;
  final VoidCallback onTap;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRename;
  final VoidCallback onMerge;
  final VoidCallback onMigrate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyles.listTitle,
                  ),
                  Text(
                    '${tag.usageCount} 笔交易',
                    style: textStyles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: canMoveUp ? onMoveUp : null,
              icon: Icon(
                RemixIcons.arrow_up_s_line,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: '上移',
            ),
            IconButton(
              onPressed: canMoveDown ? onMoveDown : null,
              icon: Icon(
                RemixIcons.arrow_down_s_line,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: '下移',
            ),
            PopupMenuButton<String>(
              icon: Icon(
                RemixIcons.more_2_line,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              tooltip: '更多操作',
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    onRename();
                  case 'merge':
                    onMerge();
                  case 'migrate':
                    onMigrate();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(value: 'merge', child: Text('合并到…')),
                PopupMenuItem(value: 'migrate', child: Text('迁移到…')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
