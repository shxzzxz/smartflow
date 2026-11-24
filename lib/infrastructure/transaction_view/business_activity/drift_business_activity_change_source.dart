import 'package:drift/drift.dart';

import '../../../application/transaction_view/transaction_view_query_port_api.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/repayment_enums.dart';
import '../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../database/app_database.dart';

/// Watches dependencies of the complete candidate and summary read paths.
final class DriftBusinessActivityChangeSource
    implements BusinessActivityChangeSource {
  const DriftBusinessActivityChangeSource(this._db);

  final AppDatabase _db;

  @override
  Stream<void> watchChanges(BusinessActivityPageQuery query) {
    final tables = _tablesFor(query.activityTypes);
    if (tables.isEmpty) return Stream.value(null);
    return Stream.multi((controller) {
      final subscription = _db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen(
            (_) => controller.add(null),
            onError: controller.addError,
            onDone: controller.close,
          );
      controller.onCancel = subscription.cancel;
      controller.add(null);
    });
  }

  Set<TableInfo<Table, dynamic>> _tablesFor(Set<String>? types) {
    bool includes(String type) => types == null || types.contains(type);
    final ledger = includes(ledgerTransactionGroupActivityType);
    final advance = includes(orchestrationAdvanceOwnerType);
    final amortization = includes(orchestrationAmortizationOwnerType);
    final installment = includes(installmentOwnerType);
    final repayment = includes(creditRepaymentOwnerType);
    if (!ledger && !advance && !amortization && !installment && !repayment) {
      return {};
    }
    return {
      // Candidate filters and ledger projections, including child transactions.
      _db.transactions,
      _db.transactionLines,
      _db.transactionTags,
      _db.entries,
      _db.accounts,
      _db.counterparties,
      if (advance) _db.advanceCases,
      if (amortization) ...{
        _db.amortizationPlans,
        _db.amortizationPeriods,
        _db.amortizationRefunds,
        _db.amortizationTerminations,
        _db.amortizationAllocations,
      },
      if (installment) ...{
        _db.installmentContracts,
        _db.installmentStageConfigs,
        _db.installmentSchedules,
        _db.installmentRepricingConfigs,
        _db.installmentRepricingRecords,
        _db.installmentInterestAdjustments,
        _db.billItems,
        _db.repaymentItems,
      },
      if (installment || repayment) _db.repayments,
    };
  }
}
