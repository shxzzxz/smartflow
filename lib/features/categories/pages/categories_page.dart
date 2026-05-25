import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/providers.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../application/accounting/accounting_api.dart';
import '../../../widgets/business/category_grid_picker.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(categoryTreeProvider(AccountType.income));
    final expenseAsync = ref.watch(categoryTreeProvider(AccountType.expense));
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
                  children: [
                    _CategoryGridPage(
                      asyncValue: expenseAsync,
                      type: AccountType.expense,
                      emptyLabel: '暂无支出分类',
                    ),
                    _CategoryGridPage(
                      asyncValue: incomeAsync,
                      type: AccountType.income,
                      emptyLabel: '暂无收入分类',
                    ),
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
            onPressed: () => context.push('/categories/new'),
            icon: Icon(RemixIcons.add_circle_line, color: colors.onSurface),
            tooltip: '新建分类',
          ),
        ],
      ),
    );
  }
}

class _CategoryGridPage extends StatefulWidget {
  const _CategoryGridPage({
    required this.asyncValue,
    required this.type,
    required this.emptyLabel,
  });

  final AsyncValue<List<CategoryNode>> asyncValue;
  final AccountType type;
  final String emptyLabel;

  @override
  State<_CategoryGridPage> createState() => _CategoryGridPageState();
}

class _CategoryGridPageState extends State<_CategoryGridPage> {
  int? _selectedRootId;
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return widget.asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _CategoryErrorView(error: error),
      data: (nodes) {
        if (nodes.isEmpty) {
          return _EmptyCategories(label: widget.emptyLabel, type: widget.type);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space28,
            AppSpacing.space24,
            AppSpacing.space28,
            AppSpacing.space32,
          ),
          children: [
            CategoryGridPicker(
              nodes: nodes,
              selectedRootId: _selectedRootId,
              selectedCategoryId: _selectedCategoryId,
              emptyLabel: widget.emptyLabel,
              onRootSelected:
                  (account) => setState(() {
                    _selectedRootId = account.id;
                    _selectedCategoryId = account.id;
                  }),
              onChildSelected:
                  (root, child) => setState(() {
                    _selectedRootId = root.id;
                    _selectedCategoryId = child.id;
                  }),
              onAddRoot: () => _openCategoryForm(context, widget.type),
              onAddChild:
                  (rootId) =>
                      _openCategoryForm(context, widget.type, parentId: rootId),
            ),
          ],
        );
      },
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

void _openCategoryForm(
  BuildContext context,
  AccountType type, {
  int? parentId,
}) {
  final uri = Uri(
    path: '/categories/new',
    queryParameters: {
      'type': type.name,
      if (parentId != null) 'parentId': parentId.toString(),
    },
  );
  context.push(uri.toString());
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.label, required this.type});

  final String label;
  final AccountType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                  path: '/categories/new',
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
