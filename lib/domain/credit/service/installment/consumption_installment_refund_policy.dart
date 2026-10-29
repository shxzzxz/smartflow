import '../../../../core/money/money.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/installment_plan_change.dart';

/// Refund principal eligibility for a purchase installment contract.
///
/// A refund can only reduce principal that is still unpaid and whose scheduled
/// repayment date is strictly after the refund business date.
class ConsumptionInstallmentRefundPolicy {
  const ConsumptionInstallmentRefundPolicy();

  Money refundablePrincipal({
    required DateTime refundDate,
    required Iterable<InstallmentPlanRow> rows,
    required Map<String, Money> paidPrincipalByScheduleId,
  }) {
    final cutoff = _dateOnly(refundDate);
    var totalMinor = 0;
    for (final row in rows) {
      if (row.status == InstallmentScheduleStatus.skipped ||
          row.status == InstallmentScheduleStatus.paid ||
          !_dateOnly(row.date).isAfter(cutoff)) {
        continue;
      }
      final scheduleId = row.id;
      final paid = scheduleId == null
          ? Money.zero()
          : paidPrincipalByScheduleId[scheduleId] ?? Money.zero();
      final remainingMinor = row.principal.minorUnits - paid.minorUnits;
      if (remainingMinor > 0) totalMinor += remainingMinor;
    }
    return Money(minorUnits: totalMinor);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
