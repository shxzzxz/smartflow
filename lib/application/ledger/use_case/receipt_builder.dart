import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../command/transaction_command.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/account_usage.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/valobj/post_receipt.dart';
import 'package:smartflow/domain/ledger/service/account_capability_policy.dart';
import 'package:smartflow/domain/ledger/service/receipt_assembler.dart';
import '../query/transaction_query_service.dart';

/// 把用户意图([CreateXxxCommand])翻译成"账务真相"([PostReceipt])的应用层编排器。
///
/// 每个 `buildXxx`:
/// 1. 通过 [AccountCapabilityPolicy] 校验账户类型 / usage(批量加载一次)
/// 2. 通过 ports / query 加载领域事实(父交易、refundedTotal、advance summary、
///    Account 实体、系统科目 id 等)
/// 3. 调 [ReceiptAssembler] 组装 [PostReceipt]
///
/// 凭证组装规则与基本不变量(借贷布局、金额签名、gap 拆分、parent/root 设定)
/// 在 [ReceiptAssembler] 内表达,builder 不重复;mutation 元数据由 [Poster]
/// 注入,builder 永远只交付"独立合法"的蓝字凭证。
class ReceiptBuilder {
  ReceiptBuilder({
    required AccountRepository accounts,
    required TransactionQueryService query,
    required SystemAccountResolver systemAccounts,
    AccountCapabilityPolicy capabilityPolicy = const AccountCapabilityPolicy(),
    ReceiptAssembler assembler = const ReceiptAssembler(),
  }) : _accounts = accounts,
       _query = query,
       _systemAccounts = systemAccounts,
       _capabilityPolicy = capabilityPolicy,
       _assembler = assembler;

  final AccountRepository _accounts;
  final TransactionQueryService _query;
  final SystemAccountResolver _systemAccounts;
  final AccountCapabilityPolicy _capabilityPolicy;
  final ReceiptAssembler _assembler;

  // ============================================================
  //  日常收支与转账
  // ============================================================

  Future<Result<PostReceipt>> buildExpense(CreateExpenseCommand cmd) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {cmd.paidFromAccountId: AccountUsage.settlement},
      types: {
        cmd.expenseAccountId: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleExpense(
      amount: cmd.amount,
      paidFromAccountId: cmd.paidFromAccountId,
      expenseAccountId: cmd.expenseAccountId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> buildIncome(CreateIncomeCommand cmd) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {cmd.receiveAccountId: AccountUsage.settlement},
      types: {
        cmd.incomeAccountId: {AccountType.income},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleIncome(
      amount: cmd.amount,
      receiveAccountId: cmd.receiveAccountId,
      incomeAccountId: cmd.incomeAccountId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> buildTransfer(CreateTransferCommand cmd) async {
    final fee = cmd.feeAmount;
    final feeAccountId = cmd.feeExpenseAccountId;
    final hasFeeAccount =
        fee != null && fee.minorUnits > 0 && feeAccountId != null;
    final roleFailure = await _validateAccountConstraints(
      usages: {
        cmd.fromAccountId: AccountUsage.settlement,
        cmd.toAccountId: AccountUsage.settlement,
      },
      types: {
        if (hasFeeAccount) feeAccountId: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleTransfer(
      amount: cmd.amount,
      fromAccountId: cmd.fromAccountId,
      toAccountId: cmd.toAccountId,
      occurredAt: cmd.occurredAt,
      feeAmount: cmd.feeAmount,
      feeExpenseAccountId: cmd.feeExpenseAccountId,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  // ============================================================
  //  退款
  // ============================================================

  Future<Result<PostReceipt>> buildRefund(
    CreateRefundCommand cmd, {
    Money? selfPrimaryAddback,
  }) async {
    final parent = await _query.findTransactionById(cmd.parentTransactionId);
    if (parent == null) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_found',
          message: 'Original expense not found.',
        ),
      );
    }
    if (parent.businessPurpose != BusinessPurpose.dailyExpense &&
        parent.businessPurpose != BusinessPurpose.reimbursementAdvance) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_expense',
          message: 'Refund can only be applied to an expense transaction.',
        ),
      );
    }
    if (parent.businessPurpose == BusinessPurpose.reimbursementAdvance) {
      final summary = await _query.getReimbursementSummary(
        parent.rootTransactionId,
      );
      if (summary?.isClosed ?? false) {
        return const Result.failure(
          Failure(
            code: 'refund_parent_reimbursement_closed',
            message: 'Refund is not supported after reimbursement is closed.',
          ),
        );
      }
    }
    if (parent.businessState != BusinessState.current) {
      return const Result.failure(
        Failure(
          code: 'refund_parent_not_current',
          message: 'Refund can only be applied to a current expense.',
        ),
      );
    }
    final refunded = await _query.getRefundedTotal(parent.rootTransactionId);
    final creditAccountId = await _resolveRefundCreditAccount(
      parentId: parent.id,
      parentPurpose: parent.businessPurpose,
    );
    if (creditAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'refund_expense_account_not_found',
          message: 'Original refund target account cannot be located.',
        ),
      );
    }

    final roleFailure = await _validateAccountConstraints(
      usages: {cmd.refundToAccountId: AccountUsage.settlement},
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleRefund(
      amount: cmd.amount,
      refundToAccountId: cmd.refundToAccountId,
      parent: parent,
      refundedSoFar: refunded,
      creditAccountId: creditAccountId,
      occurredAt: cmd.occurredAt,
      selfPrimaryAddback: selfPrimaryAddback,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<int?> _resolveRefundCreditAccount({
    required int parentId,
    required BusinessPurpose parentPurpose,
  }) async {
    final detail = await _query.findTransactionDetail(parentId);
    if (detail == null) return null;
    final accountTypes = await _loadAccountTypes(
      detail.entries.map((e) => e.accountId),
    );
    for (final entry in detail.entries) {
      final accountType = accountTypes[entry.accountId];
      final isDailyExpenseTarget =
          parentPurpose == BusinessPurpose.dailyExpense &&
          accountType == AccountType.expense &&
          entry.direction == EntryDirection.debit;
      final isAdvanceTarget =
          parentPurpose == BusinessPurpose.reimbursementAdvance &&
          accountType == AccountType.asset &&
          entry.direction == EntryDirection.debit;
      if (isDailyExpenseTarget || isAdvanceTarget) {
        return entry.accountId;
      }
    }
    return null;
  }

  // ============================================================
  //  报销:垫付 / 到账 / 结束
  // ============================================================

  Future<Result<PostReceipt>> buildReimbursementAdvance(
    CreateReimbursementAdvanceCommand cmd,
  ) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {
        cmd.receivableAccountId: AccountUsage.reimbursement,
        cmd.paidFromAccountId: AccountUsage.settlement,
      },
      types: {
        cmd.expenseCategoryId: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleReimbursementAdvance(
      amount: cmd.amount,
      receivableAccountId: cmd.receivableAccountId,
      paidFromAccountId: cmd.paidFromAccountId,
      expenseCategoryId: cmd.expenseCategoryId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> buildReimbursementReceipt(
    CreateReimbursementReceiptCommand cmd, {
    Money? selfPrimaryAddback,
  }) async {
    final advance = await _query.findTransactionById(cmd.advanceTransactionId);
    final advanceFailure = _validateAdvance(advance);
    if (advanceFailure != null) return Result.failure(advanceFailure);

    final summary = await _query.getReimbursementSummary(advance!.id);
    if (summary == null) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_summary_unavailable',
          message: 'Cannot resolve reimbursement state.',
        ),
      );
    }
    if (summary.isClosed) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_already_closed',
          message: 'This reimbursement chain is already closed.',
        ),
      );
    }

    final roleFailure = await _validateAccountConstraints(
      usages: {
        cmd.receiveAccountId: AccountUsage.settlement,
        cmd.receivableAccountId: AccountUsage.reimbursement,
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleReimbursementReceipt(
      amount: cmd.amount,
      advance: advance,
      outstanding: summary.outstanding,
      receivableAccountId: cmd.receivableAccountId,
      receiveAccountId: cmd.receiveAccountId,
      occurredAt: cmd.occurredAt,
      selfPrimaryAddback: selfPrimaryAddback,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> buildReimbursementClose(
    CloseReimbursementCommand cmd, {
    Money? outstandingOverride,
  }) async {
    final advance = await _query.findTransactionById(cmd.advanceTransactionId);
    final advanceFailure = _validateAdvance(advance);
    if (advanceFailure != null) return Result.failure(advanceFailure);

    Money outstanding;
    if (outstandingOverride != null) {
      outstanding = outstandingOverride;
    } else {
      final summary = await _query.getReimbursementSummary(advance!.id);
      if (summary == null || summary.isClosed) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_already_closed',
            message: 'This reimbursement chain is already closed.',
          ),
        );
      }
      outstanding = summary.outstanding;
    }

    final actual = cmd.actualReceivedAmount;
    final hasOverGap = (actual - outstanding).minorUnits > 0;
    final gapIncomeAccountId =
        hasOverGap
            ? await _systemAccounts.resolveReimbursementGapIncome()
            : null;

    final roleFailure = await _validateAccountConstraints(
      usages: {
        if (actual.minorUnits > 0)
          cmd.receiveAccountId: AccountUsage.settlement,
        cmd.receivableAccountId: AccountUsage.reimbursement,
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleReimbursementClose(
      actualReceivedAmount: actual,
      advance: advance!,
      outstanding: outstanding,
      receivableAccountId: cmd.receivableAccountId,
      receiveAccountId: cmd.receiveAccountId,
      occurredAt: cmd.occurredAt,
      gapIncomeAccountId: gapIncomeAccountId,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Failure? _validateAdvance(Transaction? advance) {
    if (advance == null) {
      return const Failure(
        code: 'reimbursement_advance_not_found',
        message: 'Reimbursement advance not found.',
      );
    }
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

  // ============================================================
  //  借贷:还款 / 借入
  // ============================================================

  Future<Result<PostReceipt>> buildRepayment(CreateRepaymentCommand cmd) async {
    final hasInterest = cmd.interest != null && cmd.interest!.minorUnits > 0;
    final hasFee = cmd.fee != null && cmd.fee!.minorUnits > 0;
    final hasDiscount = cmd.discount != null && cmd.discount!.minorUnits > 0;

    final interestExpenseAccountId =
        hasInterest ? await _systemAccounts.resolveDebtInterestExpense() : null;
    final feeExpenseAccountId =
        hasFee ? await _systemAccounts.resolveDebtFeeExpense() : null;
    final discountIncomeAccountId =
        hasDiscount ? await _systemAccounts.resolveDiscountIncome() : null;

    final roleFailure = await _validateAccountConstraints(
      usages: {
        cmd.liabilityAccountId: AccountUsage.repaymentTarget,
        cmd.paidFromAccountId: AccountUsage.repaymentSource,
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleRepayment(
      principal: cmd.principal,
      liabilityAccountId: cmd.liabilityAccountId,
      paidFromAccountId: cmd.paidFromAccountId,
      occurredAt: cmd.occurredAt,
      interest: cmd.interest,
      fee: cmd.fee,
      discount: cmd.discount,
      interestExpenseAccountId: interestExpenseAccountId,
      feeExpenseAccountId: feeExpenseAccountId,
      discountIncomeAccountId: discountIncomeAccountId,
      ownership: cmd.ownership,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> buildBorrowing(CreateBorrowingCommand cmd) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {
        cmd.liabilityAccountId: AccountUsage.borrowingLiability,
        cmd.receiveAccountId: AccountUsage.fund,
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return _assembler.assembleBorrowing(
      amount: cmd.amount,
      liabilityAccountId: cmd.liabilityAccountId,
      receiveAccountId: cmd.receiveAccountId,
      occurredAt: cmd.occurredAt,
      ownership: cmd.ownership,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  // ============================================================
  //  期初 / 余额调整
  // ============================================================

  Future<Result<PostReceipt>> buildOpeningBalance(
    CreateOpeningBalanceCommand cmd,
  ) async {
    final account = await _accounts.findAccountById(cmd.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    final equityAccountId = await _systemAccounts.resolveOpeningBalance();
    return _assembler.assembleOpeningBalance(
      account: account,
      signedAmount: cmd.amount,
      equityAccountId: equityAccountId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  Future<Result<PostReceipt>> buildBalanceAdjustment(
    AdjustBalanceCommand cmd,
  ) async {
    final account = await _accounts.findAccountById(cmd.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    final equityAccountId = await _systemAccounts.resolveOpeningBalance();
    return _assembler.assembleBalanceAdjustment(
      account: account,
      targetBalance: cmd.targetBalance,
      equityAccountId: equityAccountId,
      occurredAt: cmd.occurredAt,
      counterpartyName: cmd.counterpartyName,
      note: cmd.note,
      isExcludedFromStats: cmd.isExcludedFromStats,
      isExcludedFromBudget: cmd.isExcludedFromBudget,
    );
  }

  // ============================================================
  //  共享私有 helpers
  // ============================================================

  /// 批量加载账户后,逐个委托 [AccountCapabilityPolicy] 校验角色 / usage。
  /// `types` / `usages` 可分别给出;同一账户在两个 map 中出现时,两项都会校验。
  Future<Failure?> _validateAccountConstraints({
    Map<int, Set<AccountType>> types = const {},
    Map<int, AccountUsage> usages = const {},
  }) async {
    final ids = <int>{...types.keys, ...usages.keys};
    if (ids.isEmpty) return null;
    final accounts = await _accounts.findAccountsByIds(ids);
    final accountsById = <int, Account>{
      for (final account in accounts) account.id: account,
    };
    for (final entry in types.entries) {
      final failure = _capabilityPolicy.validate(
        accountsById[entry.key],
        accountId: entry.key,
        expectedTypes: entry.value,
      );
      if (failure != null) return failure;
    }
    for (final entry in usages.entries) {
      final failure = _capabilityPolicy.validate(
        accountsById[entry.key],
        accountId: entry.key,
        requiredUsage: entry.value,
      );
      if (failure != null) return failure;
    }
    return null;
  }

  Future<Map<int, AccountType>> _loadAccountTypes(
    Iterable<int> accountIds,
  ) async {
    final ids = accountIds.toSet();
    if (ids.isEmpty) return const {};
    final accounts = await _accounts.findAccountsByIds(ids);
    return {for (final a in accounts) a.id: a.type};
  }
}
