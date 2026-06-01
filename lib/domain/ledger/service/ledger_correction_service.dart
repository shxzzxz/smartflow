import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../entity/account.dart';
import '../entity/root_transaction_group.dart';
import '../entity/transaction.dart';
import '../port/account_repository.dart';
import '../port/root_transaction_group_repository.dart';
import '../port/system_account_resolver.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/posting_instruction.dart';
import '../valobj/posting_result.dart';
import 'account_posting_service.dart';
import 'account_role_policy.dart';
import 'child_transaction_migration_policy.dart';
import 'ledger_rule.dart';
import 'posting_engine.dart';
import 'posting_instruction_resolver.dart';

class LedgerCorrectionService {
  const LedgerCorrectionService({
    required RootTransactionGroupRepository rootGroupRepository,
    required AccountRepository accountRepository,
    required PostingInstructionResolver postingInstructionResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
    required ChildTransactionMigrationPolicy childMigrationPolicy,
    required SystemAccountResolver systemAccountResolver,
  }) : _rootGroupRepository = rootGroupRepository,
       _accountRepository = accountRepository,
       _postingInstructionResolver = postingInstructionResolver,
       _postingEngine = postingEngine,
       _accountPostingService = accountPostingService,
       _accountRolePolicy = accountRolePolicy,
       _childMigrationPolicy = childMigrationPolicy,
       _systemAccountResolver = systemAccountResolver;

  final RootTransactionGroupRepository _rootGroupRepository;
  final AccountRepository _accountRepository;
  final PostingInstructionResolver _postingInstructionResolver;
  final PostingEngine _postingEngine;
  final AccountPostingService _accountPostingService;
  final AccountRolePolicy _accountRolePolicy;
  final ChildTransactionMigrationPolicy _childMigrationPolicy;
  final SystemAccountResolver _systemAccountResolver;

  Future<Result<ParentReplacementResult>> replaceParentTransaction(
    ReplaceParentTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    final currentParent = group.parentTransaction;
    if (instruction.transactionId != currentParent.id) {
      return _failure('parent_transaction_required');
    }
    if (currentParent.businessState != BusinessState.current) {
      return _failure('transaction_not_current');
    }
    if (currentParent.businessPurpose != instruction.expectedCurrentPurpose) {
      return _failure('transaction_purpose_mismatch');
    }

    final currentInstructionResult = _postingInstructionResolver.resolve(
      currentParent,
    );
    if (currentInstructionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final replacementInstructionResult = instruction.replacementPatch.applyTo(
      currentInstructionResult.value,
    );
    if (replacementInstructionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final replacementInstruction = replacementInstructionResult.value;
    final roleFailure = await _validatePostingInstruction(
      replacementInstruction,
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final candidateParentResult = await _createPostingCandidate(
      replacementInstruction,
    );
    if (candidateParentResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final candidateParent = candidateParentResult.value;
    if (hasSamePostingShape(currentParent, candidateParent)) {
      _applyParentCorrectionFields(group, instruction);
      return Result.success(
        ParentReplacementResult(
          transactions: group.transactions.toList(),
          accounts: const [],
          currentTransaction: currentParent,
          currentGroup: group,
        ),
      );
    }

    final convertibleFailure = _childMigrationPolicy.validateConvertible(
      oldGroup: group,
      newParentPurpose: replacementInstruction.businessPurpose,
      newParent: candidateParent,
    );
    if (convertibleFailure != null) return Result.failure(convertibleFailure);

    final parentReplacementResult = _postingEngine.createReplacement(
      original: currentParent,
      replacement: candidateParent,
      reason: MutationReason.correction,
    );
    if (parentReplacementResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final parentReplacement = parentReplacementResult.value;
    final newParent = parentReplacement.correctionTransaction;

    final childMigrationResult = await _childMigrationPolicy.migrateChildren(
      oldGroup: group,
      newParent: newParent,
    );
    if (childMigrationResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final childReplacements = <TransactionReplacement>[];
    for (final migration in childMigrationResult.value) {
      final replacementResult = _postingEngine.createReplacement(
        original: migration.originalChild,
        replacement: migration.replacementCandidate,
        reason: MutationReason.correction,
      );
      if (replacementResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      childReplacements.add(replacementResult.value);
    }

    final replacements = [parentReplacement, ...childReplacements];
    final postingTransactions = [
      for (final replacement in replacements)
        ...replacement.postingTransactions,
    ];
    final accounts = await _loadAccountsFor(postingTransactions);
    final changedAccounts = _accountPostingService.applyAll(
      transactions: postingTransactions,
      accounts: accounts,
    );
    final currentGroup = RootTransactionGroup(
      rootTransactionId: group.rootTransactionId,
      parentTransaction: newParent,
      childTransactions: [
        for (final replacement in childReplacements)
          replacement.correctionTransaction,
      ],
    );
    _applyParentCorrectionFields(currentGroup, instruction);

    return Result.success(
      ParentReplacementResult(
        transactions: [
          for (final replacement in replacements) ...replacement.transactions,
        ],
        accounts: changedAccounts,
        currentTransaction: newParent,
        currentGroup: currentGroup,
      ),
    );
  }

  Future<Result<ChildReplacementResult>> replaceRefundTransaction(
    ReplaceRefundTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    final currentRefund = group.findTransaction(instruction.transactionId);
    if (currentRefund == null ||
        currentRefund.id == group.parentTransaction.id ||
        currentRefund.businessPurpose != BusinessPurpose.refund) {
      return _failure('refund_transaction_required');
    }
    if (currentRefund.businessState != BusinessState.current) {
      return _failure('transaction_not_current');
    }

    final currentInstructionResult = _postingInstructionResolver.resolveRefund(
      currentRefund,
    );
    if (currentInstructionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final replacementInstructionResult = instruction.replacementPatch.applyTo(
      currentInstructionResult.value,
    );
    if (replacementInstructionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final replacementInstruction = replacementInstructionResult.value;
    final parent = group.parentTransaction;
    final remaining =
        parent.primaryAmount -
        group.refundedTotal() +
        currentRefund.primaryAmount;
    if (replacementInstruction.amount.minorUnits > remaining.minorUnits) {
      return _failure('refund_exceeds_remaining');
    }

    final parentInstructionResult = _postingInstructionResolver.resolve(parent);
    if (parentInstructionResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final refundOffsetAccountId = resolveRefundOffsetAccountId(
      parentInstructionResult.value,
    );
    if (refundOffsetAccountId == null) {
      return _failure('refund_parent_not_supported');
    }
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountId: replacementInstruction.refundToAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final candidateRefundResult = _postingEngine.createRefund(
      instruction: replacementInstruction,
      parent: parent,
      refundOffsetAccountId: refundOffsetAccountId,
    );
    if (candidateRefundResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final candidateRefund = candidateRefundResult.value;
    if (hasSamePostingShape(currentRefund, candidateRefund)) {
      _applyChildCorrectionFields(currentRefund, instruction);
      return Result.success(
        ChildReplacementResult(
          transactions: [currentRefund],
          accounts: const [],
          currentTransaction: currentRefund,
          currentGroup: group,
        ),
      );
    }

    final replacementResult = _postingEngine.createReplacement(
      original: currentRefund,
      replacement: candidateRefund,
      reason: MutationReason.correction,
    );
    if (replacementResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final replacement = replacementResult.value;
    final postingTransactions = replacement.postingTransactions.toList();
    final accounts = await _loadAccountsFor(postingTransactions);
    final changedAccounts = _accountPostingService.applyAll(
      transactions: postingTransactions,
      accounts: accounts,
    );
    final correctedRefund = replacement.correctionTransaction;
    _applyChildCorrectionFields(correctedRefund, instruction);
    final currentGroup = RootTransactionGroup(
      rootTransactionId: group.rootTransactionId,
      parentTransaction: parent,
      childTransactions: [
        for (final child in group.childTransactions)
          child.id == currentRefund.id ? correctedRefund : child,
      ],
    );
    return Result.success(
      ChildReplacementResult(
        transactions: replacement.transactions.toList(),
        accounts: changedAccounts,
        currentTransaction: correctedRefund,
        currentGroup: currentGroup,
      ),
    );
  }

  Future<Result<ChildReplacementResult>> replaceReimbursementReceipt(
    ReplaceReimbursementReceiptTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    final currentReceipt = group.findTransaction(instruction.transactionId);
    if (currentReceipt == null ||
        currentReceipt.id == group.parentTransaction.id ||
        currentReceipt.businessPurpose !=
            BusinessPurpose.reimbursementReceipt) {
      return _failure('reimbursement_receipt_transaction_required');
    }
    if (currentReceipt.businessState != BusinessState.current) {
      return _failure('transaction_not_current');
    }
    final advanceFailure = _validateReimbursementAdvance(group);
    if (advanceFailure != null) return Result.failure(advanceFailure);
    if (group.reimbursementClosed) {
      return _failure('reimbursement_already_closed');
    }

    final remaining =
        group.parentTransaction.primaryAmount -
        group.reimbursementReceivedTotal() +
        currentReceipt.primaryAmount;
    final amount = instruction.amount ?? currentReceipt.primaryAmount;
    final receiveAccountId =
        instruction.receiveAccountId ??
        _firstEntryAccount(currentReceipt, EntryDirection.debit);
    final receivableAccountId =
        instruction.receivableAccountId ??
        _firstEntryAccount(currentReceipt, EntryDirection.credit);
    if (receiveAccountId == null || receivableAccountId == null) {
      return _failure('reimbursement_receipt_accounts_unresolved');
    }
    if (amount.minorUnits > remaining.minorUnits) {
      return _failure('reimbursement_receipt_exceeds_outstanding');
    }

    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final candidateResult = _postingEngine.createReimbursementReceipt(
      instruction: ReimbursementReceiptInstruction(
        advanceTransactionId: group.parentTransaction.id,
        amount: amount,
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
        occurredAt: currentReceipt.occurredAt,
        counterpartyName: currentReceipt.counterpartyName,
        note: currentReceipt.note,
      ),
      advance: group.parentTransaction,
    );
    if (candidateResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _replaceChildWithCandidate(
      group: group,
      currentChild: currentReceipt,
      candidateChild: candidateResult.value,
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
  }

  Future<Result<ChildReplacementResult>> replaceReimbursementClose(
    ReplaceReimbursementCloseTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    final currentClose = group.findTransaction(instruction.transactionId);
    if (currentClose == null ||
        currentClose.id == group.parentTransaction.id ||
        currentClose.businessPurpose != BusinessPurpose.reimbursementClose) {
      return _failure('reimbursement_close_transaction_required');
    }
    if (currentClose.businessState != BusinessState.current) {
      return _failure('transaction_not_current');
    }
    final advanceFailure = _validateReimbursementAdvance(group);
    if (advanceFailure != null) return Result.failure(advanceFailure);

    final outstanding =
        _detailAmount(
          currentClose,
          TransactionDetailType.reimbursementCloseMain,
        ) ??
        Money.zero();
    final actualReceivedAmount =
        instruction.actualReceivedAmount ?? currentClose.primaryAmount;
    final receiveAccountId =
        instruction.receiveAccountId ??
        _firstEntryAccount(currentClose, EntryDirection.debit);
    final receivableAccountId =
        instruction.receivableAccountId ??
        _firstEntryAccount(currentClose, EntryDirection.credit);
    if (receiveAccountId == null || receivableAccountId == null) {
      return _failure('reimbursement_close_accounts_unresolved');
    }
    final gapIncomeAccountId =
        actualReceivedAmount.minorUnits > outstanding.minorUnits
            ? await _systemAccountResolver.resolveReimbursementGapIncome()
            : null;
    final roleFailure = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementClose(
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
        receivesCash: actualReceivedAmount.minorUnits > 0,
      ),
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    final candidateResult = _postingEngine.createReimbursementClose(
      instruction: ReimbursementCloseInstruction(
        advanceTransactionId: group.parentTransaction.id,
        actualReceivedAmount: actualReceivedAmount,
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
        occurredAt: currentClose.occurredAt,
        counterpartyName: currentClose.counterpartyName,
        note: currentClose.note,
      ),
      advance: group.parentTransaction,
      outstanding: outstanding,
      gapIncomeAccountId: gapIncomeAccountId,
    );
    if (candidateResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _replaceChildWithCandidate(
      group: group,
      currentChild: currentClose,
      candidateChild: candidateResult.value,
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
  }

  Future<Result<CancellationResult>> cancelTransaction(
    CancelTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) return _failure('transaction_not_found');
    final target = group.findTransaction(instruction.transactionId);
    if (target == null) return _failure('transaction_not_found');
    if (target.businessState != BusinessState.current) {
      return _failure('transaction_not_current');
    }

    final originals =
        target.id == group.parentTransaction.id
            ? group.transactions.toList()
            : [target];
    final cancellations = <TransactionCancellation>[];
    for (final original in originals) {
      final cancellationResult = _postingEngine.createCancellation(
        original: original,
        reason: MutationReason.delete,
      );
      if (cancellationResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      cancellations.add(cancellationResult.value);
    }

    final postingTransactions = [
      for (final cancellation in cancellations)
        ...cancellation.postingTransactions,
    ];
    final accounts = await _loadAccountsFor(postingTransactions);
    final changedAccounts = _accountPostingService.applyAll(
      transactions: postingTransactions,
      accounts: accounts,
    );
    return Result.success(
      CancellationResult(
        transactions: [
          for (final cancellation in cancellations)
            ...cancellation.transactions,
        ],
        accounts: changedAccounts,
      ),
    );
  }

  Future<Map<String, Account>> _loadAccountsFor(
    Iterable<Transaction> transactions,
  ) async {
    final ids = {
      for (final transaction in transactions) ...transaction.accountIds,
    };
    final accounts = await _accountRepository.findByIds(ids);
    return {for (final account in accounts) account.id: account};
  }

  Future<Result<ChildReplacementResult>> _replaceChildWithCandidate({
    required RootTransactionGroup group,
    required Transaction currentChild,
    required Transaction candidateChild,
    DateTime? occurredAt,
    Patch<String?>? counterpartyName,
    Patch<String?>? note,
  }) async {
    if (hasSamePostingShape(currentChild, candidateChild)) {
      currentChild.updateBasicInfo(
        occurredAt: occurredAt,
        counterpartyName: counterpartyName,
        note: note,
      );
      return Result.success(
        ChildReplacementResult(
          transactions: [currentChild],
          accounts: const [],
          currentTransaction: currentChild,
          currentGroup: group,
        ),
      );
    }

    final replacementResult = _postingEngine.createReplacement(
      original: currentChild,
      replacement: candidateChild,
      reason: MutationReason.correction,
    );
    if (replacementResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final replacement = replacementResult.value;
    final postingTransactions = replacement.postingTransactions.toList();
    final accounts = await _loadAccountsFor(postingTransactions);
    final changedAccounts = _accountPostingService.applyAll(
      transactions: postingTransactions,
      accounts: accounts,
    );
    final correctedChild = replacement.correctionTransaction;
    correctedChild.updateBasicInfo(
      occurredAt: occurredAt,
      counterpartyName: counterpartyName,
      note: note,
    );
    final currentGroup = RootTransactionGroup(
      rootTransactionId: group.rootTransactionId,
      parentTransaction: group.parentTransaction,
      childTransactions: [
        for (final child in group.childTransactions)
          child.id == currentChild.id ? correctedChild : child,
      ],
    );
    return Result.success(
      ChildReplacementResult(
        transactions: replacement.transactions.toList(),
        accounts: changedAccounts,
        currentTransaction: correctedChild,
        currentGroup: currentGroup,
      ),
    );
  }

  void _applyParentCorrectionFields(
    RootTransactionGroup group,
    ReplaceParentTransactionInstruction instruction,
  ) {
    group.parentTransaction.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
    group.updateReportingFlags(
      isExcludedFromStats: instruction.isExcludedFromStats,
      isExcludedFromBudget: instruction.isExcludedFromBudget,
    );
  }

  void _applyChildCorrectionFields(
    Transaction transaction,
    ReplaceRefundTransactionInstruction instruction,
  ) {
    transaction.updateBasicInfo(
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
  }

  String? _firstEntryAccount(
    Transaction transaction,
    EntryDirection direction,
  ) {
    for (final entry in transaction.entries) {
      if (entry.direction == direction) return entry.accountId;
    }
    return null;
  }

  Failure? _validateReimbursementAdvance(RootTransactionGroup group) {
    final advance = group.parentTransaction;
    if (advance.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return const Failure(
        code: 'reimbursement_parent_not_advance',
        message: 'Parent transaction is not a reimbursement advance.',
      );
    }
    if (advance.businessState != BusinessState.current) {
      return const Failure(
        code: 'reimbursement_advance_not_current',
        message: 'Reimbursement advance is not current.',
      );
    }
    return null;
  }

  Money? _detailAmount(Transaction transaction, TransactionDetailType type) {
    for (final detail in transaction.details) {
      if (detail.type == type) return detail.amount;
    }
    return null;
  }

  Future<Failure?> _validatePostingInstruction(PostingInstruction instruction) {
    return switch (instruction) {
      ExpenseInstruction i => _accountRolePolicy.validate(
        AccountRoleContext.expense(
          paidFromAccountId: i.paidFromAccountId,
          expenseAccountId: i.expenseAccountId,
        ),
      ),
      IncomeInstruction i => _accountRolePolicy.validate(
        AccountRoleContext.income(
          receiveAccountId: i.receiveAccountId,
          incomeAccountId: i.incomeAccountId,
        ),
      ),
      ReimbursementAdvanceInstruction i => _accountRolePolicy.validate(
        AccountRoleContext.reimbursementAdvance(
          receivableAccountId: i.receivableAccountId,
          paidFromAccountId: i.paidFromAccountId,
          expenseCategoryId: i.expenseAccountId,
        ),
      ),
      TransferInstruction i => _accountRolePolicy.validate(
        AccountRoleContext.transfer(
          fromAccountId: i.fromAccountId,
          toAccountId: i.toAccountId,
        ),
      ),
      RepaymentInstruction i => _accountRolePolicy.validate(
        AccountRoleContext.repayment(
          liabilityAccountId: i.liabilityAccountId,
          paidFromAccountId: i.paidFromAccountId,
        ),
      ),
      BorrowingInstruction i => _accountRolePolicy.validate(
        AccountRoleContext.borrowing(
          liabilityAccountId: i.liabilityAccountId,
          receiveAccountId: i.receiveAccountId,
        ),
      ),
    };
  }

  Future<Result<Transaction>> _createPostingCandidate(
    PostingInstruction instruction,
  ) async {
    if (instruction is TransferInstruction) {
      final hasFee =
          instruction.feeAmount != null &&
          instruction.feeAmount!.minorUnits > 0;
      return _postingEngine.createTransfer(
        instruction,
        feeExpenseAccountId:
            hasFee ? await _systemAccountResolver.resolveFeeExpense() : null,
      );
    }
    if (instruction is RepaymentInstruction) {
      final hasInterest =
          instruction.interest != null && instruction.interest!.minorUnits > 0;
      final hasFee = instruction.fee != null && instruction.fee!.minorUnits > 0;
      final hasDiscount =
          instruction.discount != null && instruction.discount!.minorUnits > 0;
      return _postingEngine.createRepayment(
        instruction,
        interestExpenseAccountId:
            hasInterest
                ? await _systemAccountResolver.resolveInterestExpense()
                : null,
        feeExpenseAccountId:
            hasFee ? await _systemAccountResolver.resolveFeeExpense() : null,
        discountIncomeAccountId:
            hasDiscount
                ? await _systemAccountResolver.resolveDiscountIncome()
                : null,
      );
    }
    return _postingEngine.create(instruction);
  }

  Result<T> _failure<T>(String code) {
    return Result.failure(
      Failure(code: code, message: 'Ledger correction failed: $code.'),
    );
  }
}
