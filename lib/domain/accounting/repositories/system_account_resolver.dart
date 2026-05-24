import '../../../core/money/money.dart';

abstract interface class SystemAccountResolver {
  Future<int> resolveOpeningBalance({
    String currencyCode = Money.defaultCurrency,
  });

  Future<int> resolveReimbursementGapIncome({
    String currencyCode = Money.defaultCurrency,
  });

  Future<int> resolveDebtInterestExpense({
    String currencyCode = Money.defaultCurrency,
  });

  Future<int> resolveDebtFeeExpense({
    String currencyCode = Money.defaultCurrency,
  });

  Future<int> resolveDiscountIncome({
    String currencyCode = Money.defaultCurrency,
  });

  /// 幽灵账户:用于导入 / 修复等场景下"暂时挂在某个语义账户"的占位入口。
  Future<int> resolveGhostAccount({
    String currencyCode = Money.defaultCurrency,
  });
}
