import '../valobj/ledger_enum.dart';

abstract interface class SystemAccountResolver {
  Future<String> resolveOpeningBalance();

  Future<String> resolveReimbursementGapIncome();

  Future<String> resolveInterestExpense();

  Future<String> resolveFeeExpense();

  Future<String> resolveDiscountIncome();

  /// 幽灵账户:用于导入 / 修复等场景下"暂时挂在某个语义账户"的占位入口。
  Future<String> resolveGhostAccount();
}

abstract interface class ReceivableSystemAccountResolver
    implements SystemAccountResolver {
  Future<String> resolveInterestIncome();
  Future<String> resolveBadDebtExpense();
  Future<String> resolveDebtReliefIncome();
}

/// 过账规则以 [SystemKey] 表达规则账户;这里把它翻译成具体解析调用。
extension SystemAccountResolution on SystemAccountResolver {
  Future<Map<SystemKey, String>> resolveAll(Set<SystemKey> keys) async {
    final resolved = <SystemKey, String>{};
    for (final key in keys) {
      resolved[key] = await resolveByKey(key);
    }
    return resolved;
  }

  Future<String> resolveByKey(SystemKey key) {
    return switch (key) {
      SystemKey.openingBalance => resolveOpeningBalance(),
      SystemKey.reimbursementGapIncome => resolveReimbursementGapIncome(),
      SystemKey.interestExpense => resolveInterestExpense(),
      SystemKey.feeExpense => resolveFeeExpense(),
      SystemKey.discountIncome => resolveDiscountIncome(),
      SystemKey.ghostAccount => resolveGhostAccount(),
      SystemKey.interestIncome => _receivable.resolveInterestIncome(),
      SystemKey.badDebtExpense => _receivable.resolveBadDebtExpense(),
      SystemKey.debtReliefIncome => _receivable.resolveDebtReliefIncome(),
    };
  }

  ReceivableSystemAccountResolver get _receivable {
    final resolver = this;
    if (resolver is ReceivableSystemAccountResolver) return resolver;
    throw StateError('System account resolver does not support receivables.');
  }
}
