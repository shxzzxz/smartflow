import 'package:drift/drift.dart';

import '../../../application/credit/transaction_view/query/credit_transaction_view_read_models.dart';
import '../../../application/credit/transaction_view/query/port/credit_transaction_view_source.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/entity/bill.dart';
import '../../../domain/credit/valobj/bill_enums.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/repayment_amount_breakdown.dart';
import '../../../domain/credit/valobj/repayment_enums.dart';
import '../../database/app_database.dart';

final class DriftCreditTransactionViewSource
    implements CreditTransactionViewSource {
  const DriftCreditTransactionViewSource(this._db);

  final AppDatabase _db;

  @override
  Future<CreditTransactionViewAnchorPage> findAnchorPage(
    CreditTransactionViewQuery query,
  ) async {
    return _pageFromRows(await _anchorSelect(query).get(), query.limit);
  }

  @override
  Stream<CreditTransactionViewAnchorPage> watchAnchorPage(
    CreditTransactionViewQuery query,
  ) {
    return _anchorSelect(
      query,
    ).watch().map((rows) => _pageFromRows(rows, query.limit));
  }

  @override
  Future<Map<String, CreditInstallmentSummarySource>>
  findInstallmentSummarySources(Set<String> contractIds) async {
    if (contractIds.isEmpty) return const {};
    final ids = contractIds.toList()..sort();
    final variables = _variables(ids);
    final placeholders = _placeholders(ids.length);
    final results = await Future.wait([
      _db
          .customSelect(
            '''
SELECT id, installment_type, status, principal_minor
FROM installment_contracts
WHERE id IN ($placeholders)
''',
            variables: variables,
            readsFrom: {_db.installmentContracts},
          )
          .get(),
      _db
          .customSelect(
            '''
SELECT
  schedule.contract_id AS schedule_contract_id,
  schedule.status AS schedule_status,
  schedule.expected_principal_minor AS schedule_principal_minor,
  bill.id AS bill_item_id,
  bill.bill_id,
  bill.item_type,
  bill.repayment_date,
  bill.expected_principal_minor,
  bill.expected_interest_minor,
  bill.expected_fee_minor,
  bill.status AS bill_item_status,
  bill.billing_state,
  bill.contract_id AS bill_contract_id,
  bill.schedule_id AS bill_schedule_id,
  bill.created_at AS bill_created_at,
  COALESCE(SUM(allocation.allocated_principal_minor), 0)
    AS allocated_principal_minor
FROM installment_schedules schedule
LEFT JOIN bill_items bill ON bill.schedule_id = schedule.id
LEFT JOIN repayment_items allocation ON allocation.bill_item_id = bill.id
WHERE schedule.contract_id IN ($placeholders)
GROUP BY
  schedule.id,
  bill.id
ORDER BY schedule.contract_id, schedule.period_no, bill.id
''',
            variables: variables,
            readsFrom: {
              _db.installmentSchedules,
              _db.bills,
              _db.billItems,
              _db.repaymentItems,
            },
          )
          .get(),
    ]);

    final schedulesByContract =
        <String, List<CreditInstallmentScheduleSummarySource>>{};
    for (final row in results[1]) {
      final contractId = row.read<String>('schedule_contract_id');
      final billItemId = row.read<String?>('bill_item_id');
      schedulesByContract
          .putIfAbsent(contractId, () => [])
          .add(
            CreditInstallmentScheduleSummarySource(
              status: InstallmentScheduleStatus.values.byName(
                row.read<String>('schedule_status'),
              ),
              expectedPrincipal: Money(
                minorUnits: row.read<int>('schedule_principal_minor'),
              ),
              allocated: RepaymentAmountBreakdown(
                principal: Money(
                  minorUnits: row.read<int>('allocated_principal_minor'),
                ),
                interest: Money.zero(),
                fee: Money.zero(),
                discount: Money.zero(),
              ),
              billItem: billItemId == null
                  ? null
                  : BillItem(
                      id: billItemId,
                      billId: row.read<String>('bill_id'),
                      itemType: BillItemType.values.byName(
                        row.read<String>('item_type'),
                      ),
                      repaymentDate: row.read<DateTime>('repayment_date'),
                      expectedPrincipal: Money(
                        minorUnits: row.read<int>('expected_principal_minor'),
                      ),
                      expectedInterest: Money(
                        minorUnits: row.read<int>('expected_interest_minor'),
                      ),
                      expectedFee: Money(
                        minorUnits: row.read<int>('expected_fee_minor'),
                      ),
                      status: BillItemStatus.values.byName(
                        row.read<String>('bill_item_status'),
                      ),
                      billingState: BillItemBillingState.values.byName(
                        row.read<String>('billing_state'),
                      ),
                      contractId: row.read<String?>('bill_contract_id'),
                      scheduleId: row.read<String?>('bill_schedule_id'),
                      createdAt: row.read<DateTime?>('bill_created_at'),
                    ),
            ),
          );
    }

    return {
      for (final row in results[0])
        row.read<String>('id'): CreditInstallmentSummarySource(
          contractId: row.read<String>('id'),
          installmentType: InstallmentType.values.byName(
            row.read<String>('installment_type'),
          ),
          status: InstallmentContractStatus.values.byName(
            row.read<String>('status'),
          ),
          principal: Money(minorUnits: row.read<int>('principal_minor')),
          schedules: schedulesByContract[row.read<String>('id')] ?? const [],
        ),
    };
  }

  @override
  Future<Map<String, CreditRepaymentBusinessItemSummary>>
  findRepaymentSummaries(Set<String> repaymentIds) async {
    if (repaymentIds.isEmpty) return const {};
    final ids = repaymentIds.toList()..sort();
    final rows = await _db
        .customSelect(
          '''
SELECT id, repayment_type, target_type, target_id
FROM repayments
WHERE id IN (${_placeholders(ids.length)})
''',
          variables: _variables(ids),
          readsFrom: {_db.repayments},
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('id'): CreditRepaymentBusinessItemSummary(
          repaymentType: RepaymentType.fromCode(
            row.read<String>('repayment_type'),
          ),
          targetType: RepaymentTargetType.fromCode(
            row.read<String>('target_type'),
          ),
          targetId: row.read<String>('target_id'),
        ),
    };
  }

  Selectable<QueryRow> _anchorSelect(CreditTransactionViewQuery query) {
    final requestedTypes = query.itemTypes;
    final branches = <String>[];
    final variables = <Variable>[];

    if (requestedTypes == null ||
        requestedTypes.contains(CreditTransactionViewItemType.installment)) {
      final sql = _AnchorSql(
        transactionAlias: 'anchor',
        itemType: CreditTransactionViewItemType.installment.code,
        itemIdExpression: 'contract.id',
      )..apply(query);
      branches.add('''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '${CreditTransactionViewItemType.installment.code}' AS item_type,
  contract.id AS item_id
FROM installment_contracts contract
JOIN transactions anchor ON anchor.id = contract.source_ref_id
WHERE contract.source_ref_id IS NOT NULL
  AND contract.installment_type IN ('disbursement', 'purchase')
  AND anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$installmentOwnerType'
  AND anchor.owner_id = contract.id
  AND ${sql.whereClause}
''');
      variables.addAll(sql.variables);
    }

    if (requestedTypes == null ||
        requestedTypes.contains(CreditTransactionViewItemType.repayment)) {
      final sql = _AnchorSql(
        transactionAlias: 'anchor',
        itemType: CreditTransactionViewItemType.repayment.code,
        itemIdExpression: 'repayment.id',
      )..apply(query);
      branches.add('''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '${CreditTransactionViewItemType.repayment.code}' AS item_type,
  repayment.id AS item_id
FROM repayments repayment
JOIN transactions anchor ON anchor.id = repayment.transaction_id
WHERE anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$creditRepaymentOwnerType'
  AND anchor.owner_id = repayment.id
  AND ${sql.whereClause}
''');
      variables.addAll(sql.variables);
    }

    if (branches.isEmpty) {
      return _db.customSelect(
        'SELECT NULL AS anchor_transaction_id, NULL AS anchor_at, '
        'NULL AS item_type, NULL AS item_id WHERE 0 = 1',
      );
    }

    return _db.customSelect(
      '''
SELECT *
FROM (
  ${branches.join('\nUNION ALL\n')}
)
ORDER BY anchor_at DESC, item_type DESC, item_id DESC
LIMIT ?
''',
      variables: [...variables, Variable<int>(query.limit + 1)],
      readsFrom: {
        _db.transactions,
        _db.transactionLines,
        _db.transactionTags,
        _db.installmentContracts,
        _db.installmentSchedules,
        _db.bills,
        _db.billItems,
        _db.repayments,
        _db.repaymentItems,
      },
    );
  }

  CreditTransactionViewAnchorPage _pageFromRows(
    List<QueryRow> rows,
    int limit,
  ) {
    return CreditTransactionViewAnchorPage(
      hasMore: rows.length > limit,
      anchors: [
        for (final row in rows.take(limit + 1))
          CreditTransactionViewAnchorCandidate(
            itemType: CreditTransactionViewItemType.values.firstWhere(
              (value) => value.code == row.read<String>('item_type'),
            ),
            itemId: row.read<String>('item_id'),
            anchorTransactionId: row.read<String>('anchor_transaction_id'),
            anchorAt: row.read<DateTime>('anchor_at'),
          ),
      ],
    );
  }
}

final class _AnchorSql {
  _AnchorSql({
    required this.transactionAlias,
    required this.itemType,
    required this.itemIdExpression,
  });

  final String transactionAlias;
  final String itemType;
  final String itemIdExpression;
  final List<String> _conditions = [];
  final List<Variable> _variables = [];

  List<Variable> get variables => List.unmodifiable(_variables);

  void apply(CreditTransactionViewQuery query) {
    _conditions.add(
      '($transactionAlias.occurred_at >= ? AND '
      '$transactionAlias.occurred_at < ?)',
    );
    _variables
      ..add(Variable<DateTime>(query.occurredFrom))
      ..add(Variable<DateTime>(query.occurredUntil));

    final before = query.before;
    if (before != null) _applyCursor(before);

    final categories = query.categoryAccountIds;
    if (categories != null) {
      _transactionLineFilter(
        categories,
        roles: const {'category', 'advanceExpenseCategory', 'advanceSelfBorne'},
        alias: 'credit_category_lines',
      );
    }

    final settlements = query.settlementAccountIds;
    if (settlements != null) {
      _transactionLineFilter(
        settlements,
        roles: const {'settlementIn', 'settlementOut'},
        alias: 'credit_settlement_lines',
      );
    }

    final tags = query.tagIds;
    if (tags != null) {
      if (tags.isEmpty) {
        _conditions.add('0 = 1');
      } else {
        final placeholders = _placeholders(tags.length);
        _variables.addAll(_variablesFor(tags));
        _conditions.add(
          'EXISTS (SELECT 1 FROM transaction_tags tag_match '
          'WHERE tag_match.transaction_id = $transactionAlias.id '
          'AND tag_match.tag_id IN ($placeholders))',
        );
      }
    } else if (query.untaggedOnly) {
      _conditions.add(
        'NOT EXISTS (SELECT 1 FROM transaction_tags tag_match '
        'WHERE tag_match.transaction_id = $transactionAlias.id)',
      );
    }

    final counterpartyId = query.counterpartyId;
    if (counterpartyId != null) {
      _conditions.add('$transactionAlias.counterparty_id = ?');
      _variables.add(Variable<String>(counterpartyId));
    }
  }

  String get whereClause => _conditions.join(' AND ');

  void _applyCursor(CreditTransactionViewCursor before) {
    final comparison = itemType.compareTo(before.itemType);
    if (comparison < 0) {
      _conditions.add('$transactionAlias.occurred_at <= ?');
      _variables.add(Variable<DateTime>(before.anchorAt));
    } else if (comparison > 0) {
      _conditions.add('$transactionAlias.occurred_at < ?');
      _variables.add(Variable<DateTime>(before.anchorAt));
    } else {
      _conditions.add(
        '($transactionAlias.occurred_at < ? OR '
        '($transactionAlias.occurred_at = ? AND $itemIdExpression < ?))',
      );
      _variables
        ..add(Variable<DateTime>(before.anchorAt))
        ..add(Variable<DateTime>(before.anchorAt))
        ..add(Variable<String>(before.itemId));
    }
  }

  void _transactionLineFilter(
    Set<String> accountIds, {
    required Set<String> roles,
    required String alias,
  }) {
    if (accountIds.isEmpty) {
      _conditions.add('0 = 1');
      return;
    }
    final accountPlaceholders = _placeholders(accountIds.length);
    _variables.addAll(_variablesFor(accountIds));
    final rolePlaceholders = roles
        .map((role) => "'${role.replaceAll("'", "''")}'")
        .join(', ');
    _conditions.add(
      'EXISTS (SELECT 1 FROM transaction_lines $alias '
      'WHERE $alias.transaction_id = $transactionAlias.id '
      'AND $alias.role IN ($rolePlaceholders) '
      'AND $alias.account_id IN ($accountPlaceholders))',
    );
  }
}

List<Variable<String>> _variablesFor(Iterable<String> values) {
  final sorted = values.toSet().toList()..sort();
  return [for (final value in sorted) Variable<String>(value)];
}

List<Variable<String>> _variables(Iterable<String> values) =>
    _variablesFor(values);

String _placeholders(int count) => List.filled(count, '?').join(', ');
