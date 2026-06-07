import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import '../../entity/account.dart';
import '../../entity/root_transaction_group.dart';
import '../../entity/transaction.dart';
import '../../port/account_repository.dart';
import '../../port/root_transaction_group_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import '../posting/account_posting_service.dart';
import '../posting/posting_engine.dart';
import '../posting/posting_instruction_resolver.dart';
import '../posting/posting_rule.dart';
import 'child_transaction_migration_policy.dart';

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

  Future<ParentReplacementResult> replaceParentTransaction(
    ReplaceParentTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    final targetViolation = _validateParentReplacementTarget(
      group,
      instruction,
    );
    if (targetViolation != null) targetViolation.throwException();

    final currentParent = group!.parentTransaction;
    final currentInstruction = _postingInstructionResolver.resolve(
      currentParent,
    );
    final replacementInstruction = instruction.replacementPatch.applyTo(
      currentInstruction,
    );
    final roleViolation = await _validatePostingInstruction(
      replacementInstruction,
    );
    if (roleViolation != null) roleViolation.throwException();

    final candidateParent = await _createPostingCandidate(
      replacementInstruction,
    );
    if (hasSamePostingShape(currentParent, candidateParent)) {
      _applyParentCorrectionFields(group, instruction);
      return ParentReplacementResult(
        transactions: group.transactions.toList(),
        accounts: const [],
        currentTransaction: currentParent,
        currentGroup: group,
      );
    }

    final convertibleViolation = _childMigrationPolicy.validateConvertible(
      oldGroup: group,
      newParentPurpose: replacementInstruction.businessPurpose,
      newParent: candidateParent,
    );
    if (convertibleViolation != null) convertibleViolation.throwException();

    final parentReplacement = _postingEngine.createReplacement(
      original: currentParent,
      replacement: candidateParent,
      reason: MutationReason.correction,
    );
    final newParent = parentReplacement.correctionTransaction;

    final childMigrations = await _childMigrationPolicy.migrateChildren(
      oldGroup: group,
      newParent: newParent,
    );
    final childReplacements = <TransactionReplacement>[];
    for (final migration in childMigrations) {
      final replacement = _postingEngine.createReplacement(
        original: migration.originalChild,
        replacement: migration.replacementCandidate,
        reason: MutationReason.correction,
      );
      childReplacements.add(replacement);
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

    return ParentReplacementResult(
      transactions: [
        for (final replacement in replacements) ...replacement.transactions,
      ],
      accounts: changedAccounts,
      currentTransaction: newParent,
      currentGroup: currentGroup,
    );
  }

  Future<ChildReplacementResult> replaceRefundTransaction(
    ReplaceRefundTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    final currentRefund = group.findTransaction(instruction.transactionId);
    if (currentRefund == null ||
        currentRefund.id == group.parentTransaction.id ||
        currentRefund.businessPurpose != BusinessPurpose.refund) {
      LedgerViolationReason.refundTransactionRequired.throwException();
    }
    if (currentRefund.businessState != BusinessState.current) {
      LedgerViolationReason.transactionNotCurrent.throwException();
    }

    final currentInstruction = _postingInstructionResolver.resolveRefund(
      currentRefund,
    );
    final replacementInstruction = instruction.replacementPatch.applyTo(
      currentInstruction,
    );
    final parent = group.parentTransaction;
    final remaining =
        parent.primaryAmount -
        group.refundedTotal() +
        currentRefund.primaryAmount;
    if (replacementInstruction.amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.refundExceedsRemaining.throwException();
    }

    final parentInstruction = _postingInstructionResolver.resolve(parent);
    final refundOffsetAccountId = resolveRefundOffsetAccountId(
      parentInstruction,
    );
    if (refundOffsetAccountId == null) {
      LedgerViolationReason.refundParentNotSupported.throwException();
    }
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.refund(
        refundToAccountId: replacementInstruction.refundToAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    final candidateRefund = _postingEngine.createRefund(
      instruction: replacementInstruction,
      parent: parent,
      refundOffsetAccountId: refundOffsetAccountId,
    );
    if (hasSamePostingShape(currentRefund, candidateRefund)) {
      _applyChildCorrectionFields(currentRefund, instruction);
      return ChildReplacementResult(
        transactions: [currentRefund],
        accounts: const [],
        currentTransaction: currentRefund,
        currentGroup: group,
      );
    }

    final replacement = _postingEngine.createReplacement(
      original: currentRefund,
      replacement: candidateRefund,
      reason: MutationReason.correction,
    );
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
    return ChildReplacementResult(
      transactions: replacement.transactions.toList(),
      accounts: changedAccounts,
      currentTransaction: correctedRefund,
      currentGroup: currentGroup,
    );
  }

  Future<ChildReplacementResult> replaceReimbursementReceipt(
    ReplaceReimbursementReceiptTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    final currentReceipt = group.findTransaction(instruction.transactionId);
    if (currentReceipt == null ||
        currentReceipt.id == group.parentTransaction.id ||
        currentReceipt.businessPurpose !=
            BusinessPurpose.reimbursementReceipt) {
      LedgerViolationReason.reimbursementReceiptTransactionRequired
          .throwException();
    }
    if (currentReceipt.businessState != BusinessState.current) {
      LedgerViolationReason.transactionNotCurrent.throwException();
    }
    final advanceViolation = _validateReimbursementAdvance(group);
    if (advanceViolation != null) advanceViolation.throwException();
    if (group.reimbursementClosed) {
      LedgerViolationReason.reimbursementAlreadyClosed.throwException();
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
      LedgerViolationReason.reimbursementReceiptAccountsUnresolved
          .throwException();
    }
    if (amount.minorUnits > remaining.minorUnits) {
      LedgerViolationReason.reimbursementReceiptExceedsOutstanding
          .throwException();
    }

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementReceipt(
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    final candidate = _postingEngine.createReimbursementReceipt(
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
    return _replaceChildWithCandidate(
      group: group,
      currentChild: currentReceipt,
      candidateChild: candidate,
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
  }

  Future<ChildReplacementResult> replaceReimbursementClose(
    ReplaceReimbursementCloseTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    final currentClose = group.findTransaction(instruction.transactionId);
    if (currentClose == null ||
        currentClose.id == group.parentTransaction.id ||
        currentClose.businessPurpose != BusinessPurpose.reimbursementClose) {
      LedgerViolationReason.reimbursementCloseTransactionRequired
          .throwException();
    }
    if (currentClose.businessState != BusinessState.current) {
      LedgerViolationReason.transactionNotCurrent.throwException();
    }
    final advanceViolation = _validateReimbursementAdvance(group);
    if (advanceViolation != null) advanceViolation.throwException();

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
      LedgerViolationReason.reimbursementCloseAccountsUnresolved
          .throwException();
    }
    final gapIncomeAccountId =
        actualReceivedAmount.minorUnits > outstanding.minorUnits
            ? await _systemAccountResolver.resolveReimbursementGapIncome()
            : null;
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.reimbursementClose(
        receivableAccountId: receivableAccountId,
        receiveAccountId: receiveAccountId,
        receivesCash: actualReceivedAmount.minorUnits > 0,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    final candidate = _postingEngine.createReimbursementClose(
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
    return _replaceChildWithCandidate(
      group: group,
      currentChild: currentClose,
      candidateChild: candidate,
      occurredAt: instruction.occurredAt,
      counterpartyName: instruction.counterpartyName,
      note: instruction.note,
    );
  }

  Future<CancellationResult> cancelTransaction(
    CancelTransactionInstruction instruction,
  ) async {
    final group = await _rootGroupRepository.findByTransactionId(
      instruction.transactionId,
    );
    if (group == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    final target = group.findTransaction(instruction.transactionId);
    if (target == null) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    if (target.businessState != BusinessState.current) {
      LedgerViolationReason.transactionNotCurrent.throwException();
    }

    final originals =
        target.id == group.parentTransaction.id
            ? group.transactions.toList()
            : [target];
    final cancellations = <TransactionCancellation>[];
    for (final original in originals) {
      final cancellation = _postingEngine.createCancellation(
        original: original,
        reason: MutationReason.delete,
      );
      cancellations.add(cancellation);
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
    return CancellationResult(
      transactions: [
        for (final cancellation in cancellations) ...cancellation.transactions,
      ],
      accounts: changedAccounts,
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

  Future<ChildReplacementResult> _replaceChildWithCandidate({
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
      return ChildReplacementResult(
        transactions: [currentChild],
        accounts: const [],
        currentTransaction: currentChild,
        currentGroup: group,
      );
    }

    final replacement = _postingEngine.createReplacement(
      original: currentChild,
      replacement: candidateChild,
      reason: MutationReason.correction,
    );
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
    return ChildReplacementResult(
      transactions: replacement.transactions.toList(),
      accounts: changedAccounts,
      currentTransaction: correctedChild,
      currentGroup: currentGroup,
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

  LedgerViolationReason? _validateParentReplacementTarget(
    RootTransactionGroup? group,
    ReplaceParentTransactionInstruction instruction,
  ) {
    if (group == null) {
      return LedgerViolationReason.transactionNotFound;
    }
    final currentParent = group.parentTransaction;
    if (instruction.transactionId != currentParent.id) {
      return LedgerViolationReason.parentTransactionRequired;
    }
    if (currentParent.businessState != BusinessState.current) {
      return LedgerViolationReason.transactionNotCurrent;
    }
    if (currentParent.businessPurpose != instruction.expectedCurrentPurpose) {
      return LedgerViolationReason.transactionPurposeMismatch;
    }
    return null;
  }

  LedgerViolationReason? _validateReimbursementAdvance(
    RootTransactionGroup group,
  ) {
    final advance = group.parentTransaction;
    if (advance.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return LedgerViolationReason.reimbursementParentNotAdvance;
    }
    if (advance.businessState != BusinessState.current) {
      return LedgerViolationReason.reimbursementAdvanceNotCurrent;
    }
    return null;
  }

  Money? _detailAmount(Transaction transaction, TransactionDetailType type) {
    for (final detail in transaction.details) {
      if (detail.type == type) return detail.amount;
    }
    return null;
  }

  Future<LedgerViolationReason?> _validatePostingInstruction(
    PostingInstruction instruction,
  ) {
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

  Future<Transaction> _createPostingCandidate(
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
}
