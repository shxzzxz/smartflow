import 'package:smartflow/core/money/money.dart';

import '../../entity/transaction_group.dart';
import '../../port/account_repository.dart';
import '../../port/transaction_group_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/account_amount_allocation.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import 'account_posting_service.dart';
import 'posting_engine.dart';
import 'posting_application_service.dart';

class AdvancePostingService {
  const AdvancePostingService({
    required TransactionGroupRepository transactionGroupRepository,
    required AccountRepository accountRepository,
    required SystemAccountResolver systemAccountResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
    PostingApplicationService? postingApplicationService,
  }) : _transactionGroupRepository = transactionGroupRepository,
       _systemAccountResolver = systemAccountResolver,
       _postingEngine = postingEngine,
       _accountRolePolicy = accountRolePolicy,
       _accountRepository = accountRepository,
       _accountPostingService = accountPostingService,
       _postingApplicationService = postingApplicationService;

  final TransactionGroupRepository _transactionGroupRepository;
  final AccountRepository _accountRepository;
  final SystemAccountResolver _systemAccountResolver;
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

  Future<PostingResult> postAdvance(AdvanceInstruction instruction) async {
    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.advance(
        receivableAccountId: instruction.receivableAccountId,
        paidFromAccountIds: instruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
        expenseCategoryIds: {
          for (final allocation in instruction.categoryAllocations)
            allocation.accountId,
          for (final allocation in instruction.selfBorneAllocations)
            allocation.accountId,
        },
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _postingApplication.apply(_postingEngine.createAdvance(instruction));
  }

  Future<PostingResult> postCollection(
    AdvanceCollectionInstruction instruction,
  ) async {
    final advanceTransactionId = instruction.advanceTransactionId;
    final group = advanceTransactionId == null
        ? null
        : await _loadOpenAdvance(advanceTransactionId);
    if (group != null) {
      final itemizedViolation = _validateItemizedChildTarget(
        group: group,
        receivableAccountId: instruction.receivableAccountId,
      );
      if (itemizedViolation != null) itemizedViolation.throwException();
    }
    final advance = group?.parentTransaction;
    final outstanding = group?.advanceOutstanding() ?? Money.zero();
    if (group != null &&
        instruction.amount.minorUnits > outstanding.minorUnits) {
      LedgerViolationReason.advanceCollectionExceedsOutstanding
          .throwException();
    }

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.advanceCollection(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountIds: instruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _postingApplication.apply(
      _postingEngine.createAdvanceCollection(
        instruction: instruction,
        advance: advance,
      ),
    );
  }

  Future<PostingResult> settle(AdvanceSettlementInstruction instruction) async {
    final advanceTransactionId = instruction.advanceTransactionId;
    final group = advanceTransactionId == null
        ? null
        : await _loadOpenAdvance(advanceTransactionId);
    if (group != null) {
      final itemizedViolation = _validateItemizedChildTarget(
        group: group,
        receivableAccountId: instruction.receivableAccountId,
      );
      if (itemizedViolation != null) itemizedViolation.throwException();
    }
    final advance = group?.parentTransaction;
    final outstanding = group?.advanceOutstanding() ?? Money.zero();
    final actual = instruction.actualReceivedAmount;
    final accountManaged = advanceTransactionId == null;
    final badDebtShortfall =
        !accountManaged &&
        actual.minorUnits < outstanding.minorUnits &&
        instruction.shortfallKind == AdvanceShortfallKind.badDebt;
    final gapIncomeAccountId =
        !accountManaged && actual.minorUnits > outstanding.minorUnits
        ? await _systemAccountResolver.resolveAdvanceCompensationIncome()
        : null;
    final badDebtExpenseAccountId = badDebtShortfall
        ? await _systemAccountResolver.resolveByKey(SystemKey.badDebtExpense)
        : null;
    // A self-borne shortfall category is an input fact supplied by the caller.
    // It need not come from the original advance transaction: a fully advanced
    // payment has no self-borne category to begin with.
    final gapExpenseAllocations = accountManaged || badDebtShortfall
        ? const <AccountAmountAllocation>[]
        : instruction.gapExpenseAllocations;
    final normalizedInstruction = accountManaged
        ? AdvanceSettlementInstruction.account(
            actualReceivedAmount: instruction.actualReceivedAmount,
            receivableAccountId: instruction.receivableAccountId,
            settlementAllocations: instruction.settlementAllocations,
            gapExpenseAllocations: gapExpenseAllocations,
            ownership: instruction.ownership!,
            shortfallKind: instruction.shortfallKind,
            occurredAt: instruction.occurredAt,
            postedAt: instruction.postedAt,
            counterpartyId: instruction.counterpartyId,
            note: instruction.note,
            isExcludedFromStats: instruction.isExcludedFromStats,
            isExcludedFromBudget: instruction.isExcludedFromBudget,
          )
        : AdvanceSettlementInstruction(
            advanceTransactionId: advanceTransactionId,
            actualReceivedAmount: instruction.actualReceivedAmount,
            receivableAccountId: instruction.receivableAccountId,
            settlementAllocations: instruction.settlementAllocations,
            gapExpenseAllocations: gapExpenseAllocations,
            shortfallKind: instruction.shortfallKind,
            occurredAt: instruction.occurredAt,
            postedAt: instruction.postedAt,
            counterpartyId: instruction.counterpartyId,
            note: instruction.note,
          );

    final roleViolation = await _accountRolePolicy.validate(
      AccountRoleContext.advanceSettlement(
        receivableAccountId: instruction.receivableAccountId,
        receiveAccountIds: instruction.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
        gapExpenseCategoryIds: gapExpenseAllocations.map(
          (allocation) => allocation.accountId,
        ),
        receivesCash: actual.minorUnits > 0,
      ),
    );
    if (roleViolation != null) roleViolation.throwException();

    return _postingApplication.apply(
      _postingEngine.createAdvanceSettlement(
        instruction: normalizedInstruction,
        advance: advance,
        outstanding: outstanding,
        gapIncomeAccountId: gapIncomeAccountId,
        badDebtExpenseAccountId: badDebtExpenseAccountId,
      ),
    );
  }

  Future<TransactionGroup> _loadOpenAdvance(String advanceTransactionId) async {
    final group = await _transactionGroupRepository.findByTransactionId(
      advanceTransactionId,
    );
    final advanceViolation = _validateOpenAdvance(group, advanceTransactionId);
    if (advanceViolation != null) advanceViolation.throwException();
    return group!;
  }

  LedgerViolationReason? _validateOpenAdvance(
    TransactionGroup? group,
    String advanceTransactionId,
  ) {
    if (group == null ||
        group.parentTransaction.id != advanceTransactionId ||
        group.parentTransaction.businessPurpose != BusinessPurpose.advance) {
      return LedgerViolationReason.advanceNotFound;
    }
    if (group.advanceSettled) {
      return LedgerViolationReason.advanceAlreadyClosed;
    }
    return null;
  }

  LedgerViolationReason? _validateItemizedChildTarget({
    required TransactionGroup group,
    required String receivableAccountId,
  }) {
    final advance = group.parentTransaction;
    final parentReceivableAccountId = advance.accountOf(
      TransactionRole.receivable,
    );
    if (parentReceivableAccountId == null) {
      return LedgerViolationReason.advanceInstructionUnresolvable;
    }
    if (parentReceivableAccountId != receivableAccountId) {
      return LedgerViolationReason.advanceReceivableAccountMismatch;
    }
    return null;
  }
}
