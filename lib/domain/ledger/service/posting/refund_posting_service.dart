import '../../entity/transaction_group.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/transaction_group_repository.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/account_amount_allocation.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import 'account_posting_service.dart';
import 'posting_engine.dart';
import 'posting_application_service.dart';

class RefundPostingService {
  const RefundPostingService({
    required TransactionGroupRepository transactionGroupRepository,
    required AccountRepository accountRepository,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
    PostingApplicationService? postingApplicationService,
  }) : _transactionGroupRepository = transactionGroupRepository,
       _postingEngine = postingEngine,
       _accountRolePolicy = accountRolePolicy,
       _accountRepository = accountRepository,
       _accountPostingService = accountPostingService,
       _postingApplicationService = postingApplicationService;

  final TransactionGroupRepository _transactionGroupRepository;
  final AccountRepository _accountRepository;
  final PostingEngine _postingEngine;
  final AccountRolePolicy _accountRolePolicy;
  final AccountPostingService _accountPostingService;
  final PostingApplicationService? _postingApplicationService;

  PostingApplicationService get _postingApplication =>
      _postingApplicationService ??
      PostingApplicationService(
        accountRepository: _accountRepository,
        accountPostingService: _accountPostingService,
      );

  Future<PostingResult> postRefund(RefundInstruction instruction) async {
    final group = await _transactionGroupRepository.findByTransactionId(
      instruction.parentTransactionId,
    );
    if (group == null) {
      LedgerViolationReason.refundParentNotFound.throwException();
    }

    final parent = group.parentTransaction;
    final parentViolation = _validateRefundParent(parent, group, instruction);
    if (parentViolation != null) parentViolation.throwException();

    final remaining =
        parent.businessPurpose == BusinessPurpose.reimbursementAdvance
        ? group.reimbursementOutstanding()
        : parent.primaryAmount - group.refundedTotal();
    if (instruction.amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.refundExceedsRemaining.throwException();
    }

    final categoryAllocations = _refundCategoryAllocations(
      instruction: instruction,
      group: group,
    );
    if (!group.allocationsFitRefundableCategories(categoryAllocations)) {
      LedgerViolationReason.allocationExceedsAvailable.throwException();
    }
    final normalizedInstruction = RefundInstruction(
      parentTransactionId: instruction.parentTransactionId,
      amount: instruction.amount,
      categoryAllocations: categoryAllocations,
      settlementAllocations: instruction.settlementAllocations,
      occurredAt: instruction.occurredAt,
      postedAt: instruction.postedAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountIds: normalizedInstruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
        categoryAccountIds: normalizedInstruction.categoryAllocations.map(
          (allocation) => allocation.accountId,
        ),
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    final transaction = _postingEngine.createRefund(
      parent: parent,
      instruction: normalizedInstruction,
    );
    return _postingApplication.apply(transaction);
  }

  List<AccountAmountAllocation> _refundCategoryAllocations({
    required RefundInstruction instruction,
    required TransactionGroup group,
  }) {
    if (instruction.categoryAllocations.isNotEmpty) {
      return instruction.categoryAllocations;
    }
    final remaining = group.remainingRefundableCategoryAllocations();
    if (remaining.length != 1) {
      LedgerViolationReason.allocationRequired.throwException(
        message: 'Refund category allocations are required.',
      );
    }
    return [remaining.single.copyWith(amount: instruction.amount)];
  }

  LedgerViolationReason? _validateRefundParent(
    Transaction parent,
    TransactionGroup group,
    RefundInstruction instruction,
  ) {
    if (parent.id != instruction.parentTransactionId ||
        (parent.businessPurpose != BusinessPurpose.dailyExpense &&
            parent.businessPurpose != BusinessPurpose.reimbursementAdvance)) {
      return LedgerViolationReason.refundParentNotExpense;
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance &&
        group.reimbursementClosed) {
      return LedgerViolationReason.refundParentReimbursementClosed;
    }
    return null;
  }
}
