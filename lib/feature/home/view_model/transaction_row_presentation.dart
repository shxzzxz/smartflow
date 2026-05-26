import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../application/ledger/ledger_api.dart';
import '../../../widget/business/account_lookup.dart';
import '../../../widget/business/finance_labels.dart';

/// 主交易行展示用的纯计算函数。
///
/// 把列表项 → 文案 / 图标 / 颜色 / 金额格式 的映射集中在此,
/// widget 层只做组装与渲染,便于单元测试与跨视图复用。
///
/// `accountsById` 由 widget 端从 `accountsByIdProvider` 提供,
/// 用于把 entries 的 accountId 解析为 Account 元数据。

/// 类目账户(expense / income / 报销垫付的 expense 账户)。
Account? categoryAccount(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.refund => firstEntryByType(
      item.entries,
      accountsById: accountsById,
      accountType: AccountType.expense,
    )?.resolveAccount(accountsById),
    BusinessPurpose.dailyIncome => firstEntryByType(
      item.entries,
      accountsById: accountsById,
      accountType: AccountType.income,
    )?.resolveAccount(accountsById),
    BusinessPurpose.reimbursementAdvance =>
      item.reimbursementExpenseAccountId == null
          ? null
          : accountsById[item.reimbursementExpenseAccountId!],
    _ => null,
  };
}

/// 资金「流出账户」:asset / liability 上的 credit 分录(付款方)。
Account? flowOutAccount(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  return firstSettlementEntry(
    item.entries,
    accountsById: accountsById,
    direction: EntryDirection.credit,
  )?.resolveAccount(accountsById);
}

/// 资金「流入账户」:asset / liability 上的 debit 分录(收款方)。
Account? flowInAccount(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  return firstSettlementEntry(
    item.entries,
    accountsById: accountsById,
    direction: EntryDirection.debit,
  )?.resolveAccount(accountsById);
}

String? resolveCategoryIconKey(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose
        .reimbursementAdvance => categoryAccount(item, accountsById)?.iconKey,
    BusinessPurpose.transfer => 'transfer',
    BusinessPurpose.debtRepayment => 'loan',
    BusinessPurpose.borrowing => 'hand-coin-line',
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment => 'wallet-line',
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose => null,
  };
}

String transactionPrimaryLabel(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.dailyIncome =>
      _cleanText(categoryAccount(item, accountsById)?.name) ??
          transactionPurposeLabel(item.businessPurpose),
    BusinessPurpose.reimbursementAdvance =>
      _cleanText(categoryAccount(item, accountsById)?.name) ?? '支出',
    _ => transactionPurposeLabel(item.businessPurpose),
  };
}

String transactionAccountLabel(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.reimbursementAdvance =>
      _cleanText(flowOutAccount(item, accountsById)?.name) ?? '',
    BusinessPurpose.dailyIncome =>
      _cleanText(flowInAccount(item, accountsById)?.name) ?? '',
    _ => _flowAccountLabel(item, accountsById),
  };
}

String _flowAccountLabel(
  TransactionListItem item,
  Map<int, Account> accountsById,
) {
  final out = _cleanText(flowOutAccount(item, accountsById)?.name);
  final in_ = _cleanText(flowInAccount(item, accountsById)?.name);
  if (out != null && in_ != null) {
    return '$out → $in_';
  }
  return out ?? in_ ?? '';
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

Color amountColor(
  ColorScheme colors,
  AppThemeExtension financeColors,
  BusinessPurpose purpose,
) {
  return switch (purpose) {
    BusinessPurpose.dailyIncome => financeColors.income,
    BusinessPurpose.dailyExpense => financeColors.expense,
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt => financeColors.income,
    BusinessPurpose.transfer ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.debtRepayment ||
    BusinessPurpose.borrowing ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment ||
    BusinessPurpose.reimbursementClose => colors.onSurface,
  };
}

String formatTransactionAmount(TransactionListItem item) {
  final prefix = switch (item.businessPurpose) {
    BusinessPurpose.dailyIncome => '+',
    BusinessPurpose.dailyExpense => '-',
    _ => '',
  };
  return '$prefix${formatMinorAmount(item.primaryAmount.minorUnits)}';
}

bool canQuickEditTransaction(TransactionListItem item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.transfer ||
    BusinessPurpose.borrowing => true,
    BusinessPurpose.debtRepayment ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose => false,
  };
}

String formatMinorAmount(int minorUnits) {
  return Money(minorUnits: minorUnits.abs()).format();
}

String formatMonthlyAmount(int minorUnits, {required bool showSign}) {
  final formatted = Money(minorUnits: minorUnits.abs()).format();
  if (!showSign) return formatted;
  return minorUnits >= 0 ? formatted : '-$formatted';
}

String formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String weekdayLabel(DateTime value) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[value.weekday - 1];
}
