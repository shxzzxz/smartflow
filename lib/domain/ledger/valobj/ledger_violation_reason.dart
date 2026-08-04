import '../../../core/error/app_exception.dart';
import 'ledger_error_code.dart';

enum LedgerViolationReason {
  accountArchived(LedgerErrorCode.accountUnavailable, 'Account is archived.'),
  accountNotFound(LedgerErrorCode.accountNotFound, 'Account does not exist.'),
  accountRoleInvalid(
    LedgerErrorCode.accountInvalidRole,
    'Account cannot be used for this transaction.',
  ),
  accountSubtypeInvalid(
    LedgerErrorCode.accountInvalidRole,
    'Account subtype is invalid for this transaction.',
  ),
  accountSubtypeTypeMismatch(
    LedgerErrorCode.accountInvalidRole,
    'Account subtype does not match account type.',
  ),
  accountArchiveNotAllowed(
    LedgerErrorCode.accountUnavailable,
    'This account cannot be archived.',
  ),
  accountTargetBalanceNegative(
    LedgerErrorCode.accountInvalidCommand,
    'Target balance cannot be negative.',
  ),
  accountTargetBalanceNotSupported(
    LedgerErrorCode.accountInvalidCommand,
    'This account type does not support balance adjustment.',
  ),
  accountTypeNotEditable(
    LedgerErrorCode.accountInvalidCommand,
    'This account type cannot be edited here.',
  ),
  balanceAdjustmentZeroDelta(
    LedgerErrorCode.transactionInvalidCommand,
    'Balance is already at the target value.',
  ),
  borrowingAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Borrowing amount must be positive.',
  ),
  borrowingInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Borrowing accounts cannot be resolved.',
  ),
  categoryArchived(
    LedgerErrorCode.categoryUnavailable,
    'Category is archived.',
  ),
  categoryDepthExceeded(
    LedgerErrorCode.categoryInvalidCommand,
    'Categories support one child level in this stage.',
  ),
  categoryHasChildren(
    LedgerErrorCode.categoryInvalidCommand,
    'Category still has child categories.',
  ),
  categoryReferencedByTransactions(
    LedgerErrorCode.categoryInUse,
    'Category is referenced by transactions.',
  ),
  categorySystemManaged(
    LedgerErrorCode.categoryUnavailable,
    'System category cannot be managed.',
  ),
  categoryMigrationTargetInvalid(
    LedgerErrorCode.categoryInvalidCommand,
    'Migration target category is invalid.',
  ),
  categoryParentArchived(
    LedgerErrorCode.categoryInvalidParent,
    'Archived category cannot be used as parent.',
  ),
  categoryParentTypeMismatch(
    LedgerErrorCode.categoryInvalidParent,
    'Parent category type must match child category type.',
  ),
  detailAmountSignInvalid(
    LedgerErrorCode.transactionInvalidCommand,
    'Detail amount has an invalid sign.',
  ),
  detailTypeNotAllowed(
    LedgerErrorCode.transactionInvalidCommand,
    'Detail type is not allowed for this transaction purpose.',
  ),
  detailsRequired(
    LedgerErrorCode.transactionInvalidCommand,
    'A transaction must have at least one detail.',
  ),
  entriesNotBalanced(
    LedgerErrorCode.transactionInvalidCommand,
    'Debit and credit entries must be balanced.',
  ),
  entriesRequired(
    LedgerErrorCode.transactionInvalidCommand,
    'A transaction must have at least two entries.',
  ),
  entryAmountSignInvalid(
    LedgerErrorCode.transactionInvalidCommand,
    'Entry amount has an invalid sign.',
  ),
  expenseAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Expense amount must be positive.',
  ),
  expenseInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Expense accounts cannot be resolved.',
  ),
  incomeAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Income amount must be positive.',
  ),
  incomeInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Income accounts cannot be resolved.',
  ),
  openingBalanceNotSupported(
    LedgerErrorCode.accountInvalidCommand,
    'This account type does not support opening balance.',
  ),
  openingBalanceZero(
    LedgerErrorCode.transactionInvalidCommand,
    'Opening balance amount cannot be zero.',
  ),
  parentTransactionRequired(
    LedgerErrorCode.transactionNotEditable,
    'A parent transaction is required.',
  ),
  postingFailed(
    LedgerErrorCode.transactionPostingFailed,
    'Transaction posting failed.',
  ),
  primaryAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Primary amount has an invalid sign.',
  ),
  refundAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Refund amount must be positive.',
  ),
  refundExceedsRemaining(
    LedgerErrorCode.transactionInvalidCommand,
    'Refund exceeds remaining refundable amount.',
  ),
  refundParentNotCurrent(
    LedgerErrorCode.transactionNotEditable,
    'Refund can only be applied to a current expense.',
  ),
  refundParentNotExpense(
    LedgerErrorCode.transactionNotEditable,
    'Refund can only be applied to an expense transaction.',
  ),
  refundParentNotFound(
    LedgerErrorCode.transactionNotFound,
    'Original expense not found.',
  ),
  refundParentReimbursementClosed(
    LedgerErrorCode.transactionNotEditable,
    'Refund is not supported after reimbursement is closed.',
  ),
  refundParentNotSupported(
    LedgerErrorCode.transactionNotEditable,
    'This parent transaction does not support refunds.',
  ),
  refundToAccountNotFound(
    LedgerErrorCode.accountNotFound,
    'Refund receiving account cannot be resolved.',
  ),
  refundTransactionRequired(
    LedgerErrorCode.transactionNotEditable,
    'A refund transaction is required.',
  ),
  reimbursementAdvanceReceivableRequired(
    LedgerErrorCode.transactionInvalidCommand,
    'A reimbursement receivable account is required.',
  ),
  reimbursementAlreadyClosed(
    LedgerErrorCode.transactionNotEditable,
    'This reimbursement chain is already closed.',
  ),
  reimbursementAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Reimbursement amount must be positive.',
  ),
  reimbursementCloseAccountsUnresolved(
    LedgerErrorCode.transactionInvalidCommand,
    'Reimbursement close accounts cannot be resolved.',
  ),
  reimbursementCloseAmountNegative(
    LedgerErrorCode.transactionInvalidCommand,
    'Received amount cannot be negative.',
  ),
  reimbursementCloseTransactionRequired(
    LedgerErrorCode.transactionNotEditable,
    'A reimbursement close transaction is required.',
  ),
  reimbursementGapIncomeRequired(
    LedgerErrorCode.transactionPostingFailed,
    'Gap income account is required.',
  ),
  reimbursementInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Reimbursement advance accounts cannot be resolved.',
  ),
  reimbursementParentNotAdvance(
    LedgerErrorCode.transactionNotEditable,
    'Parent transaction is not a reimbursement advance.',
  ),
  reimbursementReceiptAccountsUnresolved(
    LedgerErrorCode.transactionInvalidCommand,
    'Reimbursement receipt accounts cannot be resolved.',
  ),
  reimbursementReceiptExceedsOutstanding(
    LedgerErrorCode.transactionInvalidCommand,
    'Receipt exceeds outstanding receivable.',
  ),
  reimbursementRecoveryExceedsAdvance(
    LedgerErrorCode.transactionInvalidCommand,
    'Refunds and reimbursement receipts exceed the advance amount.',
  ),
  reimbursementReceiptTransactionRequired(
    LedgerErrorCode.transactionNotEditable,
    'A reimbursement receipt transaction is required.',
  ),
  reimbursementAdvanceNotFound(
    LedgerErrorCode.transactionNotFound,
    'Reimbursement advance not found.',
  ),
  repaymentDiscountAccountMissing(
    LedgerErrorCode.transactionInvalidCommand,
    'Discount income system account is required.',
  ),
  repaymentFeeAccountMissing(
    LedgerErrorCode.transactionInvalidCommand,
    'Fee expense system account is required.',
  ),
  repaymentInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Repayment accounts cannot be resolved.',
  ),
  repaymentInterestAccountMissing(
    LedgerErrorCode.transactionInvalidCommand,
    'Interest expense system account is required.',
  ),
  repaymentPrincipalNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Repayment principal must be positive.',
  ),
  repaymentTotalPaidNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Repayment total paid must be positive.',
  ),
  transactionGroupHasIncompatibleChildren(
    LedgerErrorCode.transactionNotEditable,
    'This transaction group has child records incompatible with the edit.',
  ),
  transactionNotFound(
    LedgerErrorCode.transactionNotFound,
    'Transaction does not exist.',
  ),
  transactionPurposeMismatch(
    LedgerErrorCode.transactionNotEditable,
    'Transaction purpose does not match the command.',
  ),
  transferAccountsMustDiffer(
    LedgerErrorCode.transactionInvalidCommand,
    'Transfer source and target account must differ.',
  ),
  transferAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Transfer amount must be positive.',
  ),
  transferFeeAccountRequired(
    LedgerErrorCode.transactionInvalidCommand,
    'Transfer fee account is required.',
  ),
  transferFeeNegative(
    LedgerErrorCode.transactionInvalidCommand,
    'Transfer fee cannot be negative.',
  ),
  transferInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Transfer accounts cannot be resolved.',
  ),
  unsupportedPostingInstructionResolution(
    LedgerErrorCode.transactionPostingFailed,
    'Cannot resolve transaction as a posting instruction.',
  ),
  unsupportedEditSource(
    LedgerErrorCode.transactionInvalidCommand,
    'This transaction cannot be edited to the requested purpose.',
  );

  const LedgerViolationReason(this.errorCode, this.defaultMessage);

  final LedgerErrorCode errorCode;
  final String defaultMessage;

  BusinessException toException({String? message}) {
    return BusinessException(errorCode, message: message ?? defaultMessage);
  }

  Never throwException({String? message}) {
    throw toException(message: message);
  }
}
