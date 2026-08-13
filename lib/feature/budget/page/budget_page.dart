import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../feature/shared/presentation/account_lookup.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/finance/cashflow_summary_card.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../widget/business/icon/business_icon.dart';
import '../../../widget/business/icon/business_icon_bubble.dart';
import '../../../widget/business/transaction/transaction_feed.dart';
import '../../../widget/business/analytics/analysis_section_card.dart';
import '../../../widget/business/analytics/category_progress_list_item.dart';
import '../../../widget/business/category/tree_select.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../presentation/budget_transaction_presentation.dart';
import '../view_model/budget_view_model.dart';
import '../widget/budget_trend_chart.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({this.initialMonth, super.key});

  final DateTime? initialMonth;

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  DateTime? get initialMonth => widget.initialMonth;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      await _copyPreviousMonthBudgetsOnOpen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetPageProvider(initialMonth));
    final viewModelProvider = budgetViewModelProvider(initialMonth);
    final loaded =
        state.content is BudgetContentLoaded
            ? state.content as BudgetContentLoaded
            : null;
    final hasBudgets =
        loaded != null &&
        (loaded.report.totalBudget != null ||
            loaded.report.categoryGroups.isNotEmpty);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title:
                  '${state.visibleMonth.year}年${state.visibleMonth.month}月预算',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新增预算',
                  onPressed:
                      () => _addCategoryBudget(
                        context,
                        ref,
                        report: loaded?.report,
                        categories: loaded?.categories ?? const [],
                        provider: viewModelProvider,
                      ),
                ),
                AppPopupMenuButton(
                  tooltip: '更多',
                  icon: RemixIcons.more_2_fill,
                  items: [
                    AppPopupMenuAction(
                      label: '设置总预算',
                      icon: RemixIcons.edit_line,
                      onPressed:
                          loaded == null
                              ? null
                              : () => _editBudget(
                                context,
                                ref,
                                provider: viewModelProvider,
                                existing: loaded.report.totalBudget,
                                title: '设置总预算',
                              ),
                    ),
                    AppPopupMenuAction(
                      label: '清空本月预算',
                      icon: RemixIcons.delete_bin_line,
                      onPressed:
                          hasBudgets
                              ? () => _clearMonthBudgets(
                                context,
                                ref,
                                provider: viewModelProvider,
                              )
                              : null,
                    ),
                    AppPopupMenuToggle(
                      label: '复制上月预算',
                      value: state.copyEnabled,
                      onChanged:
                          (value) => _setCopyEnabled(context, ref, value),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: switch (state.content) {
                BudgetContentLoaded(:final report, :final categories) =>
                  _BudgetContent(
                    report: report,
                    categories: categories,
                    viewModelProvider: viewModelProvider,
                  ),
                BudgetContentError(:final message) => _BudgetMessage(
                  icon: RemixIcons.error_warning_line,
                  message: message,
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPreviousMonthBudgetsOnOpen() async {
    final outcome =
        await ref
            .read(budgetViewModelProvider(initialMonth).notifier)
            .copyPreviousMonthBudgetsOnOpen();
    if (!mounted || outcome is UiActionSuccess) return;
    if (outcome case UiActionFailure(:final error)) {
      _showMessage(context, error.message);
    }
  }

  Future<void> _clearMonthBudgets(
    BuildContext context,
    WidgetRef ref, {
    required BudgetViewModelProvider provider,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('清空本月预算？'),
            content: const Text('将删除本月总预算和全部分类预算，不会影响交易和分类。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('清空'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    final outcome = await ref.read(provider.notifier).clearMonthBudgets();
    if (!context.mounted) return;
    _showOutcome(context, outcome, '本月预算已清空');
  }

  Future<void> _setCopyEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final outcome = await ref
        .read(appSettingsViewModelProvider.notifier)
        .setCopyPreviousMonthBudgetsOnOpen(enabled);
    if (!context.mounted) return;
    _showOutcome(context, outcome, enabled ? '已开启复制上月预算' : '已关闭复制上月预算');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addCategoryBudget(
    BuildContext context,
    WidgetRef ref, {
    required MonthlyBudgetReport? report,
    required List<CategoryNode> categories,
    required BudgetViewModelProvider provider,
  }) async {
    if (report == null) return;
    final Set<String> budgetedIds = {
      for (final group in report.categoryGroups)
        for (final budget in group.budgets)
          if (budget.categoryId != null) budget.categoryId!,
    };
    final available =
        [
              for (final node in categories)
                CategoryNode(
                  account: node.account,
                  children: [
                    for (final child in node.children)
                      if (!budgetedIds.contains(child.id)) child,
                  ],
                ),
            ]
            .where(
              (node) =>
                  !budgetedIds.contains(node.account.id) ||
                  node.children.isNotEmpty,
            )
            .toList();
    if (available.isEmpty) {
      _showMessage(context, '所有支出分类都已设置预算');
      return;
    }
    final selected = await showModalBottomSheet<Account>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TreeSelect(nodes: available, disabledIds: budgetedIds),
    );
    if (selected == null || !context.mounted) return;
    await _editBudget(
      context,
      ref,
      provider: provider,
      categoryId: selected.id,
      title: selected.name,
    );
  }
}

class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({
    required this.budgetId,
    required this.month,
    super.key,
  });

  final String budgetId;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetDetailPageProvider(budgetId, month));
    return Scaffold(
      body: SafeArea(
        child: switch (state) {
          BudgetDetailPageLoaded(
            :final month,
            :final progress,
            :final transactions,
            :final accountLookup,
          ) =>
            _BudgetDetailContent(
              month: month,
              progress: progress,
              transactions: transactions,
              accountLookup: accountLookup,
              viewModelProvider: budgetViewModelProvider(this.month),
            ),
          BudgetDetailPageNotFound() => const _BudgetMessage(
            icon: RemixIcons.inbox_line,
            message: '分类预算不存在',
          ),
          BudgetDetailPageError(:final message) => _BudgetMessage(
            icon: RemixIcons.error_warning_line,
            message: message,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _BudgetContent extends ConsumerStatefulWidget {
  const _BudgetContent({
    required this.report,
    required this.categories,
    required this.viewModelProvider,
  });

  final MonthlyBudgetReport report;
  final List<CategoryNode> categories;
  final BudgetViewModelProvider viewModelProvider;

  @override
  ConsumerState<_BudgetContent> createState() => _BudgetContentState();
}

class _BudgetContentState extends ConsumerState<_BudgetContent> {
  final _collapsedGroupIds = <String>{};

  @override
  void didUpdateWidget(covariant _BudgetContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.report, widget.report)) {
      _collapsedGroupIds.removeWhere(
        (id) => !widget.report.categoryGroups.any((group) => group.id == id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final control = ref.watch(widget.viewModelProvider);
    final groups =
        control.categoryGroups.isEmpty && report.categoryGroups.isNotEmpty
            ? report.categoryGroups
            : control.categoryGroups;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space4,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      buildDefaultDragHandles: false,
      header: Column(
        children: [
          if (report.totalBudget case final total?) ...[
            _BudgetSummary(progress: total),
            const SizedBox(height: AppSpacing.space16),
            _TrendSection(month: report.month, progress: total),
          ] else
            const _EmptyTotalBudget(),
          const SizedBox(height: AppSpacing.space12),
          if (groups.isEmpty)
            const _BudgetMessage(
              icon: RemixIcons.price_tag_3_line,
              message: '还没有设置预算',
            ),
        ],
      ),
      footer: const SizedBox(height: AppSpacing.space4),
      itemCount: groups.length,
      onReorder: _reorderGroups,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Padding(
          key: ValueKey(group.id),
          padding: EdgeInsets.only(
            bottom: index == groups.length - 1 ? 0 : AppSpacing.space12,
          ),
          child: _CategoryBudgetGroupCard(
            group: group,
            month: report.month,
            groupIndex: index,
            expanded: !_collapsedGroupIds.contains(group.id),
            reorderEnabled: !control.savingOrder,
            onToggleExpanded: () => _toggleGroup(group.id),
            onReorderChild:
                (oldIndex, newIndex) =>
                    _reorderChildren(index, oldIndex, newIndex),
          ),
        );
      },
    );
  }

  void _toggleGroup(String groupId) {
    setState(() {
      if (!_collapsedGroupIds.add(groupId)) {
        _collapsedGroupIds.remove(groupId);
      }
    });
  }

  Future<void> _reorderGroups(int oldIndex, int newIndex) async {
    final outcome = await ref
        .read(widget.viewModelProvider.notifier)
        .reorderBudgetGroups(oldIndex, newIndex);
    if (!mounted || outcome is UiActionSuccess) return;
    _showOutcome(context, outcome, '分类预算顺序更新失败');
  }

  Future<void> _reorderChildren(
    int groupIndex,
    int oldIndex,
    int newIndex,
  ) async {
    final outcome = await ref
        .read(widget.viewModelProvider.notifier)
        .reorderBudgetsWithinGroup(groupIndex, oldIndex, newIndex);
    if (!mounted || outcome is UiActionSuccess) return;
    _showOutcome(context, outcome, '分类预算顺序更新失败');
  }
}

class _BudgetDetailContent extends ConsumerWidget {
  const _BudgetDetailContent({
    required this.month,
    required this.progress,
    required this.transactions,
    required this.accountLookup,
    required this.viewModelProvider,
  });

  final MonthKey month;
  final BudgetProgress progress;
  final List<TransactionListReadModel> transactions;
  final AccountLookup accountLookup;
  final BudgetViewModelProvider viewModelProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionGroups = budgetTransactionGroups(
      transactions: transactions,
      accountLookup: accountLookup,
      categoryId: progress.categoryId!,
    );
    return Column(
      children: [
        AppPageHeader(
          title: progress.name,
          actions: [
            AppHeaderIconButton(
              icon: RemixIcons.edit_line,
              tooltip: '编辑分类预算',
              onPressed:
                  () => _editBudget(
                    context,
                    ref,
                    provider: viewModelProvider,
                    existing: progress,
                  ),
            ),
          ],
        ),
        Expanded(
          child: TransactionFeedScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space8,
              AppSpacing.space16,
              AppSpacing.space24,
            ),
            leading: [
              _BudgetSummary(progress: progress),
              const SizedBox(height: AppSpacing.space16),
              _TrendSection(month: month, progress: progress),
              const SizedBox(height: AppSpacing.space20),
              Text('分类交易', style: context.appTextStyles.sectionTitleStrong),
              const SizedBox(height: AppSpacing.space12),
            ],
            groups: transactionGroups,
            emptyMessage: '本月暂无计入预算的分类交易',
            emptyState: null,
            showDailyTotals: false,
          ),
        ),
      ],
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    return CashflowSummaryCard(
      showCaptions: false,
      summary: CashflowSummaryPresentation(
        metrics: [
          CashflowSummaryMetricPresentation(
            label: '预算',
            amount: progress.budget,
            caption: '',
            tone: FinanceTone.primary,
          ),
          CashflowSummaryMetricPresentation(
            label: '已用',
            amount: progress.spent,
            caption: '',
            tone: FinanceTone.expense,
          ),
          CashflowSummaryMetricPresentation(
            label: progress.isOverspent ? '超支' : '剩余',
            amount: progress.remaining.abs(),
            caption: '',
            tone:
                progress.isOverspent
                    ? FinanceTone.expense
                    : FinanceTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.month, required this.progress});

  final MonthKey month;
  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    return AnalysisSectionCard(
      title: '预算趋势',
      child: BudgetTrendChart(month: month, progress: progress),
    );
  }
}

class _CategoryBudgetGroupCard extends StatelessWidget {
  const _CategoryBudgetGroupCard({
    required this.group,
    required this.month,
    required this.groupIndex,
    required this.expanded,
    required this.reorderEnabled,
    required this.onToggleExpanded,
    required this.onReorderChild,
  });

  final BudgetCategoryGroup group;
  final MonthKey month;
  final int groupIndex;
  final bool expanded;
  final bool reorderEnabled;
  final VoidCallback onToggleExpanded;
  final ReorderCallback onReorderChild;

  @override
  Widget build(BuildContext context) {
    final root = group.rootBudget;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
        child: Column(
          children: [
            _BudgetGroupHeader(
              name: group.name,
              iconKey: group.iconKey,
              expanded: expanded,
              onToggle: onToggleExpanded,
              groupIndex: groupIndex,
              reorderEnabled: reorderEnabled,
            ),
            if (expanded) ...[
              if (root case final root?)
                _BudgetRow(
                  name: root.name,
                  iconKey: root.iconKey,
                  progress: root,
                  onTap: () => _openDetail(context, root.id),
                ),
              ReorderableListView.builder(
                shrinkWrap: true,
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: group.childBudgets.length,
                onReorder: onReorderChild,
                itemBuilder: (context, index) {
                  final child = group.childBudgets[index];
                  return Column(
                    key: ValueKey(child.id),
                    children: [
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      ReorderableDelayedDragStartListener(
                        index: index,
                        enabled: reorderEnabled,
                        child: _BudgetRow(
                          name: child.name,
                          iconKey: child.iconKey,
                          progress: child,
                          onTap: () => _openDetail(context, child.id),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String id) {
    context.push(
      Uri(
        path: '/budget/$id',
        queryParameters: {'month': month.toString()},
      ).toString(),
    );
  }
}

class _BudgetGroupHeader extends StatelessWidget {
  const _BudgetGroupHeader({
    required this.name,
    required this.iconKey,
    required this.expanded,
    required this.onToggle,
    required this.groupIndex,
    required this.reorderEnabled,
  });

  final String name;
  final String? iconKey;
  final bool expanded;
  final VoidCallback onToggle;
  final int groupIndex;
  final bool reorderEnabled;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: groupIndex,
      enabled: reorderEnabled,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.space48 + AppSpacing.space16,
          ),
          child: Row(
            children: [
              BusinessIconBubble(
                size: AppSpacing.space40,
                child: BusinessIcon(iconKey: iconKey, size: AppSpacing.space24),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  name,
                  style: context.appTextStyles.groupTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: expanded ? '收起分组' : '展开分组',
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.name,
    required this.iconKey,
    required this.progress,
    this.onTap,
  });

  final String name;
  final String? iconKey;
  final BudgetProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CategoryProgressListItem(
      title: name,
      progress: progress.usedRatio,
      color: colors.primary,
      leading: _BudgetRowLeading(iconKey: iconKey),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(
            money: progress.budget,
            semantic: MoneySemantic.neutral,
            style: context.appTextStyles.amountList,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            progress.isOverspent
                ? '超支 ${progress.remaining.abs().format()}'
                : '余${progress.remaining.format()}',
            style: context.appTextStyles.listSupporting.copyWith(
              color:
                  progress.isOverspent ? colors.error : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }
}

class _BudgetRowLeading extends StatelessWidget {
  const _BudgetRowLeading({required this.iconKey});

  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BusinessIconBubble(
          size: AppSpacing.space40,
          child: BusinessIcon(iconKey: iconKey, size: AppSpacing.space24),
        ),
      ],
    );
  }
}

class _EmptyTotalBudget extends StatelessWidget {
  const _EmptyTotalBudget();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Row(
          children: [
            Icon(
              RemixIcons.funds_line,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.space12),
            const Expanded(child: Text('还没有设置本月总预算')),
          ],
        ),
      ),
    );
  }
}

class _BudgetMessage extends StatelessWidget {
  const _BudgetMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.space8),
            Text(message, style: context.appTextStyles.listSupporting),
          ],
        ),
      ),
    );
  }
}

class _BudgetAmountSheet extends StatefulWidget {
  const _BudgetAmountSheet({required this.title, this.existing});

  final String title;
  final BudgetProgress? existing;

  @override
  State<_BudgetAmountSheet> createState() => _BudgetAmountSheetState();
}

class _BudgetAmountSheetState extends State<_BudgetAmountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.budget.format() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space20,
          0,
          AppSpacing.space20,
          AppSpacing.space16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: context.appTextStyles.sectionTitleStrong,
              ),
              const SizedBox(height: AppSpacing.space12),
              MoneyPlainFormRow(
                label: '预算金额',
                controller: _controller,
                hintText: '0.00',
                requiredIndicator: true,
                validator: validatePositiveMoneyText,
              ),
              const SizedBox(height: AppSpacing.space16),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.existing == null ? '设置预算' : '保存'),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: AppSpacing.space8),
                TextButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(const _BudgetEditorResult.delete()),
                  child: const Text('删除预算'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_controller.text);
    if (amount == null) return;
    Navigator.of(context).pop(_BudgetEditorResult.save(amount));
  }
}

class _BudgetEditorResult {
  const _BudgetEditorResult.save(this.amount) : delete = false;
  const _BudgetEditorResult.delete() : amount = null, delete = true;

  final Money? amount;
  final bool delete;
}

Future<void> _editBudget(
  BuildContext context,
  WidgetRef ref, {
  required BudgetViewModelProvider provider,
  BudgetProgress? existing,
  String? categoryId,
  String? title,
}) async {
  final result = await showModalBottomSheet<_BudgetEditorResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => _BudgetAmountSheet(
          title: title ?? existing?.name ?? '设置总预算',
          existing: existing,
        ),
  );
  if (result == null || !context.mounted) return;
  if (result.delete) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('删除预算？'),
            content: const Text('仅删除预算设置，不会影响交易和分类。'),
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
        .read(provider.notifier)
        .deleteBudget(existing!.id);
    if (!context.mounted) return;
    _showOutcome(context, outcome, '预算已删除');
    if (outcome is UiActionSuccess &&
        existing.categoryId != null &&
        context.canPop()) {
      context.pop();
    }
    return;
  }
  final outcome = await ref
      .read(provider.notifier)
      .setBudget(
        amount: result.amount!,
        categoryId: existing?.categoryId ?? categoryId,
      );
  if (!context.mounted) return;
  _showOutcome(context, outcome, existing == null ? '预算已设置' : '预算已更新');
}

void _showOutcome(
  BuildContext context,
  UiActionOutcome<void> outcome,
  String successMessage,
) {
  final message = switch (outcome) {
    UiActionSuccess() => successMessage,
    UiActionFailure(:final error) => error.message,
  };
  _showMessage(context, message);
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
