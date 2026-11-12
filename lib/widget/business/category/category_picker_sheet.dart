import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../icon/business_icon.dart';

class CategoryPickerSection {
  const CategoryPickerSection({
    required this.type,
    required this.label,
    required this.nodes,
  });

  final AccountType type;
  final String label;
  final List<CategoryPickerNode> nodes;
}

class CategoryPickerNode {
  const CategoryPickerNode({
    required this.id,
    required this.label,
    this.iconKey,
    this.children = const [],
  });

  final String id;
  final String label;
  final String? iconKey;
  final List<CategoryPickerNode> children;
}

Future<String?> showCategoryPickerSheet({
  required BuildContext context,
  required List<CategoryPickerSection> sections,
  required String? selectedId,
  Set<String>? selectableIds,
}) {
  final availableIds = selectableIds ?? _allCategoryIds(sections);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final maxHeight =
          MediaQuery.sizeOf(context).height *
          AppComponentTokens.selectionSheetMaxHeightFactor;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          child: CategoryPickerSheet(
            sections: sections,
            selectableIds: availableIds,
            selectedId: selectedId,
            onCategoryTap: (categoryId) =>
                Navigator.of(context).pop(categoryId),
          ),
        ),
      );
    },
  );
}

class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({
    required this.sections,
    required this.selectableIds,
    required this.selectedId,
    required this.onCategoryTap,
    super.key,
  });

  final List<CategoryPickerSection> sections;
  final Set<String> selectableIds;
  final String? selectedId;
  final ValueChanged<String> onCategoryTap;

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  String? _activeRootId;

  @override
  void initState() {
    super.initState();
    _activeRootId = _initialRootId();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSections = _visibleSections();
    if (visibleSections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space24),
          child: Text('暂无可选分类', style: context.appTextStyles.inputText),
        ),
      );
    }
    final activeRoot = _activeRoot(visibleSections);
    return LayoutBuilder(
      builder: (context, constraints) {
        final navigationWidth = (constraints.maxWidth * 0.36)
            .clamp(112.0, 160.0)
            .toDouble();
        return Row(
          key: const ValueKey('category-picker-layout'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: navigationWidth,
              child: _CategoryRootNavigation(
                sections: visibleSections,
                activeRootId: activeRoot.node.id,
                onSelected: (rootId) => setState(() => _activeRootId = rootId),
              ),
            ),
            const VerticalDivider(width: AppComponentTokens.outlineWidth),
            Expanded(
              child: _CategoryOptionList(
                root: activeRoot,
                sectionType: activeRoot.sectionType,
                selectedId: widget.selectedId,
                selectableIds: widget.selectableIds,
                onSelected: widget.onCategoryTap,
              ),
            ),
          ],
        );
      },
    );
  }

  List<_VisibleCategorySection> _visibleSections() {
    final result = <_VisibleCategorySection>[];
    for (final section in widget.sections) {
      final roots = _visibleRoots(section);
      if (roots.isNotEmpty) {
        result.add(_VisibleCategorySection(label: section.label, roots: roots));
      }
    }
    return result;
  }

  List<_VisibleCategoryRoot> _visibleRoots(CategoryPickerSection section) {
    return [
      for (final node in section.nodes)
        if (_isSelectable(node.id) ||
            node.children.any((child) => _isSelectable(child.id)))
          _VisibleCategoryRoot(
            node: node,
            sectionType: section.type,
            children: [
              for (final child in node.children)
                if (_isSelectable(child.id)) child,
            ],
          ),
    ];
  }

  bool _isSelectable(String id) => widget.selectableIds.contains(id);

  String? _initialRootId() {
    final sections = _visibleSections();
    for (final section in sections) {
      for (final root in section.roots) {
        if (root.node.id == widget.selectedId ||
            root.children.any((child) => child.id == widget.selectedId)) {
          return root.node.id;
        }
      }
    }
    return sections.isEmpty ? null : sections.first.roots.first.node.id;
  }

  _VisibleCategoryRoot _activeRoot(List<_VisibleCategorySection> sections) {
    for (final section in sections) {
      for (final root in section.roots) {
        if (root.node.id == _activeRootId) return root;
      }
    }
    return sections.first.roots.first;
  }
}

class _VisibleCategorySection {
  const _VisibleCategorySection({required this.label, required this.roots});

  final String label;
  final List<_VisibleCategoryRoot> roots;
}

class _VisibleCategoryRoot {
  const _VisibleCategoryRoot({
    required this.node,
    required this.sectionType,
    required this.children,
  });

  final CategoryPickerNode node;
  final AccountType sectionType;
  final List<CategoryPickerNode> children;
}

class _CategoryRootNavigation extends StatelessWidget {
  const _CategoryRootNavigation({
    required this.sections,
    required this.activeRootId,
    required this.onSelected,
  });

  final List<_VisibleCategorySection> sections;
  final String activeRootId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: ListView(
        key: const ValueKey('category-picker-root-navigation'),
        padding: const EdgeInsets.all(AppSpacing.space4),
        children: [
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space8,
                AppSpacing.space8,
                AppSpacing.space8,
                AppSpacing.space4,
              ),
              child: Text(
                section.label,
                style: context.appTextStyles.listSupporting,
              ),
            ),
            for (final root in section.roots)
              _CategoryRootItem(
                root: root.node,
                selected: root.node.id == activeRootId,
                onTap: () => onSelected(root.node.id),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRootItem extends StatelessWidget {
  const _CategoryRootItem({
    required this.root,
    required this.selected,
    required this.onTap,
  });

  final CategoryPickerNode root;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? colors.primary.withValues(
                alpha: AppComponentTokens.selectedContainerOpacity,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('category-picker-root-${root.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppComponentTokens.controlMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space8,
                vertical: AppSpacing.space8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      root.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.sideNavigationLabel(
                        selected: selected,
                      ),
                    ),
                  ),
                  Icon(
                    RemixIcons.arrow_right_s_line,
                    size: AppSpacing.space16,
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryOptionList extends StatelessWidget {
  const _CategoryOptionList({
    required this.root,
    required this.sectionType,
    required this.selectedId,
    required this.selectableIds,
    required this.onSelected,
  });

  final _VisibleCategoryRoot root;
  final AccountType sectionType;
  final String? selectedId;
  final Set<String> selectableIds;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final rootSelectable = selectableIds.contains(root.node.id);
    return ListView(
      key: ValueKey('category-picker-options-${root.node.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
      children: [
        if (rootSelectable)
          _CategoryPickerRow(
            category: root.node,
            sectionType: sectionType,
            selected: root.node.id == selectedId,
            subtitle: '本级分类',
            onTap: () => onSelected(root.node.id),
          ),
        if (root.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space12,
              AppSpacing.space16,
              AppSpacing.space4,
            ),
            child: Text('子分类', style: context.appTextStyles.listSupporting),
          ),
        for (final child in root.children)
          _CategoryPickerRow(
            category: child,
            sectionType: sectionType,
            selected: child.id == selectedId,
            onTap: () => onSelected(child.id),
          ),
      ],
    );
  }
}

class _CategoryPickerRow extends StatelessWidget {
  const _CategoryPickerRow({
    required this.category,
    required this.sectionType,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final CategoryPickerNode category;
  final AccountType sectionType;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('category-picker-option-${category.id}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppComponentTokens.controlMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space8,
          ),
          child: Row(
            children: [
              BusinessIcon(
                iconRef: category.iconKey,
                size: AppSpacing.space20,
                usage: sectionType == AccountType.income
                    ? BusinessIconUsage.incomeCategory
                    : BusinessIconUsage.expenseCategory,
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.formValue,
                    ),
                    if (subtitle case final subtitle?)
                      Text(
                        subtitle,
                        style: context.appTextStyles.listSupporting,
                      ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

Set<String> _allCategoryIds(List<CategoryPickerSection> sections) {
  return {
    for (final section in sections)
      for (final root in section.nodes) ...[
        root.id,
        for (final child in root.children) child.id,
      ],
  };
}
