enum InstallmentSourceType { disbursement, billConversion }

enum InstallmentRepaymentMethod {
  equalInstallment,
  equalPrincipal,
  interestFirst,
  flatFee,
  custom,
}

enum InterestRatePeriod { annual, monthly, daily }

/// 计息基础（与利率单位 [InterestRatePeriod] 不同：
/// 后者表达"输入的利率值按年/月/日折算"，前者决定"每期按多少个时间单位计息"）。
/// 每期按还款节奏折算出的整数个基础单位计息，不看实际日期。
/// - [daily]：每期利息 = 余额 × 日利率 × 实际天数。
/// - [monthly]：每期利息 = 余额 × 月利率 × 节奏月数，与天数无关。
/// - [annual]：每期利息 = 余额 × 年利率 × 节奏月数 / 12，即"每期按整年计息"。
enum InterestAccrualMethod { daily, monthly, annual }

enum InstallmentContractStatus { active, settled }

enum InstallmentScheduleStatus { pending, partiallyPaid, paid, skipped }

/// 分期模块写入 `transaction.owner_type` 的固定值。
const String installmentOwnerType = 'installment';

/// 分期模块写入 `transaction.owner_role` 的角色枚举。
///
/// wire 值即落库字符串：迁移 SQL、单测断言、跨存储读取都以 [wireValue] 为准。
/// 仅在分期模块内部以枚举形式使用；账务核心 / 通用 UI 不感知具体取值。
enum InstallmentOwnerRole {
  disbursement('disbursement');

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
