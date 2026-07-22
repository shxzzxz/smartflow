import 'package:intl/intl.dart';

import '../../../application/import/import_api.dart';

String importEntityKindLabel(ImportSourceEntity entity) {
  if (entity.kind == ImportEntityKind.account) return '来源账户';
  return entity.categoryKind == ImportCategoryKind.income ? '来源收入分类' : '来源支出分类';
}

List<ImportSourceEntity> importGroupEntities(
  ImportTransactionGroupDraft group,
  List<ImportSourceEntity> sourceEntities,
) {
  final keys =
      group.transactions.expand((draft) => draft.sourceEntityKeys).toSet();
  return sourceEntities
      .where((entity) => keys.contains(entity.sourceEntityKey))
      .toList(growable: false);
}

String importOperationLabel(ImportOperationKind kind) {
  return switch (kind) {
    ImportOperationKind.expense => '普通支出',
    ImportOperationKind.income => '普通收入',
    ImportOperationKind.transfer => '转账',
    ImportOperationKind.refund => '退款',
    ImportOperationKind.reimbursementAdvance => '报销垫付',
    ImportOperationKind.reimbursementReceipt => '报销到账',
    ImportOperationKind.reimbursementClose => '结束报销',
    ImportOperationKind.repayment => '还款',
    ImportOperationKind.interestExpense => '利息支出',
    ImportOperationKind.borrowing => '借入',
    ImportOperationKind.openingBalance => '债务期初余额',
  };
}

String importFileRoleLabel(YimuFileRole role) {
  return switch (role) {
    YimuFileRole.bill => '账单文件',
    YimuFileRole.transfer => '转账文件',
    YimuFileRole.debt => '债务文件',
  };
}

String formatImportDateTime(DateTime value) => _dateTimeFormat.format(value);

final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
