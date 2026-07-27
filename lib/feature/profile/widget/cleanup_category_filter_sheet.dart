import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_submit_button.dart';

/// 数据清理的分类多选面板。返回选中的分类账户 ID；
/// 空集合表示不限分类；返回 null 表示取消。
Future<Set<String>?> showCleanupCategoryFilterSheet({
  required BuildContext context,
  required List<CategoryNode> expenseTree,
  required List<CategoryNode> incomeTree,
  required Set<String> selectedIds,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return _CleanupCategoryFilterSheet(
        expenseTree: expenseTree,
        incomeTree: incomeTree,
        initialSelectedIds: selectedIds,
      );
    },
  );
}

class _CleanupCategoryFilterSheet extends StatefulWidget {
  const _CleanupCategoryFilterSheet({
    required this.expenseTree,
    required this.incomeTree,
    required this.initialSelectedIds,
  });

  final List<CategoryNode> expenseTree;
  final List<CategoryNode> incomeTree;
  final Set<String> initialSelectedIds;

  @override
  State<_CleanupCategoryFilterSheet> createState() =>
      _CleanupCategoryFilterSheetState();
}

class _CleanupCategoryFilterSheetState
    extends State<_CleanupCategoryFilterSheet> {
  late final Set<String> _selectedIds = {...widget.initialSelectedIds};

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择分类',
                      style: context.appTextStyles.subsectionTitle,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _selectedIds.isEmpty
                            ? null
                            : () => setState(_selectedIds.clear),
                    child: const Text('清除'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _typeSection('支出分类', widget.expenseTree),
                  _typeSection('收入分类', widget.incomeTree),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: AppSubmitButton(
                label: '确定',
                onPressed:
                    () => Navigator.of(context).pop(Set.of(_selectedIds)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeSection(String title, List<CategoryNode> nodes) {
    if (nodes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space8,
            AppSpacing.space16,
            AppSpacing.space4,
          ),
          child: Text(title, style: context.appTextStyles.groupTitle),
        ),
        for (final node in nodes) ..._nodeRows(node),
      ],
    );
  }

  List<Widget> _nodeRows(CategoryNode node) {
    final subtreeIds = <String>{
      node.account.id,
      for (final child in node.children) child.id,
    };
    final selectedCount =
        subtreeIds.where(_selectedIds.contains).length;
    final bool? rootValue =
        selectedCount == 0
            ? false
            : selectedCount == subtreeIds.length
            ? true
            : null;
    return [
      CheckboxListTile(
        value: rootValue,
        tristate: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
        ),
        title: Text(
          node.account.name,
          style: context.appTextStyles.formPlainValue,
        ),
        onChanged: (_) => _toggleSubtree(subtreeIds, select: rootValue != true),
      ),
      for (final child in node.children)
        CheckboxListTile(
          value: _selectedIds.contains(child.id),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.only(
            left: AppSpacing.space40,
            right: AppSpacing.space16,
          ),
          title: Text(child.name, style: context.appTextStyles.formPlainValue),
          onChanged: (_) => _toggleOne(child.id),
        ),
    ];
  }

  void _toggleSubtree(Set<String> ids, {required bool select}) {
    setState(() {
      if (select) {
        _selectedIds.addAll(ids);
      } else {
        _selectedIds.removeAll(ids);
      }
    });
  }

  void _toggleOne(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) {
        _selectedIds.add(id);
      }
    });
  }
}
