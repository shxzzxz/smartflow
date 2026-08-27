import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import '../../entity/account.dart';
import '../../entity/entry.dart';
import '../../entity/transaction.dart';
import '../../entity/transaction_line.dart';
import '../../valobj/account_amount_allocation.dart';
import '../../valobj/ledger_enum.dart';
import '../../valobj/ledger_violation_reason.dart';
import '../../valobj/posting_instruction.dart';
import 'posting_rule.dart';

/// 过账引擎,分两阶段:
///
/// 1. 指令 → 交易分项。需要组上下文(父交易、待核销额)的量由调用方算好后传入。
/// 2. (交易头 + 分项) → 分录。纯查表,只依赖分项、账户类型与已解析的系统科目。
///
/// 引擎自身不解析 `system_key`;规则账户由调用方解析后按 [SystemKey] 传入。
class PostingEngine {
  const PostingEngine({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  /// 阶段二:按过账规则把分项翻译成分录。
  ///
  /// 同一账户的多条腿在此合并净额,零额腿不产生分录——转账手续费由转出账户
  /// 承担,因此转出账户的贷方是转账金额与手续费之和。
  List<Entry> postEntries({
    required String transactionId,
    required BusinessPurpose businessPurpose,
    required Iterable<TransactionLine> lines,
    Map<SystemKey, String> systemAccountIds = const {},
    Map<String, AccountType> accountTypes = const {},
  }) {
    final legs = <({String accountId, int signedMinor})>[];
    for (final line in lines) {
      final leg = _legFor(
        businessPurpose: businessPurpose,
        line: line,
        systemAccountIds: systemAccountIds,
        accountTypes: accountTypes,
      );
      if (leg != null) legs.add(leg);
    }

    final imbalance = legs.fold(0, (sum, leg) => sum + leg.signedMinor);
    if (imbalance != 0) {
      legs.add((
        accountId: _balancingAccountId(
          businessPurpose: businessPurpose,
          lines: lines,
          systemAccountIds: systemAccountIds,
        ),
        signedMinor: -imbalance,
      ));
    }

    final netByAccount = <String, int>{};
    final accountOrder = <String>[];
    for (final leg in legs) {
      if (!netByAccount.containsKey(leg.accountId)) {
        accountOrder.add(leg.accountId);
      }
      netByAccount[leg.accountId] =
          (netByAccount[leg.accountId] ?? 0) + leg.signedMinor;
    }

    return [
      for (final accountId in accountOrder)
        if (netByAccount[accountId] != 0)
          _entry(
            transactionId: transactionId,
            accountId: accountId,
            direction: netByAccount[accountId]! > 0
                ? EntryDirection.debit
                : EntryDirection.credit,
            amount: Money(minorUnits: netByAccount[accountId]!.abs()),
          ),
    ];
  }

  Transaction create(
    PostingInstruction instruction, {
    Map<SystemKey, String> systemAccountIds = const {},
  }) {
    return switch (instruction) {
      ExpenseInstruction i => createExpense(i),
      IncomeInstruction i => createIncome(i),
      ReimbursementAdvanceInstruction i => createReimbursementAdvance(i),
      TransferInstruction i => createTransfer(
        i,
        systemAccountIds: systemAccountIds,
      ),
      RepaymentInstruction i => createRepayment(
        i,
        systemAccountIds: systemAccountIds,
      ),
      BorrowingInstruction i => createBorrowing(i),
      LendingInstruction i => createLending(i),
      ReceivableCollectionInstruction i => createReceivableCollection(
        i,
        systemAccountIds: systemAccountIds,
      ),
      BadDebtInstruction i => createBadDebt(
        i,
        systemAccountIds: systemAccountIds,
      ),
      DebtReliefInstruction i => createDebtRelief(
        i,
        systemAccountIds: systemAccountIds,
      ),
    };
  }

  Transaction createExpense(ExpenseInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.expenseAmountNotPositive.throwException(
        message: 'Expense amount must be positive.',
      );
    }
    _validateAllocations(
      total: instruction.amount,
      allocations: instruction.categoryAllocations,
    );
    _validateAllocations(
      total: instruction.amount,
      allocations: instruction.settlementAllocations,
    );
    final transactionId = _idGenerator.newId();
    var lineNo = 1;
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: instruction.isExcludedFromBudget,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        lines: [
          for (final allocation in instruction.categoryAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.category,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
          for (final allocation in instruction.settlementAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.settlementOut,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
        ],
      ),
    );
  }

  Transaction createIncome(IncomeInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.incomeAmountNotPositive.throwException(
        message: 'Income amount must be positive.',
      );
    }
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.dailyIncome,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: instruction.isExcludedFromBudget,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.category,
            accountId: instruction.incomeAccountId,
            amount: instruction.amount,
          ),
          _line(
            transactionId: transactionId,
            lineNo: 2,
            role: TransactionRole.settlementIn,
            accountId: instruction.receiveAccountId,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createReimbursementAdvance(
    ReimbursementAdvanceInstruction instruction,
  ) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.reimbursementAmountNotPositive
          .throwException(
            message: 'Reimbursement advance amount must be positive.',
          );
    }
    _validateAllocations(
      total: instruction.amount,
      allocations: instruction.categoryAllocations,
    );
    _validateAllocations(
      total: instruction.amount,
      allocations: instruction.settlementAllocations,
    );
    final transactionId = _idGenerator.newId();
    var lineNo = 1;
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.reimbursementAdvance,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: instruction.isExcludedFromBudget,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        lines: [
          // 支出分类在垫付时不产生分录,它在结束报销少收差额时才被使用。
          for (final allocation in instruction.categoryAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.reimbursementExpenseCategory,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
          _line(
            transactionId: transactionId,
            lineNo: lineNo++,
            role: TransactionRole.receivable,
            accountId: instruction.receivableAccountId,
            amount: instruction.amount,
          ),
          for (final allocation in instruction.settlementAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.settlementOut,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
        ],
      ),
    );
  }

  Transaction createRefund({
    required RefundInstruction instruction,
    required Transaction parent,
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.refundAmountNotPositive.throwException(
        message: 'Refund amount must be positive.',
      );
    }
    final categoryAllocations = instruction.categoryAllocations.isNotEmpty
        ? instruction.categoryAllocations
        : _singleRefundCategoryAllocation(parent, instruction.amount);
    _validateAllocations(
      total: instruction.amount,
      allocations: categoryAllocations,
    );
    _validateAllocations(
      total: instruction.amount,
      allocations: instruction.settlementAllocations,
    );
    final reimbursable =
        parent.businessPurpose == BusinessPurpose.reimbursementAdvance;
    final receivableAccountId = reimbursable
        ? parent.accountOf(TransactionRole.receivable)
        : null;
    if (reimbursable && receivableAccountId == null) {
      return LedgerViolationReason.reimbursementInstructionUnresolvable
          .throwException(message: 'Refund receivable account is missing.');
    }
    final transactionId = _idGenerator.newId();
    var lineNo = 1;
    return _posted(
      Transaction(
        id: transactionId,
        parentTransactionId: parent.id,
        businessPurpose: BusinessPurpose.refund,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: parent.isExcludedFromStats,
        isExcludedFromBudget: parent.isExcludedFromBudget,
        sourceKind: parent.sourceKind,
        ownership: parent.ownership,
        lines: [
          for (final allocation in instruction.settlementAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.settlementIn,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
          for (final allocation in categoryAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: reimbursable
                  ? TransactionRole.reimbursementExpenseCategory
                  : TransactionRole.refundOffset,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
          if (receivableAccountId != null)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.receivable,
              accountId: receivableAccountId,
              amount: instruction.amount,
            ),
        ],
      ),
    );
  }

  Transaction createTransfer(
    TransferInstruction instruction, {
    Map<SystemKey, String> systemAccountIds = const {},
  }) {
    final fee = instruction.feeAmount;
    final hasFee = fee != null && fee.minorUnits > 0;
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.transferAmountNotPositive.throwException(
        message: 'Transfer amount must be positive.',
      );
    }
    if (instruction.fromAccountId == instruction.toAccountId) {
      return LedgerViolationReason.transferAccountsMustDiffer.throwException(
        message: 'Transfer source and target account must differ.',
      );
    }
    if (fee != null && fee.minorUnits < 0) {
      return LedgerViolationReason.transferFeeNegative.throwException(
        message: 'Transfer fee cannot be negative.',
      );
    }
    if (hasFee && systemAccountIds[SystemKey.feeExpense] == null) {
      return LedgerViolationReason.transferFeeAccountRequired.throwException(
        message: 'Transfer fee account is required.',
      );
    }

    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.settlementOut,
            accountId: instruction.fromAccountId,
            amount: instruction.amount,
          ),
          _line(
            transactionId: transactionId,
            lineNo: 2,
            role: TransactionRole.settlementIn,
            accountId: instruction.toAccountId,
            amount: instruction.amount,
          ),
          if (hasFee)
            _line(
              transactionId: transactionId,
              lineNo: 3,
              role: TransactionRole.fee,
              amount: fee,
            ),
        ],
      ),
      systemAccountIds: systemAccountIds,
    );
  }

  Transaction createReimbursementReceipt({
    required ReimbursementReceiptInstruction instruction,
    required Transaction advance,
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.reimbursementAmountNotPositive
          .throwException(message: 'Receipt amount must be positive.');
    }
    _validateAllocations(
      total: instruction.amount,
      allocations: instruction.settlementAllocations,
    );
    final transactionId = _idGenerator.newId();
    var lineNo = 1;
    return _posted(
      Transaction(
        id: transactionId,
        parentTransactionId: advance.id,
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: advance.isExcludedFromStats,
        isExcludedFromBudget: advance.isExcludedFromBudget,
        sourceKind: advance.sourceKind,
        ownership: advance.ownership,
        lines: [
          for (final allocation in instruction.settlementAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.settlementIn,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
          _line(
            transactionId: transactionId,
            lineNo: lineNo++,
            role: TransactionRole.receivable,
            accountId: instruction.receivableAccountId,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createRepayment(
    RepaymentInstruction instruction, {
    Map<SystemKey, String> systemAccountIds = const {},
  }) {
    if (instruction.principal.minorUnits < 0) {
      return LedgerViolationReason.repaymentPrincipalNotPositive.throwException(
        message: 'Repayment principal cannot be negative.',
      );
    }
    final interest = instruction.interest;
    final fee = instruction.fee;
    final discount = instruction.discount;
    final hasInterest = interest != null && interest.minorUnits > 0;
    final hasFee = fee != null && fee.minorUnits > 0;
    final hasDiscount = discount != null && discount.minorUnits > 0;
    if (hasInterest && systemAccountIds[SystemKey.interestExpense] == null) {
      return LedgerViolationReason.repaymentInterestAccountMissing
          .throwException(
            message: 'Interest expense system account is required.',
          );
    }
    if (hasFee && systemAccountIds[SystemKey.feeExpense] == null) {
      return LedgerViolationReason.repaymentFeeAccountMissing.throwException(
        message: 'Fee expense system account is required.',
      );
    }
    if (hasDiscount && systemAccountIds[SystemKey.discountIncome] == null) {
      return LedgerViolationReason.repaymentDiscountAccountMissing
          .throwException(
            message: 'Discount income system account is required.',
          );
    }
    final totalPaid =
        instruction.principal +
        (hasInterest ? interest : Money.zero()) +
        (hasFee ? fee : Money.zero()) -
        (hasDiscount ? discount : Money.zero());
    if (totalPaid.minorUnits <= 0) {
      return LedgerViolationReason.repaymentTotalPaidNotPositive.throwException(
        message: 'Repayment total paid must be positive.',
      );
    }

    var lineNo = 1;
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.debtRepayment,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: totalPaid,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: lineNo++,
            role: TransactionRole.liability,
            accountId: instruction.liabilityAccountId,
            amount: instruction.principal,
          ),
          if (hasInterest)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.interest,
              amount: interest,
            ),
          if (hasFee)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.fee,
              amount: fee,
            ),
          if (hasDiscount)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.discount,
              amount: discount,
            ),
          _line(
            transactionId: transactionId,
            lineNo: lineNo++,
            role: TransactionRole.settlementOut,
            accountId: instruction.paidFromAccountId,
            amount: totalPaid,
          ),
        ],
      ),
      systemAccountIds: systemAccountIds,
    );
  }

  Transaction createBorrowing(BorrowingInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.borrowingAmountNotPositive.throwException(
        message: 'Borrowing amount must be positive.',
      );
    }
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.borrowing,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        ownership: instruction.ownership,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.liability,
            accountId: instruction.liabilityAccountId,
            amount: instruction.amount,
          ),
          _line(
            transactionId: transactionId,
            lineNo: 2,
            role: TransactionRole.settlementIn,
            accountId: instruction.receiveAccountId,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createLending(LendingInstruction instruction) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.lendingAmountNotPositive.throwException();
    }
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.lending,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.receivable,
            accountId: instruction.receivableAccountId,
            amount: instruction.amount,
          ),
          _line(
            transactionId: transactionId,
            lineNo: 2,
            role: TransactionRole.settlementOut,
            accountId: instruction.paidFromAccountId,
            amount: instruction.amount,
          ),
        ],
      ),
    );
  }

  Transaction createReceivableCollection(
    ReceivableCollectionInstruction instruction, {
    Map<SystemKey, String> systemAccountIds = const {},
  }) {
    if (instruction.principal.minorUnits <= 0 ||
        instruction.interest.minorUnits < 0) {
      return LedgerViolationReason.receivableCollectionAmountInvalid
          .throwException();
    }
    final hasInterest = instruction.interest.minorUnits > 0;
    if (hasInterest && systemAccountIds[SystemKey.interestIncome] == null) {
      return LedgerViolationReason.interestIncomeAccountMissing
          .throwException();
    }
    final total = instruction.principal + instruction.interest;
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.receivableCollection,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: total,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.receivable,
            accountId: instruction.receivableAccountId,
            amount: instruction.principal,
          ),
          if (hasInterest)
            _line(
              transactionId: transactionId,
              lineNo: 2,
              role: TransactionRole.interest,
              amount: instruction.interest,
            ),
          _line(
            transactionId: transactionId,
            lineNo: hasInterest ? 3 : 2,
            role: TransactionRole.settlementIn,
            accountId: instruction.receiveAccountId,
            amount: total,
          ),
        ],
      ),
      systemAccountIds: systemAccountIds,
    );
  }

  Transaction createBadDebt(
    BadDebtInstruction instruction, {
    Map<SystemKey, String> systemAccountIds = const {},
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.badDebtAmountNotPositive.throwException();
    }
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.badDebt,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: instruction.isExcludedFromBudget,
        sourceKind: instruction.sourceKind,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.receivable,
            accountId: instruction.receivableAccountId,
            amount: instruction.amount,
          ),
        ],
      ),
      systemAccountIds: systemAccountIds,
    );
  }

  Transaction createDebtRelief(
    DebtReliefInstruction instruction, {
    Map<SystemKey, String> systemAccountIds = const {},
  }) {
    if (instruction.amount.minorUnits <= 0) {
      return LedgerViolationReason.debtReliefAmountNotPositive.throwException();
    }
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.debtRelief,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: instruction.isExcludedFromStats,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.liability,
            accountId: instruction.liabilityAccountId,
            amount: instruction.amount,
          ),
        ],
      ),
      systemAccountIds: systemAccountIds,
    );
  }

  Transaction createOpeningBalance({
    required OpeningBalanceInstruction instruction,
    required Account account,
    required String equityAccountId,
  }) {
    if (account.archivedAt != null) {
      return LedgerViolationReason.accountArchived.throwException(
        message: 'Cannot initialize archived account.',
      );
    }
    if (instruction.amount.minorUnits == 0) {
      return LedgerViolationReason.openingBalanceZero.throwException(
        message: 'Opening balance amount cannot be zero.',
      );
    }
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.openingBalance,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        primaryAmount: instruction.amount.abs(),
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: instruction.sourceKind,
        lines: [
          // 带符号:方向由符号与账户类型共同决定,符号单独不足以判断。
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.openingBalance,
            accountId: account.id,
            amount: instruction.amount,
          ),
        ],
      ),
      systemAccountIds: {SystemKey.openingBalance: equityAccountId},
      accountTypes: {account.id: account.type},
    );
  }

  Transaction createBalanceAdjustment({
    required BalanceAdjustmentInstruction instruction,
    required Account account,
    required Money signedDelta,
    required String equityAccountId,
  }) {
    final transactionId = _idGenerator.newId();
    return _posted(
      Transaction(
        id: transactionId,
        businessPurpose: BusinessPurpose.balanceAdjustment,
        occurredAt: instruction.occurredAt,
        primaryAmount: signedDelta.abs(),
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        sourceKind: SourceKind.manual,
        lines: [
          _line(
            transactionId: transactionId,
            lineNo: 1,
            role: TransactionRole.balanceAdjustment,
            accountId: account.id,
            amount: signedDelta,
          ),
        ],
      ),
      systemAccountIds: {SystemKey.openingBalance: equityAccountId},
      accountTypes: {account.id: account.type},
    );
  }

  Transaction createReimbursementClose({
    required ReimbursementCloseInstruction instruction,
    required Transaction advance,
    required Money outstanding,
    required String? gapIncomeAccountId,
  }) {
    final actual = instruction.actualReceivedAmount;
    if (actual.minorUnits < 0) {
      return LedgerViolationReason.reimbursementCloseAmountNegative
          .throwException(message: 'Received amount cannot be negative.');
    }
    final gap = actual - outstanding;
    if (gap.minorUnits > 0 && gapIncomeAccountId == null) {
      return LedgerViolationReason.reimbursementGapIncomeRequired
          .throwException(message: 'Gap income account is required.');
    }
    _validateAllocations(
      total: actual,
      allocations: instruction.settlementAllocations,
      allowZeroTotal: true,
    );
    final gapExpenseAllocations =
        gap.minorUnits < 0 && instruction.gapExpenseAllocations.isEmpty
        ? _singleGapExpenseAllocation(advance, -gap)
        : instruction.gapExpenseAllocations;
    if (gap.minorUnits < 0) {
      _validateAllocations(total: -gap, allocations: gapExpenseAllocations);
    } else if (gapExpenseAllocations.isNotEmpty) {
      return LedgerViolationReason.allocationTotalMismatch.throwException(
        message: 'Gap expense allocations require a reimbursement shortfall.',
      );
    }

    final transactionId = _idGenerator.newId();
    var lineNo = 1;
    return _posted(
      Transaction(
        id: transactionId,
        parentTransactionId: advance.id,
        businessPurpose: BusinessPurpose.reimbursementClose,
        occurredAt: instruction.occurredAt,
        postedAt: instruction.postedAt,
        // 主金额表达结束报销的实际到账,未收到现金时就是 0。
        primaryAmount: actual,
        counterpartyName: instruction.counterpartyName,
        note: instruction.note,
        isExcludedFromStats: advance.isExcludedFromStats,
        isExcludedFromBudget: advance.isExcludedFromBudget,
        sourceKind: advance.sourceKind,
        ownership: advance.ownership,
        lines: [
          // 一分未收时金额为零,但收款账户仍是用户给出的事实,必须留痕。
          for (final allocation in instruction.settlementAllocations)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.settlementIn,
              accountId: allocation.accountId,
              amount: allocation.amount,
            ),
          if (outstanding.minorUnits > 0)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.receivable,
              accountId: instruction.receivableAccountId,
              amount: outstanding,
            ),
          if (gap.minorUnits > 0)
            _line(
              transactionId: transactionId,
              lineNo: lineNo++,
              role: TransactionRole.reimbursementGapIncome,
              amount: gap,
            ),
          if (gap.minorUnits < 0)
            for (final allocation in gapExpenseAllocations)
              _line(
                transactionId: transactionId,
                lineNo: lineNo++,
                role: TransactionRole.reimbursementGapExpense,
                accountId: allocation.accountId,
                amount: allocation.amount,
              ),
        ],
      ),
      systemAccountIds: {SystemKey.reimbursementGapIncome: ?gapIncomeAccountId},
    );
  }

  void _validateAllocations({
    required Money total,
    required List<AccountAmountAllocation> allocations,
    bool allowZeroTotal = false,
  }) {
    if (allocations.isEmpty) {
      LedgerViolationReason.allocationRequired.throwException();
    }
    final zeroTotal = total.minorUnits == 0;
    for (final allocation in allocations) {
      final valid = zeroTotal && allowZeroTotal
          ? allocation.amount.minorUnits == 0 && allocations.length == 1
          : allocation.amount.minorUnits > 0;
      if (!valid) {
        LedgerViolationReason.allocationAmountNotPositive.throwException();
      }
    }
    if (sumAllocations(allocations) != total) {
      LedgerViolationReason.allocationTotalMismatch.throwException();
    }
  }

  List<AccountAmountAllocation> _singleRefundCategoryAllocation(
    Transaction parent,
    Money amount,
  ) {
    final role = parent.businessPurpose == BusinessPurpose.reimbursementAdvance
        ? TransactionRole.reimbursementExpenseCategory
        : TransactionRole.category;
    final categories = parent.linesOf(role).toList();
    if (categories.length != 1) return const [];
    return singleAllocation(
      accountId: categories.single.accountId!,
      amount: amount,
    );
  }

  List<AccountAmountAllocation> _singleGapExpenseAllocation(
    Transaction advance,
    Money amount,
  ) {
    final categories = advance
        .linesOf(TransactionRole.reimbursementExpenseCategory)
        .toList();
    if (categories.length != 1) return const [];
    return singleAllocation(
      accountId: categories.single.accountId!,
      amount: amount,
    );
  }

  Transaction _posted(
    Transaction draft, {
    Map<SystemKey, String> systemAccountIds = const {},
    Map<String, AccountType> accountTypes = const {},
  }) {
    final transaction = draft.copyWith(
      entries: postEntries(
        transactionId: draft.id,
        businessPurpose: draft.businessPurpose,
        lines: draft.lines,
        systemAccountIds: systemAccountIds,
        accountTypes: accountTypes,
      ),
    );
    transaction.validateSelf();
    return transaction;
  }

  ({String accountId, int signedMinor})? _legFor({
    required BusinessPurpose businessPurpose,
    required TransactionLine line,
    required Map<SystemKey, String> systemAccountIds,
    required Map<String, AccountType> accountTypes,
  }) {
    if (line.amount.minorUnits == 0) return null;

    final accountId = roleCarriesAccount(line.role)
        ? line.accountId
        : systemAccountIds[systemKeyForRole(
            businessPurpose: businessPurpose,
            role: line.role,
          )];
    if (accountId == null) {
      return LedgerViolationReason.postingSystemAccountMissing.throwException(
        message: 'No account resolved for role ${line.role.name}.',
      );
    }

    if (roleAmountIsSigned(line.role)) {
      final accountType = accountTypes[accountId];
      if (accountType == null) {
        return LedgerViolationReason.postingAccountTypeMissing.throwException(
          message:
              'Account type of $accountId is required for ${line.role.name}.',
        );
      }
      return (
        accountId: accountId,
        signedMinor: _signed(
          directionForBalanceDelta(
            accountType: accountType,
            deltaMinor: line.amount.minorUnits,
          ),
          line.amount.minorUnits.abs(),
        ),
      );
    }

    final direction = entryDirectionFor(
      businessPurpose: businessPurpose,
      role: line.role,
    );
    if (direction == null) return null;
    return (
      accountId: accountId,
      signedMinor: _signed(direction, line.amount.minorUnits),
    );
  }

  String _balancingAccountId({
    required BusinessPurpose businessPurpose,
    required Iterable<TransactionLine> lines,
    required Map<SystemKey, String> systemAccountIds,
  }) {
    final accountId = switch (balancingAccountFor(businessPurpose)) {
      SystemBalancingAccount(:final systemKey) => systemAccountIds[systemKey],
      LineBalancingAccount(:final role) =>
        lines.where((line) => line.role == role).firstOrNull?.accountId,
      null => null,
    };
    if (accountId == null) {
      return LedgerViolationReason.entriesNotBalanced.throwException(
        message:
            'No balancing account for ${businessPurpose.name}; '
            'debit and credit do not match.',
      );
    }
    return accountId;
  }

  int _signed(EntryDirection direction, int amountMinor) =>
      direction == EntryDirection.debit ? amountMinor : -amountMinor;

  TransactionLine _line({
    required String transactionId,
    required int lineNo,
    required TransactionRole role,
    required Money amount,
    String? accountId,
  }) {
    return TransactionLine(
      id: _idGenerator.newId(),
      transactionId: transactionId,
      lineNo: lineNo,
      role: role,
      accountId: accountId,
      amount: amount,
    );
  }

  Entry _entry({
    required String transactionId,
    required String accountId,
    required EntryDirection direction,
    required Money amount,
  }) {
    return Entry(
      id: _idGenerator.newId(),
      transactionId: transactionId,
      accountId: accountId,
      direction: direction,
      amount: amount,
    );
  }
}
