import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/shared/name_dialog.dart';
import '../../../widget/business/tag/tag_search_field.dart';
import '../../shared/provider/counterparty_providers.dart';
import '../view_model/counterparty_management_view_model.dart';

class CounterpartiesPage extends ConsumerStatefulWidget {
  const CounterpartiesPage({super.key});

  @override
  ConsumerState<CounterpartiesPage> createState() => _CounterpartiesPageState();
}

class _CounterpartiesPageState extends ConsumerState<CounterpartiesPage> {
  final _searchController = TextEditingController();
  var _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final counterparties = ref.watch(counterpartyListProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '对手方管理',
              actions: [
                AppHeaderIconButton(
                  onPressed: () => _createCounterparty(context),
                  icon: RemixIcons.add_circle_line,
                  tooltip: '新建对手方',
                ),
              ],
            ),
            Expanded(
              child: counterparties.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    const Center(child: Text('对手方加载失败，请稍后重试。')),
                data: (items) => _buildContent(context, items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<CounterpartyView> counterparties,
  ) {
    if (counterparties.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: const Icon(RemixIcons.user_shared_line),
          title: '暂无对手方',
          message: '录入交易时也可以直接创建对手方。',
          action: FilledButton.icon(
            onPressed: () => _createCounterparty(context),
            icon: const Icon(RemixIcons.add_line),
            label: const Text('新建对手方'),
          ),
        ),
      );
    }
    final filtered = _filter(counterparties);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space8,
            AppSpacing.space20,
            AppSpacing.space12,
          ),
          child: TagSearchField(
            controller: _searchController,
            hintText: '搜索对手方',
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('没有匹配的对手方'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space20,
                    0,
                    AppSpacing.space20,
                    AppSpacing.space48,
                  ),
                  children: [
                    AppSurface(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < filtered.length;
                            index++
                          ) ...[
                            _CounterpartyRow(
                              counterparty: filtered[index],
                              onRename: () =>
                                  _renameCounterparty(context, filtered[index]),
                              onDelete: () =>
                                  _deleteCounterparty(context, filtered[index]),
                            ),
                            if (index < filtered.length - 1)
                              const AppListDivider(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  List<CounterpartyView> _filter(List<CounterpartyView> counterparties) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return counterparties;
    return [
      for (final counterparty in counterparties)
        if (counterparty.name.toLowerCase().contains(query)) counterparty,
    ];
  }

  Future<void> _createCounterparty(BuildContext context) async {
    final name = await promptName(context, title: '新建对手方', hintText: '对手方名称');
    if (name == null || name.trim().isEmpty) return;
    final outcome = await ref
        .read(counterpartyManagementViewModelProvider.notifier)
        .create(name);
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _renameCounterparty(
    BuildContext context,
    CounterpartyView counterparty,
  ) async {
    final name = await promptName(
      context,
      title: '重命名对手方',
      hintText: '对手方名称',
      initialText: counterparty.name,
    );
    if (name == null ||
        name.trim().isEmpty ||
        name.trim() == counterparty.name) {
      return;
    }
    final outcome = await ref
        .read(counterpartyManagementViewModelProvider.notifier)
        .rename(id: counterparty.id, name: name);
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _deleteCounterparty(
    BuildContext context,
    CounterpartyView counterparty,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对手方'),
        content: Text(
          counterparty.usageCount > 0
              ? '「${counterparty.name}」正在 ${counterparty.usageCount} 笔交易上使用，'
                    '删除后这些交易将不再携带该对手方。'
              : '「${counterparty.name}」没有被任何交易使用。',
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
    if (confirmed != true || !context.mounted) return;
    final outcome = await ref
        .read(counterpartyManagementViewModelProvider.notifier)
        .delete(counterparty.id);
    if (context.mounted) _showOutcome(context, outcome);
  }

  void _showOutcome(BuildContext context, CounterpartyCommandOutcome outcome) {
    final message = switch (outcome) {
      CounterpartyCommandOutcome.success => null,
      CounterpartyCommandOutcome.duplicateName => '已有同名对手方',
      CounterpartyCommandOutcome.unknown => '操作失败，请稍后重试',
    };
    if (message == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CounterpartyRow extends StatelessWidget {
  const _CounterpartyRow({
    required this.counterparty,
    required this.onRename,
    required this.onDelete,
  });

  final CounterpartyView counterparty;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space6,
        AppSpacing.space4,
        AppSpacing.space6,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.space32,
            height: AppSpacing.space32,
            decoration: BoxDecoration(
              color: colors.primary.withValues(
                alpha: AppComponentTokens.selectedContainerOpacity,
              ),
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            ),
            child: Icon(
              RemixIcons.user_shared_line,
              size: AppSpacing.space20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counterparty.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.listTitle,
                ),
                Text(
                  '${counterparty.usageCount} 笔交易',
                  style: context.appTextStyles.listSupporting,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              RemixIcons.more_2_line,
              size: AppSpacing.space20,
              color: colors.onSurfaceVariant,
            ),
            tooltip: '更多操作',
            onSelected: (action) {
              switch (action) {
                case 'rename':
                  onRename();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}
