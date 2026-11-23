import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/intake/intake_rules_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_tab_swipe_region.dart';
import '../view_model/recognition_rules_view_model.dart';
import '../../../design_system/widget/app_scaffold.dart';

class RecognitionRulesPage extends ConsumerStatefulWidget {
  const RecognitionRulesPage({super.key});

  @override
  ConsumerState<RecognitionRulesPage> createState() =>
      _RecognitionRulesPageState();
}

class _RecognitionRulesPageState extends ConsumerState<RecognitionRulesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(recognitionRulesViewModelProvider);
    final state = asyncState.asData?.value;
    final vm = ref.read(recognitionRulesViewModelProvider.notifier);
    final rules = state?.filteredRules ?? const <RecognitionRule>[];
    final targetLabel = state?.kind == RecognitionRuleKind.category
        ? '分类'
        : '账户';
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader.custom(
              titleContent: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AppSlidingSegmentedControl<RecognitionRuleKind>(
                  variant: AppSegmentedControlVariant.header,
                  segments: const [
                    AppSegment(
                      value: RecognitionRuleKind.account,
                      label: '账户规则',
                    ),
                    AppSegment(
                      value: RecognitionRuleKind.category,
                      label: '分类规则',
                    ),
                  ],
                  selected: state?.kind ?? RecognitionRuleKind.account,
                  onChanged: state == null || state.saving
                      ? null
                      : vm.selectKind,
                ),
              ),
              actions: [
                AppHeaderIconButton(
                  tooltip: '新增识别规则',
                  icon: RemixIcons.add_line,
                  onPressed: state == null || state.saving
                      ? null
                      : () => _edit(context, vm, kind: state.kind),
                ),
              ],
            ),
            Expanded(
              child: switch (asyncState) {
                AsyncData(:final value) =>
                  AppTabSwipeRegion<RecognitionRuleKind>(
                    values: RecognitionRuleKind.values,
                    selected: value.kind,
                    onChanged: value.saving ? null : vm.selectKind,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.space16,
                            AppSpacing.space8,
                            AppSpacing.space16,
                            AppSpacing.space12,
                          ),
                          child: SearchBar(
                            controller: _searchController,
                            hintText: '搜索$targetLabel或关键词',
                            leading: const Icon(RemixIcons.search_line),
                            textInputAction: TextInputAction.search,
                            onChanged: vm.setSearchQuery,
                            trailing: [
                              if (value.searchQuery.isNotEmpty)
                                IconButton(
                                  tooltip: '清除搜索',
                                  icon: const Icon(RemixIcons.close_line),
                                  onPressed: () {
                                    _searchController.clear();
                                    vm.setSearchQuery('');
                                  },
                                ),
                            ],
                          ),
                        ),
                        if (value.saving) const LinearProgressIndicator(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: vm.refresh,
                            child: ReorderableListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(AppSpacing.space16),
                              buildDefaultDragHandles: false,
                              header: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (value.error case final error?) ...[
                                    AppStatusBanner(
                                      message: error.message,
                                      tone: AppStatusBannerTone.warning,
                                    ),
                                    const SizedBox(height: AppSpacing.space12),
                                  ],
                                  if (rules.isEmpty)
                                    AppEmptyState(
                                      title: value.isSearching
                                          ? '没有找到相关规则'
                                          : '暂无识别规则',
                                      message: value.isSearching
                                          ? '试试其他$targetLabel名称或关键词。'
                                          : '点击右上角添加关键词和目标。',
                                    ),
                                ],
                              ),
                              itemCount: rules.length,
                              onReorderItem: (oldIndex, newIndex) {
                                if (value.canReorder) {
                                  vm.reorder(rules[oldIndex].id, newIndex);
                                }
                              },
                              itemBuilder: (context, index) {
                                final rule = rules[index];
                                return ReorderableDelayedDragStartListener(
                                  key: ValueKey(rule.id),
                                  index: index,
                                  enabled: value.canReorder,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.space12,
                                    ),
                                    child: _RuleRow(
                                      rule: rule,
                                      targets: value.data.targets,
                                      enabled: !value.saving,
                                      onMoveToTop:
                                          value.rules.first.id == rule.id
                                          ? null
                                          : () => vm.moveToTop(rule.id),
                                      onToggle: () =>
                                          vm.setEnabled(rule.id, !rule.enabled),
                                      onEdit: () =>
                                          _edit(context, vm, rule: rule),
                                      onDelete: () =>
                                          _delete(context, vm, rule),
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
                AsyncError() => Center(
                  child: AppEmptyState(
                    title: '无法读取识别规则',
                    action: FilledButton(
                      onPressed: () =>
                          ref.invalidate(recognitionRulesViewModelProvider),
                      child: const Text('重试'),
                    ),
                  ),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    RecognitionRulesViewModel vm, {
    RecognitionRule? rule,
    RecognitionRuleKind? kind,
  }) async {
    final path = rule == null
        ? '/profile/recognition-rules/new?kind=${kind!.name}'
        : '/profile/recognition-rules/rule/${rule.id}';
    final saved = await context.push<bool>(path);
    if (context.mounted && saved == true) await vm.refresh();
  }

  Future<void> _delete(
    BuildContext context,
    RecognitionRulesViewModel vm,
    RecognitionRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除识别规则'),
        content: Text('删除“${rule.displayName}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (context.mounted && confirmed == true) await vm.delete(rule.id);
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.targets,
    required this.enabled,
    required this.onMoveToTop,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RecognitionRule rule;
  final List<RecognitionRuleTarget> targets;
  final bool enabled;
  final VoidCallback? onMoveToTop;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final target = targets
        .where((target) => target.id == rule.targetAccountId)
        .firstOrNull;
    final targetText =
        target?.displayName ??
        (rule.targetPath.isEmpty
            ? '目标不可用'
            : '${rule.targetPath.join(' / ')}（不可用）');
    final scope = switch (rule.source) {
      RecognitionRuleSource.wechat => '微信',
      RecognitionRuleSource.alipay => '支付宝',
      null => '全部来源',
    };
    final supporting = [
      targetText,
      scope,
      if (!rule.enabled) '已禁用',
    ].join(' · ');
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.keywords.join('、'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rule.enabled && target != null
                        ? context.appTextStyles.listTitle
                        : context.appTextStyles.listTitle.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                  ),
                  Text(
                    supporting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.listSupporting,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            AppPopupMenuButton(
              tooltip: '更多${rule.displayName}',
              icon: RemixIcons.more_2_line,
              items: [
                AppPopupMenuAction(
                  label: '置顶',
                  onPressed: enabled ? onMoveToTop : null,
                ),
                AppPopupMenuAction(
                  label: rule.enabled ? '禁用' : '启用',
                  onPressed: enabled ? onToggle : null,
                ),
                AppPopupMenuAction(
                  label: '编辑',
                  onPressed: enabled ? onEdit : null,
                ),
                AppPopupMenuAction(
                  label: '删除',
                  onPressed: enabled ? onDelete : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
