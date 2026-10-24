import 'package:smartflow/application/ledger/ledger_query_api.dart';

String entryDirectionLabel(EntryDirection direction) {
  return switch (direction) {
    EntryDirection.debit => '借',
    EntryDirection.credit => '贷',
  };
}

String transactionPurposeLabel(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyExpense => '支出',
    BusinessPurpose.dailyIncome => '收入',
    BusinessPurpose.transfer => '转账',
    BusinessPurpose.refund => '退款',
    BusinessPurpose.advance => '垫付',
    BusinessPurpose.advanceCollection => '垫付到账',
    BusinessPurpose.advanceSettlement => '垫付结清',
    BusinessPurpose.debtRepayment => '还款',
    BusinessPurpose.borrowing => '借入',
    BusinessPurpose.lending => '借出',
    BusinessPurpose.receivableCollection => '收回',
    BusinessPurpose.badDebt => '坏账',
    BusinessPurpose.debtRelief => '债务豁免',
    BusinessPurpose.openingBalance => '期初余额',
    BusinessPurpose.balanceAdjustment => '余额调整',
  };
}

String transactionRoleLabel(TransactionRole role) {
  return switch (role) {
    TransactionRole.category => '分类',
    TransactionRole.settlementIn => '收款账户',
    TransactionRole.settlementOut => '付款账户',
    TransactionRole.receivable => '应收',
    TransactionRole.liability => '负债',
    TransactionRole.interest => '利息',
    TransactionRole.fee => '手续费',
    TransactionRole.discount => '优惠',
    TransactionRole.refundOffset => '退款冲销',
    TransactionRole.advanceExpenseCategory => '垫付分类总额',
    TransactionRole.advanceSelfBorne => '自承担支出',
    TransactionRole.advanceCompensationIncome => '垫付补偿',
    TransactionRole.advanceBadDebtExpense => '垫付坏账',
    TransactionRole.openingBalance => '期初余额',
    TransactionRole.balanceAdjustment => '余额调整',
  };
}
