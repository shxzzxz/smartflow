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

String transactionDetailTypeLabel(TransactionDetailType type) {
  return switch (type) {
    TransactionDetailType.primaryExpense => '支出主体',
    TransactionDetailType.primaryIncome => '收入主体',
    TransactionDetailType.transferMain => '转账主体',
    TransactionDetailType.transferFee => '转账手续费',
    TransactionDetailType.refundMain => '退款主体',
    TransactionDetailType.reimbursementAdvanceMain => '报销垫付',
    TransactionDetailType.reimbursementReceiptMain => '报销到账',
    TransactionDetailType.reimbursementCloseMain => '结束报销',
    TransactionDetailType.reimbursementGapExpense => '报销少收差额',
    TransactionDetailType.reimbursementGapIncome => '报销多收差额',
    TransactionDetailType.repaymentPrincipal => '还款本金',
    TransactionDetailType.repaymentInterest => '还款利息',
    TransactionDetailType.repaymentFee => '还款手续费',
    TransactionDetailType.repaymentDiscount => '优惠',
    TransactionDetailType.borrowingPrincipal => '借入本金',
    TransactionDetailType.lendingPrincipal => '借出本金',
    TransactionDetailType.receivableCollectionPrincipal => '收回本金',
    TransactionDetailType.receivableCollectionInterest => '利息',
    TransactionDetailType.badDebtMain => '坏账本金',
    TransactionDetailType.debtReliefMain => '豁免本金',
    TransactionDetailType.openingBalanceMain => '期初余额',
    TransactionDetailType.balanceAdjustmentMain => '余额调整',
  };
}
