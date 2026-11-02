import '../../../../core/money/money.dart';
import '../../entity/installment_contract.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/repayment_amount_breakdown.dart';
import '../debt/credit_debt_bucket_service.dart';

/// 一份分期合同当前的履约进度。
class InstallmentRepaymentProgress {
  const InstallmentRepaymentProgress({
    required this.paidPeriodCount,
    required this.totalPeriodCount,
    required this.remainingPrincipal,
    required this.repaid,
  });

  final int paidPeriodCount;
  final int totalPeriodCount;
  final Money remainingPrincipal;

  /// 已发生的还款分摊，包含合同级提前还款；退款还本不在此金额内。
  final RepaymentAmountBreakdown repaid;
}

/// 合同及其还款事实只负责提供输入，进度规则集中在此处。
class InstallmentRepaymentProgressService {
  const InstallmentRepaymentProgressService({
    CreditDebtBucketService debtBuckets = const CreditDebtBucketService(),
  }) : _debtBuckets = debtBuckets;

  final CreditDebtBucketService _debtBuckets;

  InstallmentRepaymentProgress project({
    required InstallmentContract installment,
    required Map<String, RepaymentAmountBreakdown> allocatedByScheduleId,
    required Iterable<RepaymentAmountBreakdown> repayments,
  }) {
    var remainingPrincipalMinor = 0;
    var repaid = RepaymentAmountBreakdown.zero;
    for (final repayment in repayments) {
      repaid += repayment;
    }

    for (final schedule in installment.schedules) {
      if (schedule.status != InstallmentScheduleStatus.pending &&
          schedule.status != InstallmentScheduleStatus.partiallyPaid) {
        continue;
      }
      remainingPrincipalMinor += _debtBuckets.remainingPrincipalMinor(
        expectedPrincipalMinor: schedule.expectedPrincipal.minorUnits,
        allocatedPrincipalMinor:
            allocatedByScheduleId[schedule.id]?.principal.minorUnits ?? 0,
      );
    }

    return InstallmentRepaymentProgress(
      paidPeriodCount: installment.schedules
          .where(
            (schedule) => schedule.status == InstallmentScheduleStatus.paid,
          )
          .length,
      totalPeriodCount: installment.schedules.length,
      remainingPrincipal: Money(minorUnits: remainingPrincipalMinor),
      repaid: repaid,
    );
  }
}
