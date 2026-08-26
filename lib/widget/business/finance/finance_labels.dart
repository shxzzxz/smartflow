import 'package:smartflow/application/ledger/ledger_query_api.dart';

String accountTypeLabel(AccountType type) {
  return switch (type) {
    AccountType.asset => '资产',
    AccountType.liability => '负债',
    AccountType.equity => '权益',
    AccountType.income => '收入',
    AccountType.expense => '支出',
  };
}

String accountSubtypeLabel(AccountSubtype subtype) {
  return switch (subtype) {
    AccountSubtype.fund => '资金账户',
    AccountSubtype.receivable => '应收账户',
    AccountSubtype.payable => '应付账户',
    AccountSubtype.loan => '贷款账户',
  };
}

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
    BusinessPurpose.reimbursementAdvance => '报销垫付',
    BusinessPurpose.reimbursementReceipt => '报销到账',
    BusinessPurpose.reimbursementClose => '结束报销',
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
    TransactionRole.reimbursementExpenseCategory => '报销支出分类',
    TransactionRole.reimbursementGapExpense => '报销少收差额',
    TransactionRole.reimbursementGapIncome => '报销多收差额',
    TransactionRole.openingBalance => '期初余额',
    TransactionRole.balanceAdjustment => '余额调整',
  };
}
