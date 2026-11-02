import 'package:drift/drift.dart';

import '../../../application/credit/installment/query/port/installment_progress_source.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/repayment_enums.dart';
import '../../../domain/credit/valobj/repayment_amount_breakdown.dart';
import '../../database/app_database.dart';

final class DriftInstallmentProgressSource
    implements InstallmentProgressSource {
  const DriftInstallmentProgressSource(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, List<InstallmentRepaymentAllocationFact>>>
  findRepaymentFacts(Set<String> contractIds) async {
    if (contractIds.isEmpty) return const {};
    final ids = contractIds.toList()..sort();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final variables = [
      for (final id in ids) Variable<String>(id),
      for (final id in ids) Variable<String>(id),
    ];
    final rows = await _db
        .customSelect(
          '''
WITH facts AS (
  SELECT
    bill.contract_id AS contract_id,
    bill.schedule_id AS schedule_id,
    SUM(allocation.allocated_principal_minor) AS principal_minor,
    SUM(allocation.allocated_interest_minor) AS interest_minor,
    SUM(allocation.allocated_fee_minor) AS fee_minor,
    SUM(allocation.allocated_discount_minor) AS discount_minor
  FROM repayments repayment
  JOIN repayment_items allocation
    ON allocation.repayment_id = repayment.id
  JOIN bill_items bill
    ON bill.id = allocation.bill_item_id
  WHERE repayment.target_type = '${RepaymentTargetType.bill.code}'
    AND bill.contract_id IN ($placeholders)
  GROUP BY bill.contract_id, bill.schedule_id

  UNION ALL

  SELECT
    repayment.target_id AS contract_id,
    NULL AS schedule_id,
    SUM(allocation.allocated_principal_minor) AS principal_minor,
    SUM(allocation.allocated_interest_minor) AS interest_minor,
    SUM(allocation.allocated_fee_minor) AS fee_minor,
    SUM(allocation.allocated_discount_minor) AS discount_minor
  FROM repayments repayment
  JOIN repayment_items allocation
    ON allocation.repayment_id = repayment.id
  WHERE repayment.target_type = '${RepaymentTargetType.contract.code}'
    AND repayment.target_id IN ($placeholders)
  GROUP BY repayment.target_id
)
SELECT
  contract_id,
  schedule_id,
  principal_minor,
  interest_minor,
  fee_minor,
  discount_minor
FROM facts
ORDER BY contract_id, schedule_id
''',
          variables: variables,
          readsFrom: {_db.repayments, _db.repaymentItems, _db.billItems},
        )
        .get();
    final result = <String, List<InstallmentRepaymentAllocationFact>>{};
    for (final row in rows) {
      final contractId = row.read<String>('contract_id');
      (result[contractId] ??= []).add(
        InstallmentRepaymentAllocationFact(
          contractId: contractId,
          scheduleId: row.read<String?>('schedule_id'),
          allocated: RepaymentAmountBreakdown(
            principal: Money(minorUnits: row.read<int>('principal_minor')),
            interest: Money(minorUnits: row.read<int>('interest_minor')),
            fee: Money(minorUnits: row.read<int>('fee_minor')),
            discount: Money(minorUnits: row.read<int>('discount_minor')),
          ),
        ),
      );
    }
    return result;
  }
}
