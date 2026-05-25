import 'package:flutter/material.dart';

import '../../design_system/theme/app_text_styles.dart';
import '../../design_system/tokens/radius.dart';
import '../../design_system/tokens/spacing.dart';
import '../../design_system/widgets/app_surface.dart';
import '../../application/accounting/accounting_api.dart';
import 'business_icon.dart';
import 'business_icon_bubble.dart';

class CategoryGridPicker extends StatelessWidget {
  const CategoryGridPicker({
    required this.nodes,
    required this.selectedRootId,
    required this.selectedCategoryId,
    required this.emptyLabel,
    required this.onRootSelected,
    required this.onChildSelected,
    required this.onAddRoot,
    required this.onAddChild,
    super.key,
  });

  final List<CategoryNode> nodes;
  final int? selectedRootId;
  final int? selectedCategoryId;
  final String emptyLabel;
  final ValueChanged<Account> onRootSelected;
  final void Function(Account root, Account child) onChildSelected;
  final VoidCallback onAddRoot;
  final ValueChanged<int> onAddChild;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return AppSurface(
        border: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  emptyLabel,
                  style: context.appTextStyles.inputText.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAddRoot,
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <List<CategoryNode>>[];
    for (var index = 0; index < nodes.length; index += 5) {
      rows.add(nodes.skip(index).take(5).toList());
    }
    if (rows.last.length == 5) {
      rows.add(const []);
    }

    return Column(
      children: [
        for (final row in rows) ...[
          _CategoryRow(
            nodes: row,
            selectedRootId: selectedRootId,
            selectedCategoryId: selectedCategoryId,
            onRootSelected: onRootSelected,
            showAddRoot: row == rows.last,
            onAddRoot: onAddRoot,
          ),
          if (row.any((node) => node.account.id == selectedRootId))
            _SubcategoryPanel(
              node: row.firstWhere((node) => node.account.id == selectedRootId),
              selectedCategoryId: selectedCategoryId,
              onChildSelected: onChildSelected,
              onAddChild: onAddChild,
            ),
          const SizedBox(height: AppSpacing.space8),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.nodes,
    required this.selectedRootId,
    required this.selectedCategoryId,
    required this.onRootSelected,
    required this.showAddRoot,
    required this.onAddRoot,
  });

  final List<CategoryNode> nodes;
  final int? selectedRootId;
  final int? selectedCategoryId;
  final ValueChanged<Account> onRootSelected;
  final bool showAddRoot;
  final VoidCallback onAddRoot;

  @override
  Widget build(BuildContext context) {
    final filledSlots = nodes.length + (showAddRoot ? 1 : 0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in nodes)
          Expanded(
            child: _CategoryTile(
              category: node.account,
              selected:
                  node.account.id == selectedCategoryId ||
                  node.account.id == selectedRootId,
              onTap: () => onRootSelected(node.account),
            ),
          ),
        if (showAddRoot && nodes.length < 5)
          Expanded(child: _AddCategoryTile(onTap: onAddRoot)),
        for (var index = filledSlots; index < 5; index++) const Spacer(),
      ],
    );
  }
}

class _SubcategoryPanel extends StatelessWidget {
  const _SubcategoryPanel({
    required this.node,
    required this.selectedCategoryId,
    required this.onChildSelected,
    required this.onAddChild,
  });

  final CategoryNode node;
  final int? selectedCategoryId;
  final void Function(Account root, Account child) onChildSelected;
  final ValueChanged<int> onAddChild;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final slots = <Widget>[
      for (final child in node.children)
        _CategoryTile(
          category: child,
          selected: child.id == selectedCategoryId,
          onTap: () => onChildSelected(node.account, child),
        ),
      _AddCategoryTile(onTap: () => onAddChild(node.account.id)),
    ];
    final rows = <List<Widget>>[];
    for (var index = 0; index < slots.length; index += 5) {
      rows.add(slots.skip(index).take(5).toList());
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space8,
      ),
      child: Column(
        children: [
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in rows[rowIndex]) Expanded(child: child),
                for (var index = rows[rowIndex].length; index < 5; index++)
                  const Spacer(),
              ],
            ),
            if (rowIndex < rows.length - 1)
              const SizedBox(height: AppSpacing.space4),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Account category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: BusinessIconTile(
        extent: 64,
        borderRadius: AppRadius.radiusMd,
        onTap: onTap,
        child: BusinessIconBubble(
          selected: selected,
          label: category.name,
          labelSpacing: AppSpacing.space4,
          child: BusinessIcon(iconKey: category.iconKey, size: 28),
        ),
      ),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  const _AddCategoryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: BusinessIconTile(
        extent: 64,
        borderRadius: AppRadius.radiusMd,
        onTap: onTap,
        child: BusinessIconBubble(
          label: '新增',
          labelSpacing: AppSpacing.space4,
          child: Icon(Icons.add, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
