import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/tag/tag_name_dialog.dart';
import '../../../widget/business/tag/tag_search_field.dart';
import '../../shared/provider/tag_providers.dart';

/// 标签词表管理：新建、重命名、合并、排序与删除。
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
  var _batchDeleteMode = false;
  var _batchDeleting = false;

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
              title: _batchDeleteMode ? '批量删除标签' : '标签管理',
              actions: _batchDeleteMode
                  ? [
                      AppHeaderIconButton(
                        onPressed: _batchDeleting ? null : _leaveBatchMode,
                        icon: RemixIcons.close_line,
                        tooltip: '取消批量删除',
                      ),
                      AppHeaderIconButton(
                        onPressed: _selectedTagIds.isEmpty || _batchDeleting
                            ? null
                            : () => _deleteSelectedTags(context),
                        icon: RemixIcons.delete_bin_line,
                        tooltip: '删除已选标签',
                      ),
                    ]
                  : [
                      AppHeaderIconButton(
                        onPressed: _enterBatchMode,
                        icon: RemixIcons.delete_bin_line,
                        tooltip: '批量删除标签',
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
                    Center(child: Text('标签加载失败：$error')),
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
    final list = _batchDeleteMode
        ? _buildBatchTagList(context, filteredTags)
        : _buildTagList(context, ref, tags);

    if (tags.isEmpty) {
      return _buildEmptyState(context, colors);
    }

    if (_batchDeleteMode) {
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
              enabled: !_batchDeleting,
            ),
          ),
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
                  onPressed: filteredTags.isEmpty || _batchDeleting
                      ? null
                      : () => _toggleAll(filteredTags),
                  child: Text(_allSelected(filteredTags) ? '取消全选结果' : '全选结果'),
                ),
              ],
            ),
          ),
          Expanded(child: list),
        ],
      );
    }

    return list;
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(RemixIcons.price_tag_3_line, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.space12),
            Text('暂无标签', style: context.appTextStyles.inputText),
            const SizedBox(height: AppSpacing.space12),
            if (!_batchDeleteMode)
              FilledButton.icon(
                onPressed: () => _createTag(context, ref),
                icon: const Icon(RemixIcons.add_line),
                label: const Text('新建标签'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagList(
    BuildContext context,
    WidgetRef ref,
    List<TagView> tags,
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
                  canMoveUp: i > 0,
                  canMoveDown: i < tags.length - 1,
                  onMoveUp: () => ref
                      .read(tagApplicationServiceProvider)
                      .moveTag(id: tags[i].id, delta: -1),
                  onMoveDown: () => ref
                      .read(tagApplicationServiceProvider)
                      .moveTag(id: tags[i].id, delta: 1),
                  onRename: () => _renameTag(context, ref, tags[i]),
                  onMerge: () => _mergeTag(context, ref, tags[i], tags),
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
                  onChanged: _batchDeleting
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
      _batchDeleteMode = true;
      _batchDeleting = false;
      _selectedTagIds.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _leaveBatchMode() {
    setState(() {
      _batchDeleteMode = false;
      _batchDeleting = false;
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
    if (_selectedTagIds.isEmpty || _batchDeleting) return;

    final service = ref.read(tagApplicationServiceProvider);
    late final List<TagView> tags;
    try {
      tags = await service.listTags();
    } catch (_) {
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

    setState(() => _batchDeleting = true);
    try {
      for (final tag in selected) {
        await service.deleteTag(tag.id);
      }
      if (!context.mounted) return;
      _leaveBatchMode();
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _batchDeleting = false);
      _showMessage(context, '批量删除失败，请稍后重试');
    }
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final name = await promptTagName(context, title: '新建标签');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(tagApplicationServiceProvider).createTag(name);
  }

  Future<void> _renameTag(
    BuildContext context,
    WidgetRef ref,
    TagView tag,
  ) async {
    final name = await promptTagName(
      context,
      title: '重命名标签',
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

  Future<void> _mergeTag(
    BuildContext context,
    WidgetRef ref,
    TagView tag,
    List<TagView> all,
  ) async {
    final others = all.where((item) => item.id != tag.id).toList();
    if (others.isEmpty) {
      _showMessage(context, '没有其他标签可合并');
      return;
    }
    final target = await showModalBottomSheet<TagView>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Text(
                '把「${tag.name}」合并到',
                style: context.appTextStyles.subsectionTitle,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final other in others)
                    ListTile(
                      title: Text(other.name),
                      subtitle: Text('${other.usageCount} 笔交易'),
                      onTap: () => Navigator.of(context).pop(other),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (target == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('合并标签'),
        content: Text(
          '将把「${tag.name}」的 ${tag.usageCount} 笔交易改指向'
          '「${target.name}」，并删除「${tag.name}」。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('合并'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(tagApplicationServiceProvider)
        .mergeTags(sourceId: tag.id, targetId: target.id);
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
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(value: 'merge', child: Text('合并到…')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
