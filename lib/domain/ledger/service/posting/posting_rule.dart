import '../../entity/entry.dart';
import '../../entity/transaction_line.dart';
import '../../valobj/ledger_enum.dart';

/// 交易主金额的正数约束。结束报销的主金额表达实际到账,允许一分未收。
bool primaryAmountAllowsZero(BusinessPurpose businessPurpose) =>
    businessPurpose == BusinessPurpose.reimbursementClose;

/// 账户余额按借贷的净增量。
///
/// - 资产 / 费用账户:借方为正
/// - 负债 / 收入 / 权益账户:贷方为正
int balanceDeltaMinor({
  required AccountType accountType,
  required EntryDirection direction,
  required int amountMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;

  if (increasesOnDebit) {
    return direction == EntryDirection.debit ? amountMinor : -amountMinor;
  }

  return direction == EntryDirection.credit ? amountMinor : -amountMinor;
}

/// 给定账户类型与"目标余额变化方向(±)",返回应使用的 entry 方向。
/// 期初余额 / 余额调整这两个带符号角色用此公式。
EntryDirection directionForBalanceDelta({
  required AccountType accountType,
  required int deltaMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;
  final increase = deltaMinor > 0;
  if (increasesOnDebit) {
    return increase ? EntryDirection.debit : EntryDirection.credit;
  }
  return increase ? EntryDirection.credit : EntryDirection.debit;
}

bool entriesAreBalanced(Iterable<Object> entries) {
  var debitMinor = 0;
  var creditMinor = 0;

  for (final item in entries) {
    final (:direction, :amountMinor) = switch (item) {
      Entry(:final direction, :final amount) => (
        direction: direction,
        amountMinor: amount.minorUnits,
      ),
      _ => throw ArgumentError.value(item, 'entries', 'Unsupported entry type'),
    };
    switch (direction) {
      case EntryDirection.debit:
        debitMinor += amountMinor;
      case EntryDirection.credit:
        creditMinor += amountMinor;
    }
  }

  return debitMinor == creditMinor;
}

bool sameLines(Iterable<Object> left, Iterable<Object> right) {
  return _sameShapes(left, right, _lineShape);
}

bool sameEntries(Iterable<Object> left, Iterable<Object> right) {
  return _sameShapes(left, right, _entryShape);
}

bool hasSamePostingShape(dynamic left, dynamic right) {
  return left.businessPurpose == right.businessPurpose &&
      left.primaryAmount == right.primaryAmount &&
      sameLines(left.lines, right.lines) &&
      sameEntries(left.entries, right.entries);
}

bool _sameShapes(
  Iterable<Object> left,
  Iterable<Object> right,
  String Function(Object) shapeOf,
) {
  final leftShape = left.map(shapeOf).toList()..sort();
  final rightShape = right.map(shapeOf).toList()..sort();
  if (leftShape.length != rightShape.length) return false;
  for (var i = 0; i < leftShape.length; i++) {
    if (leftShape[i] != rightShape[i]) return false;
  }
  return true;
}

String _lineShape(Object item) {
  final (:role, :accountId, :amountMinor) = switch (item) {
    TransactionLine(:final role, :final accountId, :final amount) => (
      role: role,
      accountId: accountId,
      amountMinor: amount.minorUnits,
    ),
    _ => throw ArgumentError.value(item, 'lines', 'Unsupported line type'),
  };
  return '${role.name}|${accountId ?? ''}|$amountMinor';
}

String _entryShape(Object item) {
  final (:accountId, :direction, :amountMinor) = switch (item) {
    Entry(:final accountId, :final direction, :final amount) => (
      accountId: accountId,
      direction: direction,
      amountMinor: amount.minorUnits,
    ),
    _ => throw ArgumentError.value(item, 'entries', 'Unsupported entry type'),
  };
  return '$accountId|${direction.name}|$amountMinor';
}

const _allowedPurposesByRole = <TransactionRole, Set<BusinessPurpose>>{
  TransactionRole.category: {
    BusinessPurpose.dailyExpense,
    BusinessPurpose.dailyIncome,
  },
  TransactionRole.settlementIn: {
    BusinessPurpose.dailyIncome,
    BusinessPurpose.transfer,
    BusinessPurpose.refund,
    BusinessPurpose.reimbursementReceipt,
    BusinessPurpose.reimbursementClose,
    BusinessPurpose.borrowing,
    BusinessPurpose.receivableCollection,
  },
  TransactionRole.settlementOut: {
    BusinessPurpose.dailyExpense,
    BusinessPurpose.transfer,
    BusinessPurpose.reimbursementAdvance,
    BusinessPurpose.debtRepayment,
    BusinessPurpose.lending,
  },
  TransactionRole.receivable: {
    BusinessPurpose.reimbursementAdvance,
    BusinessPurpose.reimbursementReceipt,
    BusinessPurpose.reimbursementClose,
    BusinessPurpose.lending,
    BusinessPurpose.receivableCollection,
    BusinessPurpose.badDebt,
  },
  TransactionRole.liability: {
    BusinessPurpose.borrowing,
    BusinessPurpose.debtRepayment,
    BusinessPurpose.debtRelief,
  },
  TransactionRole.interest: {
    BusinessPurpose.debtRepayment,
    BusinessPurpose.receivableCollection,
  },
  TransactionRole.fee: {
    BusinessPurpose.transfer,
    BusinessPurpose.debtRepayment,
  },
  TransactionRole.discount: {BusinessPurpose.debtRepayment},
  TransactionRole.refundOffset: {BusinessPurpose.refund},
  TransactionRole.reimbursementExpenseCategory: {
    BusinessPurpose.reimbursementAdvance,
    BusinessPurpose.refund,
  },
  TransactionRole.reimbursementGapIncome: {BusinessPurpose.reimbursementClose},
  TransactionRole.reimbursementGapExpense: {BusinessPurpose.reimbursementClose},
  TransactionRole.openingBalance: {BusinessPurpose.openingBalance},
  TransactionRole.balanceAdjustment: {BusinessPurpose.balanceAdjustment},
};

/// 账户由过账规则按 `system_key` 解析、分项本身恒不携带账户的角色。
const _ruleAccountRoles = <TransactionRole>{
  TransactionRole.interest,
  TransactionRole.fee,
  TransactionRole.discount,
  TransactionRole.reimbursementGapIncome,
};

/// 金额带符号存储的角色:方向由符号与账户类型共同决定。
const _signedAmountRoles = <TransactionRole>{
  TransactionRole.openingBalance,
  TransactionRole.balanceAdjustment,
};

bool roleAllowedForPurpose({
  required TransactionRole role,
  required BusinessPurpose businessPurpose,
}) {
  return _allowedPurposesByRole[role]?.contains(businessPurpose) ?? false;
}

/// 分项自身是否携带账户。为 false 时账户由 [systemKeyForRole] 解析。
bool roleCarriesAccount(TransactionRole role) =>
    !_ruleAccountRoles.contains(role);

bool roleAmountIsSigned(TransactionRole role) =>
    _signedAmountRoles.contains(role);

SystemKey? systemKeyForRole({
  required BusinessPurpose businessPurpose,
  required TransactionRole role,
}) {
  return switch (role) {
    TransactionRole.fee => SystemKey.feeExpense,
    TransactionRole.discount => SystemKey.discountIncome,
    TransactionRole.interest =>
      businessPurpose == BusinessPurpose.debtRepayment
          ? SystemKey.interestExpense
          : SystemKey.interestIncome,
    TransactionRole.reimbursementGapIncome => SystemKey.reimbursementGapIncome,
    _ => null,
  };
}

/// 分项对应分录的方向;`null` 表示该分项不产生分录。
///
/// 带符号角色(见 [roleAmountIsSigned])不走此表,方向由
/// [directionForBalanceDelta] 按符号与账户类型决定。
EntryDirection? entryDirectionFor({
  required BusinessPurpose businessPurpose,
  required TransactionRole role,
}) {
  return switch (role) {
    TransactionRole.settlementIn => EntryDirection.debit,
    TransactionRole.settlementOut => EntryDirection.credit,
    TransactionRole.refundOffset => EntryDirection.credit,
    TransactionRole.fee => EntryDirection.debit,
    TransactionRole.discount => EntryDirection.credit,
    TransactionRole.reimbursementGapIncome => EntryDirection.credit,
    TransactionRole.reimbursementGapExpense => EntryDirection.debit,
    TransactionRole.category =>
      businessPurpose == BusinessPurpose.dailyExpense
          ? EntryDirection.debit
          : EntryDirection.credit,
    TransactionRole.interest =>
      businessPurpose == BusinessPurpose.debtRepayment
          ? EntryDirection.debit
          : EntryDirection.credit,
    // 应收增加(垫付 / 借出)记借方,应收减少(到账 / 收回 / 结束报销 / 坏账)记贷方。
    TransactionRole.receivable =>
      businessPurpose == BusinessPurpose.reimbursementAdvance ||
              businessPurpose == BusinessPurpose.lending
          ? EntryDirection.debit
          : EntryDirection.credit,
    // 负债增加(借入)记贷方,负债减少(还款 / 债务豁免)记借方。
    TransactionRole.liability =>
      businessPurpose == BusinessPurpose.borrowing
          ? EntryDirection.credit
          : EntryDirection.debit,
    // 报销垫付时支出分类只是业务事实,不产生分录;它在结束报销少收时才被使用。
    TransactionRole.reimbursementExpenseCategory => null,
    TransactionRole.openingBalance || TransactionRole.balanceAdjustment => null,
  };
}

/// 借贷差额的兜底腿落在哪个账户。
sealed class PostingBalancingAccount {
  const PostingBalancingAccount();
}

/// 差额落在按 `system_key` 解析的规则账户上。
class SystemBalancingAccount extends PostingBalancingAccount {
  const SystemBalancingAccount(this.systemKey);

  final SystemKey systemKey;
}

/// 差额落回某条分项的账户上,例如转账手续费由转出账户承担。
class LineBalancingAccount extends PostingBalancingAccount {
  const LineBalancingAccount(this.role);

  final TransactionRole role;
}

PostingBalancingAccount? balancingAccountFor(BusinessPurpose businessPurpose) {
  return switch (businessPurpose) {
    BusinessPurpose.transfer => const LineBalancingAccount(
      TransactionRole.settlementOut,
    ),
    BusinessPurpose.badDebt => const SystemBalancingAccount(
      SystemKey.badDebtExpense,
    ),
    BusinessPurpose.debtRelief => const SystemBalancingAccount(
      SystemKey.debtReliefIncome,
    ),
    BusinessPurpose.openingBalance || BusinessPurpose.balanceAdjustment =>
      const SystemBalancingAccount(SystemKey.openingBalance),
    _ => null,
  };
}

/// 过账这组分项需要预先解析的系统科目。
Set<SystemKey> requiredSystemKeys({
  required BusinessPurpose businessPurpose,
  required Iterable<TransactionLine> lines,
}) {
  final keys = <SystemKey>{};
  for (final line in lines) {
    if (line.amount.minorUnits == 0) continue;
    final key = systemKeyForRole(
      businessPurpose: businessPurpose,
      role: line.role,
    );
    if (key != null) keys.add(key);
  }
  final balancing = balancingAccountFor(businessPurpose);
  if (balancing is SystemBalancingAccount) keys.add(balancing.systemKey);
  return keys;
}
