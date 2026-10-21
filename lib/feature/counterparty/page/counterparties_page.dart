import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/shared/name_dialog.dart';
import '../../../widget/business/shared/transaction_reference_target_sheet.dart';
import '../../../widget/business/tag/tag_search_field.dart';
import '../../shared/provider/counterparty_providers.dart';
import '../view_model/counterparty_management_view_model.dart';

final _logger = Logger('feature.counterparty.page');

class CounterpartiesPage extends ConsumerStatefulWidget {
  const CounterpartiesPage({super.key});

  @override
  ConsumerState<CounterpartiesPage> createState() => _CounterpartiesPageState();
}

class _CounterpartiesPageState extends ConsumerState<CounterpartiesPage> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
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
    final counterparties = ref.watch(counterpartyListProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: _batchMode ? '批量操作对手方' : '对手方管理',
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
                            onPressed: _selectedIds.isEmpty || _batchProcessing
                                ? null
                                : () => _retargetSelectedCounterparties(
                                    context,
                                    TransactionReferenceOperation.merge,
                                  ),
                          ),
                          AppPopupMenuAction(
                            label: '迁移到…',
                            icon: RemixIcons.arrow_left_right_line,
                            onPressed: _selectedIds.isEmpty || _batchProcessing
                                ? null
                                : () => _retargetSelectedCounterparties(
                                    context,
                                    TransactionReferenceOperation.migrate,
                                  ),
                          ),
                        ],
                      ),
                      AppHeaderIconButton(
                        onPressed: _selectedIds.isEmpty || _batchProcessing
                            ? null
                            : () => _deleteSelectedCounterparties(context),
                        icon: RemixIcons.delete_bin_line,
                        tooltip: '删除已选对手方',
                      ),
                    ]
                  : [
                      AppHeaderIconButton(
                        onPressed: _enterBatchMode,
                        icon: RemixIcons.list_check_3,
                        tooltip: '批量操作对手方',
                      ),
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
                Expanded(child: Text('已选 ${_selectedIds.length} 个对手方')),
                TextButton(
                  onPressed: filtered.isEmpty || _batchProcessing
                      ? null
                      : () => _toggleAll(filtered),
                  child: Text(_allSelected(filtered) ? '取消全选结果' : '全选结果'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _batchMode
              ? _buildBatchList(context, filtered)
              : filtered.isEmpty
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
                              onTap: () {
                                final uri = Uri(
                                  path:
                                      '/counterparties/${filtered[index].id}/transactions',
                                );
                                context.push(uri.toString());
                              },
                              onRename: () =>
                                  _renameCounterparty(context, filtered[index]),
                              onMerge: () => _retargetCounterparty(
                                context,
                                filtered[index],
                                counterparties,
                                TransactionReferenceOperation.merge,
                              ),
                              onMigrate: () => _retargetCounterparty(
                                context,
                                filtered[index],
                                counterparties,
                                TransactionReferenceOperation.migrate,
                              ),
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

  Widget _buildBatchList(
    BuildContext context,
    List<CounterpartyView> counterparties,
  ) {
    if (counterparties.isEmpty) {
      return const Center(child: Text('没有匹配的对手方'));
    }
    return ListView(
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
              for (var index = 0; index < counterparties.length; index++) ...[
                CheckboxListTile(
                  value: _selectedIds.contains(counterparties[index].id),
                  onChanged: _batchProcessing
                      ? null
                      : (_) => _toggle(counterparties[index].id),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                  ),
                  title: Text(
                    counterparties[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.formValue,
                  ),
                  subtitle: Text('${counterparties[index].usageCount} 笔交易'),
                ),
                if (index < counterparties.length - 1) const AppListDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _allSelected(List<CounterpartyView> counterparties) {
    return counterparties.isNotEmpty &&
        counterparties.every((item) => _selectedIds.contains(item.id));
  }

  void _enterBatchMode() {
    setState(() {
      _batchMode = true;
      _batchProcessing = false;
      _selectedIds.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _leaveBatchMode() {
    setState(() {
      _batchMode = false;
      _batchProcessing = false;
      _selectedIds.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _toggleAll(List<CounterpartyView> counterparties) {
    setState(() {
      if (_allSelected(counterparties)) {
        _selectedIds.removeAll(counterparties.map((item) => item.id));
      } else {
        _selectedIds.addAll(counterparties.map((item) => item.id));
      }
    });
  }

  Future<void> _deleteSelectedCounterparties(BuildContext context) async {
    if (_selectedIds.isEmpty || _batchProcessing) return;
    final counterparties = await _loadSelectedCounterparties(context);
    if (counterparties.isEmpty || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除对手方'),
        content: Text(
          '确定删除选中的 ${counterparties.length} 个对手方？'
          '删除后这些对手方在交易上的引用也会被解除。',
        ),
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
    final outcome = await ref
        .read(counterpartyManagementViewModelProvider.notifier)
        .deleteMany({for (final item in counterparties) item.id});
    if (!context.mounted) return;
    if (outcome == CounterpartyCommandOutcome.success) {
      _leaveBatchMode();
    } else {
      setState(() => _batchProcessing = false);
      _showOutcome(context, outcome);
    }
  }

  Future<void> _retargetSelectedCounterparties(
    BuildContext context,
    TransactionReferenceOperation operation,
  ) async {
    if (_selectedIds.isEmpty || _batchProcessing) return;
    final counterparties = await _loadSelectedCounterparties(context);
    if (counterparties.isEmpty || !context.mounted) return;
    final all = await _loadCounterparties(context);
    if (all == null || !context.mounted) return;
    final targets = [
      for (final item in all)
        if (!_selectedIds.contains(item.id))
          TransactionReferenceTarget(
            id: item.id,
            name: item.name,
            usageCount: item.usageCount,
          ),
    ];
    if (targets.isEmpty) {
      _showMessage(context, '没有其他对手方可${operation.label}');
      return;
    }
    final target = await showTransactionReferenceTargetSheet(
      context,
      sourceDescription: '选中的 ${counterparties.length} 个对手方',
      entityLabel: '对手方',
      operation: operation,
      candidates: targets,
    );
    if (target == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('批量${operation.label}对手方'),
        content: Text(
          operation == TransactionReferenceOperation.merge
              ? '将把选中的 ${counterparties.length} 个对手方所关联的交易'
                    '改指向「${target.name}」，并删除这些源对手方。'
              : '将把选中的 ${counterparties.length} 个对手方所关联的交易'
                    '改指向「${target.name}」，并保留这些源对手方。',
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
    final sourceIds = {for (final item in counterparties) item.id};
    final viewModel = ref.read(
      counterpartyManagementViewModelProvider.notifier,
    );
    final outcome = operation == TransactionReferenceOperation.merge
        ? await viewModel.merge(sourceIds: sourceIds, targetId: target.id)
        : await viewModel.migrate(sourceIds: sourceIds, targetId: target.id);
    if (!context.mounted) return;
    if (outcome == CounterpartyCommandOutcome.success) {
      _leaveBatchMode();
    } else {
      setState(() => _batchProcessing = false);
      _showOutcome(context, outcome);
    }
  }

  Future<List<CounterpartyView>> _loadSelectedCounterparties(
    BuildContext context,
  ) async {
    final all = await _loadCounterparties(context);
    if (all == null) return const [];
    return [
      for (final item in all)
        if (_selectedIds.contains(item.id)) item,
    ];
  }

  Future<List<CounterpartyView>?> _loadCounterparties(
    BuildContext context,
  ) async {
    try {
      return await ref
          .read(counterpartyApplicationServiceProvider)
          .listCounterparties();
    } catch (error, stackTrace) {
      _logger.severe('Counterparty list load failed.', error, stackTrace);
      if (context.mounted) _showMessage(context, '对手方加载失败，请稍后重试');
      return null;
    }
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

  Future<void> _retargetCounterparty(
    BuildContext context,
    CounterpartyView counterparty,
    List<CounterpartyView> all,
    TransactionReferenceOperation operation,
  ) async {
    final targets = [
      for (final item in all)
        if (item.id != counterparty.id)
          TransactionReferenceTarget(
            id: item.id,
            name: item.name,
            usageCount: item.usageCount,
          ),
    ];
    if (targets.isEmpty) {
      _showMessage(context, '没有其他对手方可${operation.label}');
      return;
    }
    final target = await showTransactionReferenceTargetSheet(
      context,
      sourceDescription: '「${counterparty.name}」',
      entityLabel: '对手方',
      operation: operation,
      candidates: targets,
    );
    if (target == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${operation.label}对手方'),
        content: Text(
          operation == TransactionReferenceOperation.merge
              ? '将把「${counterparty.name}」的 ${counterparty.usageCount} 笔交易'
                    '改指向「${target.name}」，并删除「${counterparty.name}」。'
              : '将把「${counterparty.name}」的 ${counterparty.usageCount} 笔交易'
                    '改指向「${target.name}」，并保留「${counterparty.name}」。',
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

    final viewModel = ref.read(
      counterpartyManagementViewModelProvider.notifier,
    );
    final outcome = operation == TransactionReferenceOperation.merge
        ? await viewModel.merge(
            sourceIds: {counterparty.id},
            targetId: target.id,
          )
        : await viewModel.migrate(
            sourceIds: {counterparty.id},
            targetId: target.id,
          );
    if (context.mounted) _showOutcome(context, outcome);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    required this.onTap,
    required this.onRename,
    required this.onMerge,
    required this.onMigrate,
    required this.onDelete,
  });

  final CounterpartyView counterparty;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onMerge;
  final VoidCallback onMigrate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
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
