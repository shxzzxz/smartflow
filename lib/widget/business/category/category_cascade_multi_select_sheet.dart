import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/widget/app_cascade_multi_select.dart';

Future<Set<String>?> showCategoryCascadeMultiSelectSheet({
  required BuildContext context,
  required List<CategoryNode> expenseTree,
  required List<CategoryNode> incomeTree,
  required Set<String> selectedIds,
}) {
  return showAppCascadeMultiSelectSheet<String>(
    context: context,
    title: '选择分类',
    sections: [
      AppCascadeSelectionSection(
        nodes: [
          AppCascadeSelectionNode.group(
            label: '支出分类',
            children: [for (final node in expenseTree) _categoryNode(node)],
          ),
          AppCascadeSelectionNode.group(
            label: '收入分类',
            children: [for (final node in incomeTree) _categoryNode(node)],
          ),
        ],
      ),
    ],
    selectedValues: selectedIds,
  );
}

AppCascadeSelectionNode<String> _categoryNode(CategoryNode node) {
  return AppCascadeSelectionNode(
    value: node.account.id,
    label: node.account.name,
    children: [
      for (final child in node.children)
        AppCascadeSelectionNode(value: child.id, label: child.name),
    ],
  );
}
