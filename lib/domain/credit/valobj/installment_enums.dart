enum InstallmentSourceType { disbursement, billConversion }

enum InstallmentRepaymentMethod {
  equalInstallment,
  equalPrincipal,
  interestFirst,
  flatFee,
  custom,
}

enum InterestRatePeriod { annual, monthly, daily }

/// 计息方式（与利率单位 [InterestRatePeriod] 不同：
/// 后者表达"输入的利率值按年/月/日折算"，前者决定"每期利息怎么算"）。
/// - [daily]：每期利息 = 余额 × 日利率 × 实际天数；
///   等额本息下每期还款额按现金流折现求解。
/// - [monthly]：每期利息 = 余额 × 月利率，与天数无关；
///   等额本息下用标准月供公式。
enum InterestAccrualMethod { daily, monthly }

enum InstallmentContractStatus { active, settled, closed }

enum InstallmentScheduleStatus { pending, paid, skipped }

enum InstallmentRepaymentType { scheduled, extraPrincipal, earlySettlement }

/// 分期模块写入 `transaction.owner_type` 的固定值。
/// `transaction.owner_*` 仍是开放字符串字段，账务核心不解释（见 docs/08.1）；
/// 该常量只在分期模块内部使用，避免裸字面值散布。
const String installmentOwnerType = 'installment';

/// 分期模块写入 `transaction.owner_role` 的角色枚举。
///
/// wire 值即落库字符串：迁移 SQL、单测断言、跨存储读取都以 [wireValue] 为准。
/// 仅在分期模块内部以枚举形式使用；账务核心 / 通用 UI 不感知具体取值。
enum InstallmentOwnerRole {
  disbursement('disbursement'),
  scheduledRepayment('scheduled_repayment'),
  extraPrincipal('extra_principal'),
  earlySettlement('early_settlement');

  const InstallmentOwnerRole(this.wireValue);

  final String wireValue;

  static InstallmentOwnerRole? fromWire(String? value) {
    if (value == null) return null;
    for (final role in InstallmentOwnerRole.values) {
      if (role.wireValue == value) return role;
    }
    return null;
  }
}
