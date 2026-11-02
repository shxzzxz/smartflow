import '../../../../core/money/money.dart';
import '../../../../domain/credit/service/debt/credit_debt_bucket_service.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../installment/query/port/installment_statistics_change_source.dart';
import 'credit_transaction_view_read_models.dart';
import 'port/credit_transaction_view_source.dart';

/// Credit-domain query used by the cross-domain transaction view.
abstract interface class CreditTransactionViewQueryService {
  Future<CreditTransactionViewAnchorPage> findAnchorPage(
    CreditTransactionViewQuery query,
  );

  Stream<CreditTransactionViewAnchorPage> watchAnchorPage(
    CreditTransactionViewQuery query,
  );

  Future<Map<String, CreditInstallmentBusinessItemSummary>>
  findInstallmentSummaries(Set<String> contractIds);

  Stream<CreditInstallmentBusinessItemSummary?> watchInstallmentSummary(
    String contractId,
  );

  Future<Map<String, CreditRepaymentBusinessItemSummary>>
  findRepaymentSummaries(Set<String> repaymentIds);

  Stream<CreditRepaymentBusinessItemSummary?> watchRepaymentSummary(
    String repaymentId,
  );
}

final class CreditTransactionViewQueryServiceImpl
    implements CreditTransactionViewQueryService {
  CreditTransactionViewQueryServiceImpl({
    required CreditTransactionViewSource source,
    required InstallmentStatisticsChangeSource changes,
    CreditDebtBucketService debtBuckets = const CreditDebtBucketService(),
  }) : _source = source,
       _changes = changes,
       _debtBuckets = debtBuckets;

  final CreditTransactionViewSource _source;
  final InstallmentStatisticsChangeSource _changes;
  final CreditDebtBucketService _debtBuckets;

  @override
  Future<CreditTransactionViewAnchorPage> findAnchorPage(
    CreditTransactionViewQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<CreditTransactionViewAnchorPage> watchAnchorPage(
    CreditTransactionViewQuery query,
  ) => _source.watchAnchorPage(query);

  @override
  Future<Map<String, CreditInstallmentBusinessItemSummary>>
  findInstallmentSummaries(Set<String> contractIds) async {
    final sources = await _source.findInstallmentSummarySources(contractIds);
    return {
      for (final entry in sources.entries)
        entry.key: _projectInstallment(entry.value),
    };
  }

  @override
  Stream<CreditInstallmentBusinessItemSummary?> watchInstallmentSummary(
    String contractId,
  ) {
    return _changes.watchChanges().asyncMap((_) async {
      final summaries = await findInstallmentSummaries({contractId});
      return summaries[contractId];
    });
  }

  @override
  Future<Map<String, CreditRepaymentBusinessItemSummary>>
  findRepaymentSummaries(Set<String> repaymentIds) {
    return _source.findRepaymentSummaries(repaymentIds);
  }

  @override
  Stream<CreditRepaymentBusinessItemSummary?> watchRepaymentSummary(
    String repaymentId,
  ) {
    return _changes.watchChanges().asyncMap((_) async {
      final summaries = await findRepaymentSummaries({repaymentId});
      return summaries[repaymentId];
    });
  }

  CreditInstallmentBusinessItemSummary _projectInstallment(
    CreditInstallmentSummarySource source,
  ) {
    final paidPeriods = source.schedules.where(
      (schedule) => schedule.status == InstallmentScheduleStatus.paid,
    );
    var remainingPrincipalMinor = 0;
    for (final schedule in source.schedules) {
      final billItem = schedule.billItem;
      if (billItem != null) {
        remainingPrincipalMinor += _debtBuckets.remainingPrincipalForBillItem(
          billItem,
          allocatedPrincipalMinor: schedule.allocated.principal.minorUnits,
        );
      } else if (schedule.status == InstallmentScheduleStatus.pending ||
          schedule.status == InstallmentScheduleStatus.partiallyPaid) {
        remainingPrincipalMinor +=
            schedule.expectedPrincipal.minorUnits -
            schedule.allocated.principal.minorUnits;
      }
    }
    return CreditInstallmentBusinessItemSummary(
      installmentType: source.installmentType,
      status: source.status,
      principal: source.principal,
      remainingPrincipal: Money(
        minorUnits: remainingPrincipalMinor < 0 ? 0 : remainingPrincipalMinor,
      ),
      paidPeriodCount: paidPeriods.length,
      totalPeriodCount: source.schedules.length,
    );
  }
}
