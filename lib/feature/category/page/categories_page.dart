import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../application/ledger/ledger_query_api.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/business_icon_bubble.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../widget/category_manage_sheets.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              const _CategoryHeader(),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: const [
                    _CategoryManageTab(type: AccountType.expense),
                    _CategoryManageTab(type: AccountType.income),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space10,
        AppSpacing.space12,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(RemixIcons.arrow_left_s_line),
            iconSize: 30,
            tooltip: '返回',
          ),
          Expanded(
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelStyle: textStyles.largeTabLabel(selected: true),
              unselectedLabelStyle: textStyles.largeTabLabel(selected: false),
              tabs: const [Tab(text: '支出'), Tab(text: '收入')],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/category/new'),
            icon: Icon(RemixIcons.add_circle_line, color: colors.onSurface),
            tooltip: '新建分类',
          ),
        ],
      ),
    );
  }
}

class _CategoryManageTab extends ConsumerStatefulWidget {
  const _CategoryManageTab({required this.type});

  final AccountType type;

  @override
  ConsumerState<_CategoryManageTab> createState() => _CategoryManageTabState();
}

class _CategoryManageTabState extends ConsumerState<_CategoryManageTab> {
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(categoryTreeProvider(widget.type));
    final archived =
        ref.watch(archivedCategoriesProvider(widget.type)).value ??
        const <Account>[];
    final accountsById =
        ref.watch(accountsByIdProvider).value ?? const <String, Account>{};

    return treeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _CategoryErrorView(error: error),
      data: (nodes) {
        if (nodes.isEmpty && archived.isEmpty) {
          return _EmptyCategories(type: widget.type);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space24,
            AppSpacing.space20,
            AppSpacing.space48,
          ),
          children: [
            if (nodes.isNotEmpty)
              AppSurface(
                child: Column(
                  children: [
                    for (var i = 0; i < nodes.length; i++) ...[
                      _RootCategoryRow(
                        node: nodes[i],
                        expanded: _expandedIds.contains(nodes[i].account.id),
                        onToggleExpanded:
                            () => setState(() {
                              final id = nodes[i].account.id;
                              _expandedIds.contains(id)
                                  ? _expandedIds.remove(id)
                                  : _expandedIds.add(id);
                            }),
                        onMore: () => _openActionSheet(nodes[i].account, nodes),
                      ),
                      if (_expandedIds.contains(nodes[i].account.id)) ...[
                        for (final child in nodes[i].children)
                          _ChildCategoryRow(
                            category: child,
                            onTap:
                                () => context.push('/category/${child.id}/edit'),
                            onMore: () => _openActionSheet(child, nodes),
                          ),
                        _AddChildRow(
                          onTap: () => _openChildForm(nodes[i].account.id),
                        ),
                      ],
                      if (i < nodes.length - 1)
                        const Padding(
                          padding: EdgeInsets.only(
                            left: AppSpacing.space48 + AppSpacing.space14,
                            right: AppSpacing.space16,
                          ),
                          child: Divider(height: 1),
                        ),
                    ],
                  ],
                ),
              ),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space24),
              _ArchivedSection(archived: archived, accountsById: accountsById),
            ],
          ],
        );
      },
    );
  }

  void _openActionSheet(Account category, List<CategoryNode> nodes) {
    final hasActiveChildren =
        category.parentId == null &&
        nodes
            .firstWhere(
              (node) => node.account.id == category.id,
              orElse: () => CategoryNode(account: category, children: const []),
            )
            .children
            .isNotEmpty;
    showCategoryActionSheet(
      context,
      ref,
      category: category,
      hasActiveChildren: hasActiveChildren,
      tree: nodes,
    );
  }

  void _openChildForm(String parentId) {
    final uri = Uri(
      path: '/category/new',
      queryParameters: {'type': widget.type.name, 'parentId': parentId},
    );
    context.push(uri.toString());
  }
}

class _RootCategoryRow extends StatelessWidget {
  const _RootCategoryRow({
    required this.node,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onMore,
  });

  final CategoryNode node;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final childCount = node.children.length;

    return InkWell(
      onTap: onToggleExpanded,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space10,
        ),
        child: Row(
          children: [
            BusinessIconBubble(
              size: AppSpacing.space32,
              child: BusinessIcon(iconKey: node.account.iconKey, size: 24),
            ),
            const SizedBox(width: AppSpacing.space14),
            Expanded(
              child: Text(
                node.account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyles.formValue,
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            if (childCount > 0)
              Text(
                '$childCount 个子分类',
                style: textStyles.listSupporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: AppSpacing.space6),
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                RemixIcons.arrow_down_s_line,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
            _MoreButton(onPressed: onMore),
          ],
        ),
      ),
    );
  }
}

class _ChildCategoryRow extends StatelessWidget {
  const _ChildCategoryRow({
    required this.category,
    required this.onTap,
    required this.onMore,
  });

  final Account category;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space48,
          AppSpacing.space6,
          AppSpacing.space16,
          AppSpacing.space6,
        ),
        child: Row(
          children: [
            BusinessIconBubble(
              size: AppSpacing.space28,
              child: BusinessIcon(iconKey: category.iconKey, size: 20),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyles.inputText,
              ),
            ),
            _MoreButton(onPressed: onMore),
          ],
        ),
      ),
    );
  }
}

class _AddChildRow extends StatelessWidget {
  const _AddChildRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space48,
          AppSpacing.space8,
          AppSpacing.space16,
          AppSpacing.space10,
        ),
        child: Row(
          children: [
            Icon(RemixIcons.add_line, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.space12),
            Text(
              '新增子分类',
              style: textStyles.inputText.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        RemixIcons.more_2_line,
        size: 20,
        color: colors.onSurfaceVariant,
      ),
      visualDensity: VisualDensity.compact,
      tooltip: '更多操作',
    );
  }
}

/// 归档区只读展示；parentId 指向归并目标（统计并入该分类）。
class _ArchivedSection extends StatelessWidget {
  const _ArchivedSection({required this.archived, required this.accountsById});

  final List<Account> archived;
  final Map<String, Account> accountsById;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
          child: Row(
            children: [
              Icon(
                RemixIcons.archive_line,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.space6),
              Text(
                '已归档',
                style: textStyles.groupTitle.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < archived.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space16,
                    vertical: AppSpacing.space10,
                  ),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: 0.55,
                        child: BusinessIconBubble(
                          size: AppSpacing.space28,
                          child: BusinessIcon(
                            iconKey: archived[i].iconKey,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space12),
                      Expanded(
                        child: Text(
                          archived[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyles.inputText.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '并入 ${accountsById[archived[i].parentId]?.name ?? '—'}',
                        style: textStyles.listSupporting.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < archived.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(
                      left: AppSpacing.space48 + AppSpacing.space8,
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
}

class _CategoryErrorView extends StatelessWidget {
  const _CategoryErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Text('分类加载失败：$error'),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.type});

  final AccountType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = type == AccountType.income ? '暂无收入分类' : '暂无支出分类';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(RemixIcons.apps_2_line, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.space12),
            Text(label, style: context.appTextStyles.inputText),
            const SizedBox(height: AppSpacing.space12),
            FilledButton.icon(
              onPressed: () {
                final uri = Uri(
                  path: '/category/new',
                  queryParameters: {'type': type.name},
                );
                context.push(uri.toString());
              },
              icon: const Icon(RemixIcons.add_line),
              label: const Text('新建分类'),
            ),
          ],
        ),
      ),
    );
  }
}
