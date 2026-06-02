import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

/// 交易查询的口径过滤器（lens）。
///
/// 描述「哪些交易参与该次查询」的会计语义,不含 UI 装饰。Service 决定各方法用哪种 lens
/// （通过下方预设或自定义实例),repository 把 lens 翻译成 SQL where 片段。
///
/// 字面量隔离:repository 接口接受 [TransactionScopeFilter],不出现 BusinessState 等枚举值。
class TransactionScopeFilter {
  const TransactionScopeFilter({
    required this.businessStates,
    this.excludedFromStats,
    this.excludedFromBudget,
  });

  /// 参与查询的 [BusinessState] 白名单。
  final Set<BusinessState> businessStates;

  /// 若指定,要求 transaction.is_excluded_from_stats == 该值。null 表示不限制。
  final bool? excludedFromStats;

  /// 若指定,要求 transaction.is_excluded_from_budget == 该值。null 表示不限制。
  final bool? excludedFromBudget;

  /// 统计口径:current + 非 stats 排除。用于现金流系列指标。
  static const TransactionScopeFilter stats = TransactionScopeFilter(
    businessStates: {BusinessState.current},
    excludedFromStats: false,
  );

  /// 预算口径:current + 非 budget 排除。
  static const TransactionScopeFilter budget = TransactionScopeFilter(
    businessStates: {BusinessState.current},
    excludedFromBudget: false,
  );

  /// 资产负债口径:仅 current,不排除 stats/budget。用于余额、资产负债、净资产趋势。
  static const TransactionScopeFilter assetLiability = TransactionScopeFilter(
    businessStates: {BusinessState.current},
  );

  /// 实际口径:current + compensation。包含已发生的红字凭证事实。
  static const TransactionScopeFilter actual = TransactionScopeFilter(
    businessStates: {BusinessState.current, BusinessState.compensation},
  );

  /// 全部口径:不限 business_state,常用于历史/审计查询。
  static const TransactionScopeFilter all = TransactionScopeFilter(
    businessStates: {
      BusinessState.current,
      BusinessState.replaced,
      BusinessState.canceled,
      BusinessState.compensation,
    },
  );
}
