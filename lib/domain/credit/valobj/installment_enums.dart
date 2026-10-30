enum InstallmentType { disbursement, billConversion, purchase }

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
/// 月、年口径按约定还款间隔折算，不按实际天数调整单位数量。
/// - [daily]：每期利息 = 余额 × 日利率 × 实际天数。
/// - [monthly]：每期利息 = 余额 × 月利率 × 节奏月数，与天数无关。
/// - [annual]：每期利息 = 余额 × 年利率 × 间隔月数 / 12，支持分数年。
enum InterestAccrualMethod { daily, monthly, annual }

enum InstallmentContractStatus { active, settled }

enum InstallmentScheduleStatus { pending, partiallyPaid, paid, skipped }

enum InstallmentRepricingStatus { pending, applied, userConfirmed }

/// 分期模块写入 `transaction.owner_type` 的固定值。
const String installmentOwnerType = 'credit.installment_contract';
