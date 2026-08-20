enum AccountType { asset, liability, equity, income, expense }

enum AccountSubtype { fund, receivable, payable, loan }

enum EntryDirection { debit, credit }

enum BusinessPurpose {
  dailyExpense,
  dailyIncome,
  transfer,
  refund,
  reimbursementAdvance,
  reimbursementReceipt,
  reimbursementClose,
  debtRepayment,
  borrowing,
  lending,
  receivableCollection,
  badDebt,
  debtRelief,
  openingBalance,
  balanceAdjustment,
}

enum TransactionDetailType {
  primaryExpense,
  primaryIncome,
  transferMain,
  transferFee,
  refundMain,
  reimbursementAdvanceMain,
  reimbursementReceiptMain,
  reimbursementCloseMain,
  reimbursementGapExpense,
  reimbursementGapIncome,
  repaymentPrincipal,
  repaymentInterest,
  repaymentFee,
  repaymentDiscount,
  borrowingPrincipal,
  lendingPrincipal,
  receivableCollectionPrincipal,
  receivableCollectionInterest,
  badDebtMain,
  debtReliefMain,
  openingBalanceMain,
  balanceAdjustmentMain,
}

enum SourceKind { manual, import, auto }

enum SystemKey {
  openingBalance,
  reimbursementGapIncome,
  interestExpense,
  feeExpense,
  discountIncome,
  interestIncome,
  badDebtExpense,
  debtReliefIncome,
  ghostAccount,
}

enum AccountSource { builtin, user, import }

extension AccountTypeBehavior on AccountType {
  /// 用户可手动创建 / 编辑的账户类型;income / expense / equity 由系统管理。
  bool get isUserAccount =>
      this == AccountType.asset || this == AccountType.liability;

  /// 收入 / 支出分类账户的统称(CategoryService 操作对象)。
  bool get isCategory =>
      this == AccountType.income || this == AccountType.expense;

  /// 是否支持手动调整余额。
  bool supportsManualBalance(AccountSubtype? subtype) => isUserAccount;
}
