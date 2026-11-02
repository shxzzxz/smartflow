import 'package:drift/drift.dart';

import '../../../application/transaction_view/transaction_view_query_port_api.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/repayment_enums.dart';
import '../../database/app_database.dart';
import 'business_item_query_support.dart';

final class DriftCreditBusinessItemSource implements BusinessItemSource {
  const DriftCreditBusinessItemSource(this._db);

  final AppDatabase _db;

  @override
  String get sourceKey => 'credit';

  @override
  Future<BusinessItemSourcePage> findAnchorPage(
    BusinessItemPageQuery query,
  ) async {
    final rows = await Future.wait([
      _selectContracts(query).get(),
      _selectRepayments(query).get(),
    ]);
    return _mergePages(rows, query.limit);
  }

  @override
  Stream<BusinessItemSourcePage> watchAnchorPage(BusinessItemPageQuery query) {
    return _selectContracts(query).watch().asyncMap((contractRows) async {
      final repaymentRows = await _selectRepayments(query).get();
      return _mergePages([contractRows, repaymentRows], query.limit);
    });
  }

  @override
  Future<Map<BusinessItemKey, BusinessItemSummary>> findSummaries(
    Set<BusinessItemKey> itemKeys,
  ) async {
    final contractIds = {
      for (final key in itemKeys)
        if (key.type == installmentOwnerType) key.id,
    };
    final repaymentIds = {
      for (final key in itemKeys)
        if (key.type == creditRepaymentOwnerType) key.id,
    };

    final results = await Future.wait([
      _findContractSummaries(contractIds),
      _findRepaymentSummaries(repaymentIds),
    ]);
    return {...results[0], ...results[1]};
  }

  Future<Map<BusinessItemKey, BusinessItemSummary>> _findContractSummaries(
    Set<String> contractIds,
  ) async {
    if (contractIds.isEmpty) return const {};
    final variables = businessItemStringVariables(contractIds);
    final placeholders = businessItemPlaceholders(variables.length);
    final results = await Future.wait([
      _db.customSelect('''
SELECT id, installment_type, status, principal_minor
FROM installment_contracts
WHERE id IN ($placeholders)
''', variables: variables).get(),
      _db.customSelect('''
SELECT contract_id, expected_principal_minor, status
FROM installment_schedules
WHERE contract_id IN ($placeholders)
''', variables: variables).get(),
    ]);
    final schedulesByContract = <String, List<QueryRow>>{};
    for (final row in results[1]) {
      schedulesByContract
          .putIfAbsent(row.read<String>('contract_id'), () => [])
          .add(row);
    }

    return {
      for (final row in results[0])
        BusinessItemKey(
          type: installmentOwnerType,
          id: row.read<String>('id'),
        ): _contractSummary(
          row,
          schedulesByContract[row.read<String>('id')] ?? const [],
        ),
    };
  }

  BusinessItemSummary _contractSummary(
    QueryRow contract,
    List<QueryRow> schedules,
  ) {
    final paidCount = schedules
        .where(
          (row) =>
              row.read<String>('status') == InstallmentScheduleStatus.paid.name,
        )
        .length;
    final remainingPrincipal = schedules.fold<int>(0, (total, row) {
      final status = row.read<String>('status');
      if (status != InstallmentScheduleStatus.pending.name &&
          status != InstallmentScheduleStatus.partiallyPaid.name) {
        return total;
      }
      return total + row.read<int>('expected_principal_minor');
    });
    return InstallmentBusinessItemSummary(
      installmentType: InstallmentType.values.byName(
        contract.read<String>('installment_type'),
      ),
      status: InstallmentContractStatus.values.byName(
        contract.read<String>('status'),
      ),
      principal: Money(minorUnits: contract.read<int>('principal_minor')),
      remainingPrincipal: Money(minorUnits: remainingPrincipal),
      paidPeriodCount: paidCount,
      totalPeriodCount: schedules.length,
    );
  }

  Future<Map<BusinessItemKey, BusinessItemSummary>> _findRepaymentSummaries(
    Set<String> repaymentIds,
  ) async {
    if (repaymentIds.isEmpty) return const {};
    final variables = businessItemStringVariables(repaymentIds);
    final rows = await _db.customSelect('''
SELECT id, repayment_type, target_type
FROM repayments
WHERE id IN (${businessItemPlaceholders(variables.length)})
''', variables: variables).get();
    return {
      for (final row in rows)
        BusinessItemKey(
          type: creditRepaymentOwnerType,
          id: row.read<String>('id'),
        ): RepaymentBusinessItemSummary(
          repaymentType: RepaymentType.fromCode(
            row.read<String>('repayment_type'),
          ),
          targetType: RepaymentTargetType.fromCode(
            row.read<String>('target_type'),
          ),
        ),
    };
  }

  Selectable<QueryRow> _selectContracts(BusinessItemPageQuery query) {
    final sql = BusinessItemAnchorSql(
      transactionAlias: 'anchor',
      itemType: installmentOwnerType,
      itemIdExpression: 'contract.id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '$installmentOwnerType' AS item_type,
  contract.id AS item_id
FROM installment_contracts contract
JOIN transactions anchor ON anchor.id = contract.source_ref_id
WHERE contract.source_ref_id IS NOT NULL
  AND contract.installment_type IN ('disbursement', 'purchase')
  AND anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$installmentOwnerType'
  AND anchor.owner_id = contract.id
  AND ${sql.whereClause}
ORDER BY anchor.occurred_at DESC, contract.id DESC
LIMIT ?
''',
      variables: [...sql.variables, Variable<int>(query.limit + 1)],
      readsFrom: {
        _db.transactions,
        _db.transactionLines,
        _db.transactionTags,
        _db.installmentContracts,
        _db.installmentSchedules,
      },
    );
  }

  Selectable<QueryRow> _selectRepayments(BusinessItemPageQuery query) {
    final sql = BusinessItemAnchorSql(
      transactionAlias: 'anchor',
      itemType: creditRepaymentOwnerType,
      itemIdExpression: 'repayment.id',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '$creditRepaymentOwnerType' AS item_type,
  repayment.id AS item_id
FROM repayments repayment
JOIN transactions anchor ON anchor.id = repayment.transaction_id
WHERE anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$creditRepaymentOwnerType'
  AND anchor.owner_id = repayment.id
  AND ${sql.whereClause}
ORDER BY anchor.occurred_at DESC, repayment.id DESC
LIMIT ?
''',
      variables: [...sql.variables, Variable<int>(query.limit + 1)],
      readsFrom: {
        _db.transactions,
        _db.transactionLines,
        _db.transactionTags,
        _db.repayments,
        _db.installmentContracts,
        _db.installmentSchedules,
      },
    );
  }

  BusinessItemSourcePage _mergePages(List<List<QueryRow>> rowPages, int limit) {
    final rows = rowPages.expand((page) => page).toList()
      ..sort((left, right) {
        final byTime = right
            .read<DateTime>('anchor_at')
            .compareTo(left.read<DateTime>('anchor_at'));
        if (byTime != 0) return byTime;
        final byType = right
            .read<String>('item_type')
            .compareTo(left.read<String>('item_type'));
        if (byType != 0) return byType;
        return right
            .read<String>('item_id')
            .compareTo(left.read<String>('item_id'));
      });
    return businessItemSourcePageFromRows(rows, limit: limit);
  }
}
