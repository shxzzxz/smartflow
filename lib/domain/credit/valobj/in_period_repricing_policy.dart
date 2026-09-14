/// 重定价在一期计息区间内部生效时，等额本息的还款处理策略。
enum InPeriodRepricingPolicy {
  /// 保留调息前预测的当期本金，重算分段利息，从下一期重算固定额。
  preservePrincipal,

  /// 当期使用新旧利率分段合计的期利率，重算包含当期的剩余还款安排。
  dynamicPeriodRate,
}
