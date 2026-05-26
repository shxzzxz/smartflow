import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entity/account.dart';
import '../entity/transaction.dart';
import '../valobj/transaction_ownership.dart';
import '../valobj/ledger_enum.dart';
import '../ledger/ledger_rule.dart';
import '../ledger/post_receipt.dart';

/// 把已加载好的领域事实 + 用户指令的领域字段组装为 [PostReceipt]。
///
/// 11 个 `assemble*` 纯函数,无 I/O、无 port 调用、无事务边界,
/// caller(application 层 ReceiptBuilder)负责:
/// - 通过 query / ports 加载父交易、advance summary、refundedTotal、
///   Account 实体、系统科目 id 等事实
/// - 用 [AccountCapabilityPolicy] 校验账户类型 / usage
/// - 把 Command DTO 字段展开传给 assembler
///
/// assembler 自身关心:
/// - 每种业务原语的 details / entries 借贷布局
/// - 业务原语自身的金额签名 / 关键不变量(amount > 0、principal > 0、
///   refund <= remaining、reimbursement receipt <= outstanding、
///   gap 拆分等)
/// - PostReceipt 的 parent / root / reimbursementExpenseAccountId 等
///   业务字段从已加载父交易派生
class ReceiptAssembler {
  const ReceiptAssembler();

  // ============================================================
  //  日常收支与转账
  // ============================================================

  /// 日常支出:expense 借 / settlement 贷。
  Result<PostReceipt> assembleExpense({
    required Money amount,
    required int paidFromAccountId,
    required int expenseAccountId,
    required DateTime occurredAt,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: expenseAccountId,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: paidFromAccountId,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  /// 日常收入:settlement 借 / income 贷。
  Result<PostReceipt> assembleIncome({
    required Money amount,
    required int receiveAccountId,
    required int incomeAccountId,
    required DateTime occurredAt,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.dailyIncome,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryIncome,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: receiveAccountId,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: incomeAccountId,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  /// 转账(可带手续费):
  /// - to 借 amount + [feeExpense 借 fee] + from 贷 (amount + fee)
  Result<PostReceipt> assembleTransfer({
    required Money amount,
    required int fromAccountId,
    required int toAccountId,
    required DateTime occurredAt,
    Money? feeAmount,
    int? feeExpenseAccountId,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    final feeFailure = _validateTransferFee(feeAmount, feeExpenseAccountId);
    if (feeFailure != null) return Result.failure(feeFailure);
    if (fromAccountId == toAccountId) {
      return const Result.failure(
        Failure(
          code: 'transfer_accounts_must_differ',
          message: 'Transfer source and target account must differ.',
        ),
      );
    }

    final fee = feeAmount;
    final hasFee = fee != null && fee.minorUnits > 0;
    final totalPaid = hasFee ? amount + fee : amount;

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.transferMain,
            amount: amount,
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
            accountId: toAccountId,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          if (hasFee)
            ReceiptEntry(
              accountId: feeExpenseAccountId!,
              direction: EntryDirection.debit,
              amount: fee,
            ),
          ReceiptEntry(
            accountId: fromAccountId,
            direction: EntryDirection.credit,
            amount: totalPaid,
          ),
        ],
      ),
    );
  }

  Failure? _validateTransferFee(Money? fee, int? feeAccountId) {
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
  /// caller 须预先:
  /// - 加载 [parent] 与 [refundedSoFar](`getRefundedTotal(rootId)`)
  /// - 解析 [creditAccountId](parent entries 中 dailyExpense.debit 的 expense
  ///   或 reimbursementAdvance.debit 的 receivable)
  /// - 校验 parent 的 businessPurpose / businessState / 报销链未 closed
  ///
  /// [selfPrimaryAddback] 编辑场景下传入"原退款自身金额",对剩余可退额加回。
  Result<PostReceipt> assembleRefund({
    required Money amount,
    required int refundToAccountId,
    required Transaction parent,
    required Money refundedSoFar,
    required int creditAccountId,
    required DateTime occurredAt,
    Money? selfPrimaryAddback,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    if (amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'refund_amount_not_positive',
          message: 'Refund amount must be positive.',
        ),
      );
    }
    final addback = selfPrimaryAddback ?? Money.zero();
    final remaining = parent.primaryAmount - refundedSoFar + addback;
    if (amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'refund_exceeds_remaining',
          message:
              'Refund exceeds remaining refundable amount '
              '(${remaining.format()}).',
        ),
      );
    }
    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.refund,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        rootTransactionId: parent.rootTransactionId,
        parentTransactionId: parent.id,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.refundMain,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: refundToAccountId,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: creditAccountId,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  报销:垫付 / 到账 / 结束
  // ============================================================

  /// 报销垫付:receivable 借 / paidFrom 贷。
  /// 把用户选的支出分类记入 `reimbursement_expense_account_id`,close 时少收差额复用。
  Result<PostReceipt> assembleReimbursementAdvance({
    required Money amount,
    required int receivableAccountId,
    required int paidFromAccountId,
    required int expenseCategoryId,
    required DateTime occurredAt,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    if (amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Advance amount must be positive.',
        ),
      );
    }
    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        reimbursementExpenseAccountId: expenseCategoryId,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.reimbursementAdvanceMain,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: receivableAccountId,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: paidFromAccountId,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  /// 报销到账(部分到账):receive 借 / receivable 贷。
  ///
  /// caller 须预先校验 advance 状态、加载 [outstanding](summary.outstanding)。
  /// [selfPrimaryAddback] 编辑场景下传入"原到账自身金额",对剩余 outstanding 加回。
  Result<PostReceipt> assembleReimbursementReceipt({
    required Money amount,
    required Transaction advance,
    required Money outstanding,
    required int receivableAccountId,
    required int receiveAccountId,
    required DateTime occurredAt,
    Money? selfPrimaryAddback,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    if (amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_amount_not_positive',
          message: 'Receipt amount must be positive.',
        ),
      );
    }
    final addback = selfPrimaryAddback ?? Money.zero();
    final remaining = outstanding + addback;
    if (amount.minorUnits > remaining.minorUnits) {
      return Result.failure(
        Failure(
          code: 'reimbursement_receipt_exceeds_outstanding',
          message:
              'Receipt exceeds outstanding receivable '
              '(${remaining.format()}).',
        ),
      );
    }
    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.reimbursementReceiptMain,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: receiveAccountId,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: receivableAccountId,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  /// 结束报销:= 剩余全额报销 + 差额收支。
  /// - 多收差额 → 系统 reimbursement_gap_income 贷
  /// - 少收差额 → advance 的原报销支出分类借
  ///
  /// caller 须预先:
  /// - 加载 [advance]、决定 [outstanding](create 路径取 summary,correct 路径
  ///   从原 close-main detail 取)
  /// - 加载系统 gapIncomeAccountId(多收差额场景才需要,可空)
  Result<PostReceipt> assembleReimbursementClose({
    required Money actualReceivedAmount,
    required Transaction advance,
    required Money outstanding,
    required int receivableAccountId,
    required int receiveAccountId,
    required DateTime occurredAt,
    int? gapIncomeAccountId,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    final actual = actualReceivedAmount;
    if (actual.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'reimbursement_close_amount_negative',
          message: 'Final receipt amount cannot be negative.',
        ),
      );
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
          accountId: receiveAccountId,
          direction: EntryDirection.debit,
          amount: actual,
        ),
      if (hasOutstanding)
        ReceiptEntry(
          accountId: receivableAccountId,
          direction: EntryDirection.credit,
          amount: outstanding,
        ),
    ];

    if (hasOverGap) {
      if (gapIncomeAccountId == null) {
        return const Result.failure(
          Failure(
            code: 'reimbursement_close_gap_income_missing',
            message: 'Gap income system account is required for over-receipt.',
          ),
        );
      }
      entries.add(
        ReceiptEntry(
          accountId: gapIncomeAccountId,
          direction: EntryDirection.credit,
          amount: gap,
        ),
      );
    } else if (hasUnderGap) {
      final originalExpenseId = advance.reimbursementExpenseAccountId;
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

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: occurredAt,
        primaryAmount: actual.minorUnits > 0 ? actual : outstanding,
        counterpartyName: counterpartyName,
        note: note,
        rootTransactionId: advance.rootTransactionId,
        parentTransactionId: advance.id,
        reimbursementExpenseAccountId: advance.reimbursementExpenseAccountId,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
    );
  }

  // ============================================================
  //  借贷:还款 / 借入
  // ============================================================

  /// 还款(可含利息 / 手续费 / 优惠):
  /// liability 借 + [interest 借] + [fee 借] + [discount 贷] + paidFrom 贷(=totalPaid)。
  ///
  /// caller 须预先按需加载 [interestExpenseAccountId] / [feeExpenseAccountId]
  /// / [discountIncomeAccountId] 三个系统科目 id(对应金额非零才需要)。
  Result<PostReceipt> assembleRepayment({
    required Money principal,
    required int liabilityAccountId,
    required int paidFromAccountId,
    required DateTime occurredAt,
    Money? interest,
    Money? fee,
    Money? discount,
    int? interestExpenseAccountId,
    int? feeExpenseAccountId,
    int? discountIncomeAccountId,
    TransactionOwnership? ownership,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
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
    if (hasInterest && interestExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_interest_account_missing',
          message: 'Interest expense system account is required.',
        ),
      );
    }
    if (hasFee && feeExpenseAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_fee_account_missing',
          message: 'Fee expense system account is required.',
        ),
      );
    }
    if (hasDiscount && discountIncomeAccountId == null) {
      return const Result.failure(
        Failure(
          code: 'repayment_discount_account_missing',
          message: 'Discount income system account is required.',
        ),
      );
    }

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
        accountId: liabilityAccountId,
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
        accountId: paidFromAccountId,
        direction: EntryDirection.credit,
        amount: totalPaid,
      ),
    ];

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: occurredAt,
        primaryAmount: totalPaid,
        counterpartyName: counterpartyName,
        note: note,
        ownership: ownership,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: details,
        entries: entries,
      ),
    );
  }

  /// 借入:receive 借 / liability 贷。
  Result<PostReceipt> assembleBorrowing({
    required Money amount,
    required int liabilityAccountId,
    required int receiveAccountId,
    required DateTime occurredAt,
    TransactionOwnership? ownership,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    if (amount.minorUnits <= 0) {
      return const Result.failure(
        Failure(
          code: 'borrowing_amount_not_positive',
          message: 'Borrowing amount must be positive.',
        ),
      );
    }
    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.borrowing,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        ownership: ownership,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.borrowingPrincipal,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: receiveAccountId,
            direction: EntryDirection.debit,
            amount: amount,
          ),
          ReceiptEntry(
            accountId: liabilityAccountId,
            direction: EntryDirection.credit,
            amount: amount,
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  期初 / 余额调整
  // ============================================================

  /// 期初余额:账户 ±(按账户类型 + 期初符号决定方向) / 系统期初权益 ∓。
  ///
  /// caller 须预先:加载 [account]、解析 [equityAccountId](系统期初权益)。
  /// 已归档账户应在 caller 层拒绝;但 assembler 仍兜底检查。
  Result<PostReceipt> assembleOpeningBalance({
    required Account account,
    required Money signedAmount,
    required int equityAccountId,
    required DateTime occurredAt,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
    if (account.archivedAt != null) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot initialize archived account.',
        ),
      );
    }
    if (signedAmount.minorUnits == 0) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_zero',
          message: 'Opening balance amount cannot be zero.',
        ),
      );
    }

    final amount = signedAmount.abs();
    final accountDirection = directionForBalanceDelta(
      accountType: account.type,
      deltaMinor: signedAmount.minorUnits,
    );
    final equityDirection =
        accountDirection == EntryDirection.debit
            ? EntryDirection.credit
            : EntryDirection.debit;

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.openingBalance,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.openingBalanceMain,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: account.id,
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
  Result<PostReceipt> assembleBalanceAdjustment({
    required Account account,
    required Money targetBalance,
    required int equityAccountId,
    required DateTime occurredAt,
    String? counterpartyName,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
  }) {
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
              'Only asset and liability account support balance adjustment.',
        ),
      );
    }
    final deltaMinor = targetBalance.minorUnits - account.balance.minorUnits;
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

    return Result.success(
      PostReceipt(
        businessPurpose: BusinessPurpose.balanceAdjustment,
        occurredAt: occurredAt,
        primaryAmount: amount,
        counterpartyName: counterpartyName,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        details: [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.balanceAdjustmentMain,
            amount: amount,
          ),
        ],
        entries: [
          ReceiptEntry(
            accountId: account.id,
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
}
