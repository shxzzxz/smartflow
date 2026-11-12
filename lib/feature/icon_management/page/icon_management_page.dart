import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/data_management/icons/user_business_icon_models.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/icon/business_icon.dart';
import '../../../widget/business/icon/business_icon_bubble.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/icon_management_view_model.dart';

class IconManagementPage extends ConsumerStatefulWidget {
  const IconManagementPage({super.key});

  @override
  ConsumerState<IconManagementPage> createState() => _IconManagementPageState();
}

class _IconManagementPageState extends ConsumerState<IconManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(iconManagementViewModelProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(iconManagementViewModelProvider);
    final type = _tabController.index == 0
        ? UserBusinessIconType.account
        : UserBusinessIconType.category;
    final icons = state.icons
        .where((entry) => entry.icon.type == type)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader.custom(
              titleContent: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: context.appTextStyles.largeTabLabel(selected: true),
                unselectedLabelStyle: context.appTextStyles.largeTabLabel(
                  selected: false,
                ),
                tabs: const [
                  Tab(text: '账户图标'),
                  Tab(text: '分类图标'),
                ],
              ),
              actions: [
                AppHeaderIconButton(
                  onPressed: state.busy ? null : () => _upload(type),
                  icon: RemixIcons.add_circle_line,
                  tooltip: '上传图标',
                ),
              ],
            ),
            if (state.busy)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            Expanded(
              child: switch ((state.loading, state.loadError)) {
                (true, null) when state.icons.isEmpty => const Center(
                  child: CircularProgressIndicator(),
                ),
                (_, final error?) => _LoadError(
                  message: error.message,
                  onRetry: () => ref
                      .read(iconManagementViewModelProvider.notifier)
                      .refresh(),
                ),
                _ =>
                  icons.isEmpty
                      ? _EmptyIcons(type: type, onUpload: () => _upload(type))
                      : _IconList(
                          entries: icons,
                          busy: state.busy,
                          onDelete: _delete,
                        ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload(UserBusinessIconType type) async {
    final outcome = await ref
        .read(iconManagementViewModelProvider.notifier)
        .upload(type);
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess(value: final icon?):
        _showMessage('已添加图标“${icon.label}”。');
      case UiActionSuccess():
        break;
      case UiActionFailure(:final error):
        _showMessage(error.message);
    }
  }

  Future<void> _delete(UserBusinessIconEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除图标'),
        content: Text('确定删除“${entry.icon.label}”吗？删除后无法恢复。'),
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
    if (confirmed != true || !mounted) return;
    final outcome = await ref
        .read(iconManagementViewModelProvider.notifier)
        .delete(entry.icon);
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess():
        _showMessage('图标已删除。');
      case UiActionFailure(:final error):
        _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _IconList extends StatelessWidget {
  const _IconList({
    required this.entries,
    required this.busy,
    required this.onDelete,
  });

  final List<UserBusinessIconEntry> entries;
  final bool busy;
  final ValueChanged<UserBusinessIconEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space20,
        AppSpacing.space16,
        AppSpacing.space20,
        AppSpacing.space48,
      ),
      children: [
        AppSurface(
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                _IconRow(
                  entry: entries[index],
                  busy: busy,
                  onDelete: () => onDelete(entries[index]),
                ),
                if (index < entries.length - 1)
                  const Divider(
                    height: 1,
                    indent: AppSpacing.space48 + AppSpacing.space24,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.entry,
    required this.busy,
    required this.onDelete,
  });

  final UserBusinessIconEntry entry;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final inUse = entry.usageCount > 0;
    final typeLabel = entry.icon.type == UserBusinessIconType.account
        ? '账户'
        : '分类';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space12,
      ),
      child: Row(
        children: [
          BusinessIconBubble(
            size: 44,
            bubbleColor: colors.surfaceContainerHighest,
            child: BusinessIcon(
              iconRef: entry.icon.refId,
              usage: entry.icon.type == UserBusinessIconType.account
                  ? BusinessIconUsage.account
                  : BusinessIconUsage.expenseCategory,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.icon.label,
                  style: context.appTextStyles.listTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  inUse ? '已被 $typeLabel使用 ${entry.usageCount} 次' : '未使用',
                  style: context.appTextStyles.listSupporting,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy || inUse ? null : onDelete,
            icon: const Icon(RemixIcons.delete_bin_line),
            tooltip: inUse ? '正在使用，无法删除' : '删除图标',
          ),
        ],
      ),
    );
  }
}

class _EmptyIcons extends StatelessWidget {
  const _EmptyIcons({required this.type, required this.onUpload});

  final UserBusinessIconType type;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final typeLabel = type == UserBusinessIconType.account ? '账户' : '分类';
    return Center(
      child: AppEmptyState(
        icon: const Icon(RemixIcons.image_add_line),
        title: '暂无$typeLabel图标',
        message: '支持 PNG、JPEG、WebP。上传后会出现在 $typeLabel 图标选择器中。',
        action: FilledButton.icon(
          onPressed: onUpload,
          icon: const Icon(RemixIcons.upload_2_line),
          label: const Text('上传图标'),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: const Icon(RemixIcons.error_warning_line),
        title: '图标加载失败',
        message: message,
        action: OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ),
    );
  }
}
