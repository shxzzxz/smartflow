import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../domain/accounting/accounting_api.dart';
import '../../../widgets/business/finance_labels.dart';

/// 主交易行展示用的纯计算函数。
///
/// 把列表项 → 文案 / 图标 / 颜色 / 金额格式 的映射集中在此，
/// widgets 层只做组装与渲染，便于单元测试与跨视图复用。

String? resolveCategoryIconKey(TransactionListItem item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.reimbursementAdvance => item.categoryIconKey,
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

String transactionPrimaryLabel(TransactionListItem item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.dailyIncome =>
      _cleanText(item.categoryName) ??
          transactionPurposeLabel(item.businessPurpose),
    BusinessPurpose.reimbursementAdvance =>
      _cleanText(item.categoryName) ?? '支出',
    _ => transactionPurposeLabel(item.businessPurpose),
  };
}

String transactionAccountLabel(TransactionListItem item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.reimbursementAdvance =>
      _cleanText(item.flowOutAccountName) ?? _firstAccountName(item),
    BusinessPurpose.dailyIncome =>
      _cleanText(item.flowInAccountName) ?? _firstAccountName(item),
    _ => _flowAccountLabel(item),
  };
}

String _flowAccountLabel(TransactionListItem item) {
  final flowOut = _cleanText(item.flowOutAccountName);
  final flowIn = _cleanText(item.flowInAccountName);
  if (flowOut != null && flowIn != null) {
    return '$flowOut → $flowIn';
  }
  return flowOut ?? flowIn ?? _firstAccountName(item);
}

String _firstAccountName(TransactionListItem item) {
  final parts =
      item.accountNames
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) {
    return '';
  }
  return parts.first;
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
