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
  allocationRequired(
    LedgerErrorCode.transactionInvalidCommand,
    'At least one allocation is required.',
  ),
  allocationAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Allocation amounts must be positive.',
  ),
  allocationTotalMismatch(
    LedgerErrorCode.transactionInvalidCommand,
    'Allocation total must equal the transaction amount.',
  ),
  allocationExceedsAvailable(
    LedgerErrorCode.transactionInvalidCommand,
    'Allocation exceeds the available amount for its account.',
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
  lendingAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Lending amount must be positive.',
  ),
  receivableCollectionAmountInvalid(
    LedgerErrorCode.transactionInvalidCommand,
    'Collection principal must be positive and interest cannot be negative.',
  ),
  badDebtAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Bad debt amount must be positive.',
  ),
  badDebtExceedsBalance(
    LedgerErrorCode.transactionInvalidCommand,
    'Bad debt exceeds the reducible receivable balance.',
  ),
  debtReliefAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Debt relief amount must be positive.',
  ),
  debtReliefExceedsBalance(
    LedgerErrorCode.transactionInvalidCommand,
    'Debt relief exceeds the reducible liability balance.',
  ),
  interestIncomeAccountMissing(
    LedgerErrorCode.transactionPostingFailed,
    'Interest income system account is required.',
  ),
  badDebtExpenseAccountMissing(
    LedgerErrorCode.transactionPostingFailed,
    'Bad debt expense system account is required.',
  ),
  debtReliefIncomeAccountMissing(
    LedgerErrorCode.transactionPostingFailed,
    'Debt relief income system account is required.',
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
  counterpartyNotFound(
    LedgerErrorCode.transactionInvalidCommand,
    'Counterparty does not exist.',
  ),
  lineAmountSignInvalid(
    LedgerErrorCode.transactionInvalidCommand,
    'Transaction line amount has an invalid sign.',
  ),
  lineRoleNotAllowed(
    LedgerErrorCode.transactionInvalidCommand,
    'Transaction line role is not allowed for this transaction purpose.',
  ),
  lineAccountExpectationViolated(
    LedgerErrorCode.transactionInvalidCommand,
    'Transaction line account presence does not match its role.',
  ),
  linesRequired(
    LedgerErrorCode.transactionInvalidCommand,
    'A transaction must have at least one line.',
  ),
  postingSystemAccountMissing(
    LedgerErrorCode.transactionInvalidCommand,
    'A system account required by the posting rule was not resolved.',
  ),
  postingAccountTypeMissing(
    LedgerErrorCode.transactionInvalidCommand,
    'A signed line requires its account type to determine the direction.',
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
  lendingInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Lending accounts cannot be resolved.',
  ),
  receivableCollectionInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Receivable collection accounts cannot be resolved.',
  ),
  badDebtInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Bad debt accounts cannot be resolved.',
  ),
  debtReliefInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Debt relief accounts cannot be resolved.',
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
  refundParentAdvanceClosed(
    LedgerErrorCode.transactionNotEditable,
    'Refund is not supported after advance is closed.',
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
  advanceReceivableRequired(
    LedgerErrorCode.transactionInvalidCommand,
    'An advance receivable account is required.',
  ),
  advanceManagementMismatch(
    LedgerErrorCode.transactionInvalidCommand,
    'Account-managed advances use top-level collection and settlement.',
  ),
  advanceReceivableAccountMismatch(
    LedgerErrorCode.transactionInvalidCommand,
    'Itemized advance children must use the parent receivable account.',
  ),
  advanceAlreadyClosed(
    LedgerErrorCode.transactionNotEditable,
    'This advance chain is already closed.',
  ),
  advanceAmountNotPositive(
    LedgerErrorCode.transactionInvalidCommand,
    'Advance amount must be positive.',
  ),
  advanceSettlementAccountsUnresolved(
    LedgerErrorCode.transactionInvalidCommand,
    'Advance close accounts cannot be resolved.',
  ),
  advanceSettlementAmountNegative(
    LedgerErrorCode.transactionInvalidCommand,
    'Received amount cannot be negative.',
  ),
  advanceSettlementTransactionRequired(
    LedgerErrorCode.transactionNotEditable,
    'An advance settlement transaction is required.',
  ),
  advanceCompensationIncomeRequired(
    LedgerErrorCode.transactionPostingFailed,
    'Gap income account is required.',
  ),
  advanceInstructionUnresolvable(
    LedgerErrorCode.transactionPostingFailed,
    'Advance accounts cannot be resolved.',
  ),
  advanceParentNotAdvance(
    LedgerErrorCode.transactionNotEditable,
    'Parent transaction is not an advance.',
  ),
  advanceCollectionAccountsUnresolved(
    LedgerErrorCode.transactionInvalidCommand,
    'Advance receipt accounts cannot be resolved.',
  ),
  advanceCollectionExceedsOutstanding(
    LedgerErrorCode.transactionInvalidCommand,
    'Receipt exceeds outstanding receivable.',
  ),
  advanceRecoveryExceedsAdvance(
    LedgerErrorCode.transactionInvalidCommand,
    'Refunds and advance receipts exceed the advance amount.',
  ),
  advanceCollectionTransactionRequired(
    LedgerErrorCode.transactionNotEditable,
    'An advance collection transaction is required.',
  ),
  advanceNotFound(LedgerErrorCode.transactionNotFound, 'Advance not found.'),
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
