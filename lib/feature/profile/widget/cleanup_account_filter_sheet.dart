import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../widget/business/account/account_multi_select_sheet.dart';

/// 数据清理的账户多选面板。返回选中的账户 ID；
/// 空集合表示不限账户；返回 null 表示取消。
Future<Set<String>?> showCleanupAccountFilterSheet({
  required BuildContext context,
  required List<Account> accounts,
  required Set<String> selectedIds,
}) {
  return showAccountMultiSelectSheet(
    context: context,
    accounts: accounts,
    selectedIds: selectedIds,
  );
}
