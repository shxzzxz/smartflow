import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';
import 'package:smartflow/features/home/view_models/home_transaction_group.dart';
import 'package:smartflow/features/home/view_models/transaction_row_presentation.dart';

void main() {
  group('transaction row presentation', () {
    test('uses reimbursement expense category but keeps amount neutral', () {
      final item = _item(
        BusinessPurpose.reimbursementAdvance,
        categoryName: '电费',
        categoryIconKey: 'flashlight-line',
        flowOutAccountName: '信用卡',
        flowInAccountName: '公司报销',
      );

      expect(transactionPrimaryLabel(item), '电费');
      expect(resolveCategoryIconKey(item), 'flashlight-line');
      expect(transactionAccountLabel(item), '信用卡');
      expect(formatTransactionAmount(item), '12.34');
      expect(
        amountColor(
          const ColorScheme.light(),
          AppThemeExtension.light(),
          item.businessPurpose,
        ),
        const ColorScheme.light().onSurface,
      );
      expect(isIncomePurpose(item.businessPurpose), isFalse);
      expect(isExpensePurpose(item.businessPurpose), isFalse);
    });

    test('maps non-cashflow main transaction icons and signs', () {
      final borrowing = _item(BusinessPurpose.borrowing);
      final openingBalance = _item(BusinessPurpose.openingBalance);
      final balanceAdjustment = _item(BusinessPurpose.balanceAdjustment);

      expect(resolveCategoryIconKey(borrowing), 'hand-coin-line');
      expect(resolveCategoryIconKey(openingBalance), 'wallet-line');
      expect(resolveCategoryIconKey(balanceAdjustment), 'wallet-line');
      expect(formatTransactionAmount(borrowing), '12.34');
      expect(isIncomePurpose(borrowing.businessPurpose), isFalse);
    });

    test('keeps daily income and expense as signed day totals', () {
      final expense = _item(BusinessPurpose.dailyExpense);
      final income = _item(BusinessPurpose.dailyIncome);

      expect(formatTransactionAmount(expense), '-12.34');
      expect(formatTransactionAmount(income), '+12.34');
      expect(isExpensePurpose(expense.businessPurpose), isTrue);
      expect(isIncomePurpose(income.businessPurpose), isTrue);
    });

    test('subtracts refunded total from daily expense summary', () {
      final group =
          groupTransactionsByDay(
            [
              _item(
                BusinessPurpose.dailyExpense,
                amountMinor: 5800,
                refundedTotal: const Money(minorUnits: 1000),
              ),
            ],
            [
              DailyCashflowSummary(
                date: DateTime(2026, 5, 12),
                income: Money.zero(),
                expense: const Money(minorUnits: 4800),
              ),
            ],
          ).single;

      expect(group.expenseMinor, 4800);
      expect(group.incomeMinor, 0);
    });
  });
}

TransactionListItem _item(
  BusinessPurpose purpose, {
  String? categoryName,
  String? categoryIconKey,
  String? flowOutAccountName,
  String? flowInAccountName,
  int amountMinor = 1234,
  Money? refundedTotal,
}) {
  return TransactionListItem(
    id: purpose.index,
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 5, 12, 8, 30),
    primaryAmount: Money(minorUnits: amountMinor),
    accountNames: '信用卡 / 公司报销',
    categoryName: categoryName,
    categoryIconKey: categoryIconKey,
    flowOutAccountName: flowOutAccountName,
    flowInAccountName: flowInAccountName,
    refundedTotal: refundedTotal,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
