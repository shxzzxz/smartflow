import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../commands/transaction_commands.dart';
import 'package:smartflow/domain/accounting/entities/account_usage.dart';
import 'package:smartflow/domain/accounting/entities/transaction.dart';
import 'package:smartflow/domain/accounting/enums/accounting_enums.dart';
import 'package:smartflow/domain/accounting/ports/account_repository.dart';
import 'package:smartflow/domain/accounting/ports/system_account_resolver.dart';
import '../queries/transaction_query_service.dart';
import 'package:smartflow/domain/accounting/ledger/ledger_rules.dart';
import 'package:smartflow/domain/accounting/ledger/post_receipt.dart';

/// 把用户意图([CreateXxxCommand])翻译成"账务真相"([PostReceipt])的组装器。
///
/// 每个业务原语一个 `buildXxx` 方法,职责清晰:
/// - 输入:对应原语的 Create command(+ correction 路径下的若干上下文参数)
/// - 输出:`Result<PostReceipt>` — 校验失败返回 [Failure],否则返回纯净蓝字凭证
///
/// builder 不知道:
/// - mutation 元数据(reversal/correction 由 [Poster] 内部注入)
/// - 调用者是 create 还是 correct 路径(只看面前的 command)
/// - 数据库事务边界(由 [PostingRepository] 实现层管理)
///
/// builder 关心:
/// - 业务规则校验(金额非负、父交易状态等)
/// - 账户角色校验(usage/type 匹配)
/// - 系统科目按需查找
/// - 凭证组装(details + entries + 必要的业务字段)
class ReceiptBuilder {
  ReceiptBuilder({
    required AccountRepository accounts,
    required TransactionQueryService query,
    required SystemAccountResolver systemAccounts,
  }) : _accounts = accounts,
       _query = query,
       _systemAccounts = systemAccounts;

  final AccountRepository _accounts;
  final TransactionQueryService _query;
  final SystemAccountResolver _systemAccounts;

  // ============================================================
  //  日常收支与转账
  // ============================================================

  /// 日常支出:expense 借 / settlement 贷。
  Future<Result<PostReceipt>> buildExpense(CreateExpenseCommand cmd) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {cmd.paidFromAccountId: AccountUsage.settlement},
      types: {
        cmd.expenseAccountId: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: cmd.occurredAt,
        primaryAmount: cmd.amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: cmd.amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.expenseAccountId,
            direction: EntryDirection.debit,
            amount: cmd.amount,
          ),
          ReceiptEntry(
            accountId: cmd.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: cmd.amount,
          ),
        ],
      ),
    );
  }

  /// 日常收入:settlement 借 / income 贷。
  Future<Result<PostReceipt>> buildIncome(CreateIncomeCommand cmd) async {
    final roleFailure = await _validateAccountConstraints(
      usages: {cmd.receiveAccountId: AccountUsage.settlement},
      types: {
        cmd.incomeAccountId: {AccountType.income},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.dailyIncome,
        occurredAt: cmd.occurredAt,
        primaryAmount: cmd.amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryIncome,
            amount: cmd.amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.receiveAccountId,
            direction: EntryDirection.debit,
            amount: cmd.amount,
          ),
          ReceiptEntry(
            accountId: cmd.incomeAccountId,
            direction: EntryDirection.credit,
            amount: cmd.amount,
          ),
        ],
      ),
    );
  }

  /// 转账(可带手续费):
  /// - to 借 amount + [feeExpense 借 fee] + from 贷 (amount + fee)
  Future<Result<PostReceipt>> buildTransfer(CreateTransferCommand cmd) async {
    final feeFailure = _validateTransferFee(cmd);
    if (feeFailure != null) return Result.failure(feeFailure);

    if (cmd.fromAccountId == cmd.toAccountId) {
      return const Result.failure(
        Failure(
          code: 'transfer_accounts_must_differ',
          message: 'Transfer source and target accounts must differ.',
        ),
      );
    }

    final fee = cmd.feeAmount;
    final hasFee = fee != null && fee.minorUnits > 0;
    final totalPaid = hasFee ? cmd.amount + fee : cmd.amount;

    final roleFailure = await _validateAccountConstraints(
      usages: {
        cmd.fromAccountId: AccountUsage.settlement,
        cmd.toAccountId: AccountUsage.settlement,
      },
      types: {
        if (hasFee) cmd.feeExpenseAccountId!: {AccountType.expense},
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: cmd.occurredAt,
        primaryAmount: cmd.amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.transferMain,
            amount: cmd.amount,
          ),
          if (hasFee)
            ReceiptDetail(
              lineNo: 2,
              type: TransactionDetailType.transferFee,
              amount: fee,
            ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.toAccountId,
            direction: EntryDirection.debit,
            amount: cmd.amount,
          ),
          if (hasFee)
            ReceiptEntry(
              accountId: cmd.feeExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: fee,
            ),
          ReceiptEntry(
            accountId: cmd.fromAccountId,
            direction: EntryDirection.credit,
            amount: totalPaid,
          ),
        ],
      ),
    );
  }

  Failure? _validateTransferFee(CreateTransferCommand cmd) {
    final fee = cmd.feeAmount;
    final feeAccountId = cmd.feeExpenseAccountId;
    if (fee == null) {
      return feeAccountId == null
          ? null
          : const Failure(
            code: 'transfer_fee_amount_required',
            message: 'Transfer fee amount is required when fee account is set.',
          );
    }
    if (fee.minorUnits < 0) {
      return const Failure(
        code: 'transfer_fee_negative',
        message: 'Transfer fee cannot be negative.',
      );
    }
    if (fee.minorUnits == 0) {
      return feeAccountId == null
          ? null
          : const Failure(
            code: 'transfer_fee_positive_required',
            message: 'Transfer fee must be positive when fee account is set.',
          );
    }
    if (feeAccountId == null) {
      return const Failure(
        code: 'transfer_fee_account_required',
        message:
            'Transfer fee account is required when fee amount is positive.',
      );
    }
    return null;
  }

  // ============================================================
  //  退款
  // ============================================================

  /// 退款:依赖 parent(daily expense 或 reimbursement advance);
  /// refundTo 借 / parent 的"被退回科目"贷。
  ///
  /// [selfPrimaryAddback] 编辑场景下传入"原退款自身金额",以便对剩余可退额做加回。
  /// create 路径传 null。
  Future<Result<PostReceipt>> buildRefund(
    CreateRefundCommand cmd, {
    Money? selfPrimaryAddback,
  }) async {
    if (cmd.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'refund_amount_not_positive',
          message: 'Refund amount must be positive.',
        ),
      );
    }
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
    final addback = selfPrimaryAddback ?? Money.zero();
    final remaining = parent.primaryAmount - refunded + addback;
    if (cmd.amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'refund_exceeds_remaining',
          message:
              'Refund exceeds remaining refundable amount '
              '(${remaining.format()}).',
        ),
      );
    }

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

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.refund,
        occurredAt: cmd.occurredAt,
        primaryAmount: cmd.amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        rootTransactionId: parent.rootTransactionId,
        parentTransactionId: parent.id,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.refundMain,
            amount: cmd.amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.refundToAccountId,
            direction: EntryDirection.debit,
            amount: cmd.amount,
          ),
          ReceiptEntry(
            accountId: creditAccountId,
            direction: EntryDirection.credit,
            amount: cmd.amount,
          ),
        ],
      ),
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

  /// 报销垫付:receivable 借 / paidFrom 贷。
  /// 把用户选的支出分类记入 `reimbursement_expense_account_id`,close 时少收差额复用。
  Future<Result<PostReceipt>> buildReimbursementAdvance(
    CreateReimbursementAdvanceCommand cmd,
  ) async {
    if (cmd.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Advance amount must be positive.',
        ),
      );
    }

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

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        occurredAt: cmd.occurredAt,
        primaryAmount: cmd.amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        reimbursementExpenseAccountId: cmd.expenseCategoryId,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.reimbursementAdvanceMain,
            amount: cmd.amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.receivableAccountId,
            direction: EntryDirection.debit,
            amount: cmd.amount,
          ),
          ReceiptEntry(
            accountId: cmd.paidFromAccountId,
            direction: EntryDirection.credit,
            amount: cmd.amount,
          ),
        ],
      ),
    );
  }

  /// 报销到账(部分到账):receive 借 / receivable 贷。
  /// [selfPrimaryAddback] 编辑场景下传入"原到账自身金额",对剩余 outstanding 做加回。
  Future<Result<PostReceipt>> buildReimbursementReceipt(
    CreateReimbursementReceiptCommand cmd, {
    Money? selfPrimaryAddback,
  }) async {
    if (cmd.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Receipt amount must be positive.',
        ),
      );
    }

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

    final addback = selfPrimaryAddback ?? Money.zero();
    final remaining = summary.outstanding + addback;
    if (cmd.amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'reimbursement_receipt_exceeds_outstanding',
          message:
              'Receipt exceeds outstanding receivable '
              '(${remaining.format()}).',
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

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: cmd.occurredAt,
        primaryAmount: cmd.amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.reimbursementReceiptMain,
            amount: cmd.amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.receiveAccountId,
            direction: EntryDirection.debit,
            amount: cmd.amount,
          ),
          ReceiptEntry(
            accountId: cmd.receivableAccountId,
            direction: EntryDirection.credit,
            amount: cmd.amount,
          ),
        ],
      ),
    );
  }

  /// 结束报销:= 剩余全额报销 + 差额收支。
  /// - 多收差额 → 系统 reimbursement_gap_income 贷
  /// - 少收差额 → advance 的原报销支出分类借
  ///
  /// [outstandingOverride] 编辑场景下从原 close-main detail 取 outstanding,
  /// 以保持口径稳定;create 路径传 null,从 advance summary 计算。
  Future<Result<PostReceipt>> buildReimbursementClose(
    CloseReimbursementCommand cmd, {
    Money? outstandingOverride,
  }) async {
    final actual = cmd.actualReceivedAmount;
    if (actual.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_close_amount_negative',
          message: 'Final receipt amount cannot be negative.',
        ),
      );
    }

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

    final gap = actual - outstanding;
    final hasOverGap = gap.minorUnits > 0;
    final hasUnderGap = gap.minorUnits < 0;

    final hasOutstanding = outstanding.minorUnits > 0;

    final details = <ReceiptDetail>[
      if (hasOutstanding)
        ReceiptDetail(
          lineNo: 1,
          type: TransactionDetailType.reimbursementCloseMain,
          amount: outstanding,
        ),
      if (hasOverGap)
        ReceiptDetail(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapIncome,
          amount: gap,
        ),
      if (hasUnderGap)
        ReceiptDetail(
          lineNo: 2,
          type: TransactionDetailType.reimbursementGapExpense,
          amount: gap.abs(),
        ),
    ];

    final entries = <ReceiptEntry>[
      if (actual.minorUnits > 0)
        ReceiptEntry(
          accountId: cmd.receiveAccountId,
          direction: EntryDirection.debit,
          amount: actual,
        ),
      if (hasOutstanding)
        ReceiptEntry(
          accountId: cmd.receivableAccountId,
          direction: EntryDirection.credit,
          amount: outstanding,
        ),
    ];

    if (hasOverGap) {
      final gapAccountId =
          await _systemAccounts.resolveReimbursementGapIncome();
      entries.add(
        ReceiptEntry(
          accountId: gapAccountId,
          direction: EntryDirection.credit,
          amount: gap,
        ),
      );
    } else if (hasUnderGap) {
      final originalExpenseId = advance!.reimbursementExpenseAccountId;
      if (originalExpenseId == null) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_close_expense_missing',
            message: 'Original reimbursement expense category is not recorded.',
          ),
        );
      }
      entries.add(
        ReceiptEntry(
          accountId: originalExpenseId,
          direction: EntryDirection.debit,
          amount: gap.abs(),
        ),
      );
    }

    final roleFailure = await _validateAccountConstraints(
      usages: {
        if (actual.minorUnits > 0)
          cmd.receiveAccountId: AccountUsage.settlement,
        cmd.receivableAccountId: AccountUsage.reimbursement,
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: cmd.occurredAt,
        primaryAmount: actual.minorUnits > 0 ? actual : outstanding,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        rootTransactionId: advance!.rootTransactionId,
        parentTransactionId: advance.id,
        reimbursementExpenseAccountId: advance.reimbursementExpenseAccountId,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
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

  /// 还款(可含利息 / 手续费 / 优惠):
  /// liability 借 + [interest 借] + [fee 借] + [discount 贷] + paidFrom 贷(=totalPaid)。
  Future<Result<PostReceipt>> buildRepayment(CreateRepaymentCommand cmd) async {
    final principal = cmd.principal;
    final interest = cmd.interest;
    final fee = cmd.fee;
    final discount = cmd.discount;

    if (principal.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_principal_not_positive',
          message: 'Repayment principal must be positive.',
        ),
      );
    }
    final hasInterest = interest != null && interest.minorUnits > 0;
    final hasFee = fee != null && fee.minorUnits > 0;
    final hasDiscount = discount != null && discount.minorUnits > 0;

    final zero = Money.zero();
    final totalPaid =
        principal +
        (hasInterest ? interest : zero) +
        (hasFee ? fee : zero) -
        (hasDiscount ? discount : zero);
    if (totalPaid.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'repayment_total_paid_not_positive',
          message: 'Repayment total paid must be positive.',
        ),
      );
    }

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

    final details = <ReceiptDetail>[
      ReceiptDetail(
        lineNo: 1,
        type: TransactionDetailType.repaymentPrincipal,
        amount: principal,
      ),
      if (hasInterest)
        ReceiptDetail(
          lineNo: 2,
          type: TransactionDetailType.repaymentInterest,
          amount: interest,
        ),
      if (hasFee)
        ReceiptDetail(
          lineNo: hasInterest ? 3 : 2,
          type: TransactionDetailType.repaymentFee,
          amount: fee,
        ),
      if (hasDiscount)
        ReceiptDetail(
          lineNo: 2 + (hasInterest ? 1 : 0) + (hasFee ? 1 : 0),
          type: TransactionDetailType.repaymentDiscount,
          amount: discount,
        ),
    ];

    final entries = <ReceiptEntry>[
      ReceiptEntry(
        accountId: cmd.liabilityAccountId,
        direction: EntryDirection.debit,
        amount: principal,
      ),
      if (hasInterest)
        ReceiptEntry(
          accountId: interestExpenseAccountId!,
          direction: EntryDirection.debit,
          amount: interest,
        ),
      if (hasFee)
        ReceiptEntry(
          accountId: feeExpenseAccountId!,
          direction: EntryDirection.debit,
          amount: fee,
        ),
      if (hasDiscount)
        ReceiptEntry(
          accountId: discountIncomeAccountId!,
          direction: EntryDirection.credit,
          amount: discount,
        ),
      ReceiptEntry(
        accountId: cmd.paidFromAccountId,
        direction: EntryDirection.credit,
        amount: totalPaid,
      ),
    ];

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: cmd.occurredAt,
        primaryAmount: totalPaid,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        ownership: cmd.ownership,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
    );
  }

  /// 借入:receive 借 / liability 贷。
  Future<Result<PostReceipt>> buildBorrowing(CreateBorrowingCommand cmd) async {
    if (cmd.amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'borrowing_amount_not_positive',
          message: 'Borrowing amount must be positive.',
        ),
      );
    }

    final roleFailure = await _validateAccountConstraints(
      usages: {
        cmd.liabilityAccountId: AccountUsage.borrowingLiability,
        cmd.receiveAccountId: AccountUsage.fund,
      },
    );
    if (roleFailure != null) return Result.failure(roleFailure);

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.borrowing,
        occurredAt: cmd.occurredAt,
        primaryAmount: cmd.amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        ownership: cmd.ownership,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.borrowingPrincipal,
            amount: cmd.amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.receiveAccountId,
            direction: EntryDirection.debit,
            amount: cmd.amount,
          ),
          ReceiptEntry(
            accountId: cmd.liabilityAccountId,
            direction: EntryDirection.credit,
            amount: cmd.amount,
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  期初 / 余额调整
  // ============================================================

  /// 期初余额:账户 ±(按账户类型 + 期初符号决定方向) / 系统期初权益 ∓。
  Future<Result<PostReceipt>> buildOpeningBalance(
    CreateOpeningBalanceCommand cmd,
  ) async {
    final account = await _accounts.findAccountById(cmd.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    if (account.archivedAt != null) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot initialize archived account.',
        ),
      );
    }
    if (cmd.amount.minorUnits == 0) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_zero',
          message: 'Opening balance amount cannot be zero.',
        ),
      );
    }

    final amount = cmd.amount.abs();
    final accountDirection = directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: cmd.amount.minorUnits,
    );
    final equityDirection =
        accountDirection == EntryDirection.debit
            ? EntryDirection.credit
            : EntryDirection.debit;

    final equityAccountId = await _systemAccounts.resolveOpeningBalance();

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.openingBalance,
        occurredAt: cmd.occurredAt,
        primaryAmount: amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.openingBalanceMain,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.accountId,
            direction: accountDirection,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: equityAccountId,
            direction: equityDirection,
            amount: amount,
          ),
        ],
      ),
    );
  }

  /// 余额调整(仅资产 / 负债):账户 ±(按差额方向)/ 系统期初权益 ∓,
  /// 金额 = 目标余额与当前余额的差额绝对值。
  Future<Result<PostReceipt>> buildBalanceAdjustment(
    AdjustBalanceCommand cmd,
  ) async {
    final account = await _accounts.findAccountById(cmd.accountId);
    if (account == null) {
      return const Result.failure(
        Failure(code: 'account_not_found', message: 'Account does not exist.'),
      );
    }
    if (account.archivedAt != null) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot adjust archived account.',
        ),
      );
    }
    if (account.type != AccountType.asset &&
        account.type != AccountType.liability) {
      return const Result.failure(
        Failure(
          code: 'account_not_adjustable',
          message:
              'Only asset and liability accounts support balance adjustment.',
        ),
      );
    }
    final deltaMinor =
        cmd.targetBalance.minorUnits - account.balance.minorUnits;
    if (deltaMinor == 0) {
      return const Result.failure(
        Failure(
          code: 'balance_adjustment_zero_delta',
          message: 'Balance is already at the target value.',
        ),
      );
    }

    final amount = Money(minorUnits: deltaMinor.abs());
    final accountDirection = directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: deltaMinor,
    );
    final equityDirection =
        accountDirection == EntryDirection.debit
            ? EntryDirection.credit
            : EntryDirection.debit;

    final equityAccountId = await _systemAccounts.resolveOpeningBalance();

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.balanceAdjustment,
        occurredAt: cmd.occurredAt,
        primaryAmount: amount,
        counterpartyName: cmd.counterpartyName,
        note: cmd.note,
        isExcludedFromStats: cmd.isExcludedFromStats,
        isExcludedFromBudget: cmd.isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.balanceAdjustmentMain,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: cmd.accountId,
            direction: accountDirection,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: equityAccountId,
            direction: equityDirection,
            amount: amount,
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  共享私有 helpers
  // ============================================================

  /// 同时校验账户类型与 usage。`types` / `usages` 任一为空则跳过对应检查。
  Future<Failure?> _validateAccountConstraints({
    Map<int, Set<AccountType>> types = const {},
    Map<int, AccountUsage> usages = const {},
  }) async {
    final typeFailure = await _validateAccountRoles(types);
    if (typeFailure != null) return typeFailure;
    return _validateAccountUsages(usages);
  }

  Future<Failure?> _validateAccountRoles(
    Map<int, Set<AccountType>> expectedTypesByAccountId,
  ) async {
    if (expectedTypesByAccountId.isEmpty) return null;
    final accounts = await _accounts.findAccountsByIds(
      expectedTypesByAccountId.keys.toSet(),
    );
    final accountsById = {for (final a in accounts) a.id: a};
    for (final MapEntry(key: accountId, value: expectedTypes)
        in expectedTypesByAccountId.entries) {
      final account = accountsById[accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account $accountId does not exist.',
        );
      }
      if (account.archivedAt != null) {
        return Failure(
          code: 'account_archived',
          message: 'Account $accountId is archived.',
        );
      }
      if (!expectedTypes.contains(account.type)) {
        return Failure(
          code: 'account_role_invalid',
          message: 'Account $accountId cannot be used for this transaction.',
        );
      }
    }
    return null;
  }

  Future<Failure?> _validateAccountUsages(
    Map<int, AccountUsage> expectedUsageByAccountId,
  ) async {
    if (expectedUsageByAccountId.isEmpty) return null;
    final accounts = await _accounts.findAccountsByIds(
      expectedUsageByAccountId.keys.toSet(),
    );
    final accountsById = {for (final a in accounts) a.id: a};
    for (final MapEntry(key: accountId, value: usage)
        in expectedUsageByAccountId.entries) {
      final account = accountsById[accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account $accountId does not exist.',
        );
      }
      if (!accountMatchesUsage(account, usage)) {
        return Failure(
          code:
              account.archivedAt == null
                  ? 'account_role_invalid'
                  : 'account_archived',
          message: 'Account $accountId cannot be used for this transaction.',
        );
      }
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
