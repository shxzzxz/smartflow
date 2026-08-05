import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/finance/cashflow_summary_card.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../widget/business/icon/business_icon.dart';
import '../../../widget/business/icon/business_icon_bubble.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/budget_view_model.dart';
import '../widget/budget_trend_chart.dart';

class BudgetPage extends ConsumerWidget {
  const BudgetPage({this.initialMonth, super.key});

  final DateTime? initialMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetPageProvider(initialMonth));
    final viewModelProvider = budgetViewModelProvider(initialMonth);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space8,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space4,
              ),
              child: const AppPageHeader(
                title: '预算',
                subtitle: '月度支出目标',
                showBackButton: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space4,
                AppSpacing.space16,
                AppSpacing.space12,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppMonthSelector(
                  visibleMonth: state.visibleMonth,
                  onPreviousMonth:
                      () => ref
                          .read(budgetViewModelProvider(initialMonth).notifier)
                          .shiftMonth(-1),
                  onMonthPressed:
                      () => _pickMonth(context, ref, state.visibleMonth),
                  onNextMonth:
                      () => ref
                          .read(budgetViewModelProvider(initialMonth).notifier)
                          .shiftMonth(1),
                ),
              ),
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

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime visibleMonth,
  ) async {
    final selected = await showAppMonthPicker(
      context: context,
      initialMonth: visibleMonth,
    );
    if (selected == null || !context.mounted) return;
    ref
        .read(budgetViewModelProvider(initialMonth).notifier)
        .pickMonth(selected);
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
          BudgetDetailPageLoaded(:final month, :final progress) =>
            _BudgetDetailContent(
              month: month,
              progress: progress,
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

class _BudgetContent extends ConsumerWidget {
  const _BudgetContent({
    required this.report,
    required this.categories,
    required this.viewModelProvider,
  });

  final MonthlyBudgetReport report;
  final List<CategoryNode> categories;
  final BudgetViewModelProvider viewModelProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space4,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        _SectionHeader(
          title: '总预算',
          actions: [
            IconButton(
              tooltip: report.totalBudget == null ? '设置总预算' : '编辑总预算',
              icon: Icon(
                report.totalBudget == null
                    ? RemixIcons.add_line
                    : RemixIcons.edit_line,
              ),
              onPressed:
                  () => _editBudget(
                    context,
                    ref,
                    provider: viewModelProvider,
                    existing: report.totalBudget,
                  ),
            ),
          ],
        ),
        if (report.totalBudget case final total?) ...[
          _BudgetSummary(progress: total),
          const SizedBox(height: AppSpacing.space16),
          _TrendSection(month: report.month, progress: total),
        ] else
          const _EmptyTotalBudget(),
        const SizedBox(height: AppSpacing.space20),
        _SectionHeader(
          title: '分类预算',
          actions: [
            if (report.categoryGroups.length > 1)
              IconButton(
                tooltip: '调整分类预算顺序',
                icon: const Icon(RemixIcons.sort_desc),
                onPressed:
                    () => _reorderGroups(
                      context,
                      ref,
                      provider: viewModelProvider,
                    ),
              ),
            IconButton(
              tooltip: '新增分类预算',
              icon: const Icon(RemixIcons.add_line),
              onPressed:
                  categories.isEmpty
                      ? null
                      : () => _addCategoryBudget(
                        context,
                        ref,
                        provider: viewModelProvider,
                      ),
            ),
          ],
        ),
        if (report.categoryGroups.isEmpty)
          const _BudgetMessage(
            icon: RemixIcons.price_tag_3_line,
            message: '还没有分类预算',
          )
        else
          for (
            var index = 0;
            index < report.categoryGroups.length;
            index++
          ) ...[
            _CategoryBudgetGroupCard(
              group: report.categoryGroups[index],
              month: report.month,
            ),
            if (index != report.categoryGroups.length - 1)
              const SizedBox(height: AppSpacing.space12),
          ],
      ],
    );
  }

  Future<void> _addCategoryBudget(
    BuildContext context,
    WidgetRef ref, {
    required BudgetViewModelProvider provider,
  }) async {
    final budgetedIds = {
      for (final group in report.categoryGroups)
        for (final budget in group.budgets) budget.categoryId,
    };
    final available = <(Account, String)>[
      for (final node in categories) ...[
        if (!budgetedIds.contains(node.account.id))
          (node.account, node.account.name),
        for (final child in node.children)
          if (!budgetedIds.contains(child.id))
            (child, '${node.account.name} / ${child.name}'),
      ],
    ];
    if (available.isEmpty) {
      _showMessage(context, '所有支出分类都已设置预算');
      return;
    }
    final selected = await showModalBottomSheet<(Account, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => SafeArea(
            child: FractionallySizedBox(
              heightFactor: .72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space20,
                      0,
                      AppSpacing.space20,
                      AppSpacing.space8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '选择支出分类',
                        style: sheetContext.appTextStyles.sectionTitleStrong,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in available)
                          ListTile(
                            leading: BusinessIconBubble(
                              size: AppSpacing.space40,
                              child: BusinessIcon(
                                iconKey: item.$1.iconKey,
                                size: AppSpacing.space24,
                              ),
                            ),
                            title: Text(item.$2),
                            onTap: () => Navigator.of(sheetContext).pop(item),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (selected == null || !context.mounted) return;
    await _editBudget(
      context,
      ref,
      provider: provider,
      categoryId: selected.$1.id,
      title: selected.$2,
    );
  }

  Future<void> _reorderGroups(
    BuildContext context,
    WidgetRef ref, {
    required BudgetViewModelProvider provider,
  }) async {
    final reordered = await showModalBottomSheet<List<BudgetCategoryGroup>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BudgetGroupReorderSheet(groups: report.categoryGroups),
    );
    if (reordered == null || !context.mounted) return;
    final ids = [
      for (final group in reordered)
        for (final budget in group.budgets) budget.id,
    ];
    final outcome = await ref
        .read(provider.notifier)
        .reorderCategoryBudgets(ids);
    if (!context.mounted) return;
    _showOutcome(context, outcome, '分类预算顺序已更新');
  }
}

class _BudgetDetailContent extends ConsumerWidget {
  const _BudgetDetailContent({
    required this.month,
    required this.progress,
    required this.viewModelProvider,
  });

  final MonthKey month;
  final BudgetProgress progress;
  final BudgetViewModelProvider viewModelProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space8,
            AppSpacing.space8,
            AppSpacing.space16,
            AppSpacing.space12,
          ),
          child: AppPageHeader(
            title: progress.name,
            subtitle: '${month.year}年${month.month}月分类预算',
            showBackButton: true,
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
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space4,
              AppSpacing.space16,
              AppSpacing.space24,
            ),
            children: [
              _BudgetSummary(progress: progress),
              const SizedBox(height: AppSpacing.space16),
              _TrendSection(month: month, progress: progress),
            ],
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
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预算趋势', style: context.appTextStyles.sectionTitleStrong),
            const SizedBox(height: AppSpacing.space16),
            BudgetTrendChart(month: month, progress: progress),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetGroupCard extends StatelessWidget {
  const _CategoryBudgetGroupCard({required this.group, required this.month});

  final BudgetCategoryGroup group;
  final MonthKey month;

  @override
  Widget build(BuildContext context) {
    final root = group.rootBudget;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
        child: Column(
          children: [
            _BudgetRow(
              name: group.name,
              iconKey: group.iconKey,
              progress: root,
              emphasized: true,
              onTap: root == null ? null : () => _openDetail(context, root.id),
            ),
            for (final child in group.childBudgets) ...[
              Divider(
                height: 1,
                indent: AppSpacing.space48,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.space24),
                child: _BudgetRow(
                  name: child.name,
                  iconKey: child.iconKey,
                  progress: child,
                  onTap: () => _openDetail(context, child.id),
                ),
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

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.name,
    required this.iconKey,
    this.progress,
    this.onTap,
    this.emphasized = false,
  });

  final String name;
  final String? iconKey;
  final BudgetProgress? progress;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
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
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Text(
                name,
                style:
                    emphasized
                        ? context.appTextStyles.groupTitle
                        : context.appTextStyles.listTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (progress case final value?) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(
                    money: value.budget,
                    semantic: MoneySemantic.neutral,
                    style: context.appTextStyles.amountList,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    value.isOverspent
                        ? '超支 ${value.remaining.abs().format()}'
                        : '剩余 ${value.remaining.format()}',
                    style: context.appTextStyles.listSupporting.copyWith(
                      color:
                          value.isOverspent
                              ? colors.error
                              : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.space4),
              Icon(
                RemixIcons.arrow_right_s_line,
                size: AppSpacing.space20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.space48,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: context.appTextStyles.sectionTitleStrong),
          ),
          ...actions,
        ],
      ),
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

class _BudgetGroupReorderSheet extends StatefulWidget {
  const _BudgetGroupReorderSheet({required this.groups});

  final List<BudgetCategoryGroup> groups;

  @override
  State<_BudgetGroupReorderSheet> createState() =>
      _BudgetGroupReorderSheetState();
}

class _BudgetGroupReorderSheetState extends State<_BudgetGroupReorderSheet> {
  late final List<BudgetCategoryGroup> _groups = [...widget.groups];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .66,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '调整分类预算顺序',
                      style: context.appTextStyles.sectionTitleStrong,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_groups),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _groups.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final moved = _groups.removeAt(oldIndex);
                    _groups.insert(newIndex, moved);
                  });
                },
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  return ListTile(
                    key: ValueKey(group.id),
                    leading: ReorderableDelayedDragStartListener(
                      index: index,
                      child: const Icon(RemixIcons.draggable),
                    ),
                    title: Text(group.name),
                    subtitle: Text('${group.budgets.length} 项预算'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
