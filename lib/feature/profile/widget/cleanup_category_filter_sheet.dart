import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../widget/business/category/category_cascade_multi_select_sheet.dart';

/// 数据清理的分类多选面板。返回选中的分类账户 ID；
/// 空集合表示不限分类；返回 null 表示取消。
Future<Set<String>?> showCleanupCategoryFilterSheet({
  required BuildContext context,
  required List<CategoryNode> expenseTree,
  required List<CategoryNode> incomeTree,
  required Set<String> selectedIds,
}) {
  return showCategoryCascadeMultiSelectSheet(
    context: context,
    expenseTree: expenseTree,
    incomeTree: incomeTree,
    selectedIds: selectedIds,
  );
}
