import '../../entity/account.dart';
import '../../entity/transaction.dart';
import 'package:smartflow/core/money/money.dart';
import '../../port/account_repository.dart';
import '../../port/system_account_resolver.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import '../../valobj/posting_result.dart';
import '../account/account_role_policy.dart';
import 'account_posting_service.dart';
import 'posting_engine.dart';
import 'posting_application_service.dart';

class LedgerPostingService {
  const LedgerPostingService({
    required AccountRepository accountRepository,
    required SystemAccountResolver systemAccountResolver,
    required PostingEngine postingEngine,
    required AccountPostingService accountPostingService,
    required AccountRolePolicy accountRolePolicy,
    PostingApplicationService? postingApplicationService,
  }) : _accountRepository = accountRepository,
       _systemAccountResolver = systemAccountResolver,
       _postingEngine = postingEngine,
       _accountRolePolicy = accountRolePolicy,
       _accountPostingService = accountPostingService,
       _postingApplicationService = postingApplicationService;

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

  Future<PostingResult> postExpense(ExpenseInstruction instruction) async {
    return _postingApplication.apply(await createCandidate(instruction));
  }

  Future<PostingResult> postIncome(IncomeInstruction instruction) async {
    return _postingApplication.apply(await createCandidate(instruction));
  }

  Future<PostingResult> postTransfer(TransferInstruction instruction) async {
    return _postingApplication.apply(await createCandidate(instruction));
  }

  Future<PostingResult> postRepayment(RepaymentInstruction instruction) async {
    return _postingApplication.apply(await createCandidate(instruction));
  }

  Future<PostingResult> postBorrowing(BorrowingInstruction instruction) async {
    return _postingApplication.apply(await createCandidate(instruction));
  }

  Future<PostingResult> postLending(LendingInstruction instruction) async =>
      _postingApplication.apply(await createCandidate(instruction));

  Future<PostingResult> postReceivableCollection(
    ReceivableCollectionInstruction instruction,
  ) async => _postingApplication.apply(await createCandidate(instruction));

  Future<PostingResult> postBadDebt(BadDebtInstruction instruction) async =>
      _postingApplication.apply(await createCandidate(instruction));

  Future<PostingResult> postDebtRelief(
    DebtReliefInstruction instruction,
  ) async => _postingApplication.apply(await createCandidate(instruction));

  Future<Transaction> createCandidate(
    PostingInstruction instruction, {
    Map<String, Money> reducibleBalanceOverrides = const {},
  }) async {
    final roleViolation = await _accountRolePolicy.validate(
      switch (instruction) {
        ExpenseInstruction i => AccountRoleContext.expense(
          paidFromAccountIds: i.settlementAllocations.map(
            (allocation) => allocation.accountId,
          ),
          expenseAccountIds: i.categoryAllocations.map(
            (allocation) => allocation.accountId,
          ),
        ),
        IncomeInstruction i => AccountRoleContext.income(
          receiveAccountId: i.receiveAccountId,
          incomeAccountId: i.incomeAccountId,
        ),
        ReimbursementAdvanceInstruction i =>
          AccountRoleContext.reimbursementAdvance(
            receivableAccountId: i.receivableAccountId,
            paidFromAccountIds: i.settlementAllocations.map(
              (allocation) => allocation.accountId,
            ),
            expenseCategoryIds: i.categoryAllocations.map(
              (allocation) => allocation.accountId,
            ),
          ),
        TransferInstruction i => AccountRoleContext.transfer(
          fromAccountId: i.fromAccountId,
          toAccountId: i.toAccountId,
        ),
        RepaymentInstruction i => AccountRoleContext.repayment(
          liabilityAccountId: i.liabilityAccountId,
          paidFromAccountId: i.paidFromAccountId,
        ),
        BorrowingInstruction i => AccountRoleContext.borrowing(
          liabilityAccountId: i.liabilityAccountId,
          receiveAccountId: i.receiveAccountId,
        ),
        LendingInstruction i => AccountRoleContext.lending(
          receivableAccountId: i.receivableAccountId,
          paidFromAccountId: i.paidFromAccountId,
        ),
        ReceivableCollectionInstruction i =>
          AccountRoleContext.receivableCollection(
            receivableAccountId: i.receivableAccountId,
            receiveAccountId: i.receiveAccountId,
          ),
        BadDebtInstruction i => AccountRoleContext.badDebt(
          receivableAccountId: i.receivableAccountId,
        ),
        DebtReliefInstruction i => AccountRoleContext.debtRelief(
          liabilityAccountId: i.liabilityAccountId,
        ),
      },
    );
    if (roleViolation != null) roleViolation.throwException();

    if (instruction is BadDebtInstruction) {
      await _assertReducible(
        accountId: instruction.receivableAccountId,
        amount: instruction.amount,
        overrides: reducibleBalanceOverrides,
        violation: LedgerViolationReason.badDebtExceedsBalance,
      );
    }
    if (instruction is DebtReliefInstruction) {
      await _assertReducible(
        accountId: instruction.liabilityAccountId,
        amount: instruction.amount,
        overrides: reducibleBalanceOverrides,
        violation: LedgerViolationReason.debtReliefExceedsBalance,
      );
    }

    return _postingEngine.create(
      instruction,
      systemAccountIds: await _systemAccountResolver.resolveAll(
        _systemKeysFor(instruction),
      ),
    );
  }

  /// 指令携带的可选金额决定需要哪些规则账户;分项尚未构造,因此按指令判定。
  Set<SystemKey> _systemKeysFor(PostingInstruction instruction) {
    return switch (instruction) {
      TransferInstruction i => {
        if (_isPositive(i.feeAmount)) SystemKey.feeExpense,
      },
      RepaymentInstruction i => {
        if (_isPositive(i.interest)) SystemKey.interestExpense,
        if (_isPositive(i.fee)) SystemKey.feeExpense,
        if (_isPositive(i.discount)) SystemKey.discountIncome,
      },
      ReceivableCollectionInstruction i => {
        if (_isPositive(i.interest)) SystemKey.interestIncome,
      },
      BadDebtInstruction() => {SystemKey.badDebtExpense},
      DebtReliefInstruction() => {SystemKey.debtReliefIncome},
      _ => const {},
    };
  }

  bool _isPositive(Money? amount) => amount != null && amount.minorUnits > 0;

  Future<void> _assertReducible({
    required String accountId,
    required Money amount,
    required Map<String, Money> overrides,
    required LedgerViolationReason violation,
  }) async {
    final account = await _accountRepository.findById(accountId);
    if (account == null) {
      LedgerViolationReason.accountNotFound.throwException();
    }
    final reducible = overrides[account.id] ?? account.balance;
    if (reducible.minorUnits <= 0 || amount.minorUnits > reducible.minorUnits) {
      violation.throwException();
    }
  }

  Future<PostingResult> postOpeningBalance(
    OpeningBalanceInstruction instruction,
  ) async {
    final account = await _accountRepository.findById(instruction.accountId);
    if (account == null) {
      LedgerViolationReason.accountNotFound.throwException();
    }
    return postOpeningBalanceForAccount(
      account: account,
      instruction: instruction,
    );
  }

  Future<PostingResult> postOpeningBalanceForAccount({
    required Account account,
    required OpeningBalanceInstruction instruction,
  }) async {
    if (!account.supportsManualBalance) {
      LedgerViolationReason.openingBalanceNotSupported.throwException(
        message: 'This account type does not support opening balance.',
      );
    }
    final equityAccountId = await _systemAccountResolver
        .resolveOpeningBalance();
    return _postingApplication.apply(
      _postingEngine.createOpeningBalance(
        instruction: instruction,
        account: account,
        equityAccountId: equityAccountId,
      ),
      loadedAccounts: [account],
    );
  }

  Future<PostingResult> postBalanceAdjustment(
    BalanceAdjustmentInstruction instruction,
  ) async {
    final account = await _accountRepository.findById(instruction.accountId);
    if (account == null) {
      LedgerViolationReason.accountNotFound.throwException();
    }
    return postBalanceAdjustmentForAccount(
      account: account,
      instruction: instruction,
    );
  }

  Future<PostingResult> postBalanceAdjustmentForAccount({
    required Account account,
    required BalanceAdjustmentInstruction instruction,
  }) async {
    final adjustmentViolation = account.checkBalanceAdjustmentTarget(
      instruction.targetBalance,
    );
    if (adjustmentViolation != null) adjustmentViolation.throwException();
    final signedDelta = account.balanceDeltaTo(instruction.targetBalance);
    final equityAccountId = await _systemAccountResolver
        .resolveOpeningBalance();
    return _postingApplication.apply(
      _postingEngine.createBalanceAdjustment(
        instruction: instruction,
        account: account,
        signedDelta: signedDelta,
        equityAccountId: equityAccountId,
      ),
      loadedAccounts: [account],
    );
  }
}
