import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/accounting/entities/transaction.dart' as domain;
import '../../../domain/accounting/entities/transaction_ownership.dart';
import '../../../domain/accounting/enums/accounting_enums.dart';
import '../../../domain/accounting/queries/transaction_queries.dart';
import '../../../domain/accounting/repositories/transaction_query_repository.dart';
import '../../../domain/accounting/views/transaction_views.dart';
import '../../app_database.dart';

class DriftTransactionQueryRepository implements TransactionQueryRepository {
  const DriftTransactionQueryRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<TransactionListItem>> watchTransactions(
    TransactionListQuery query,
  ) {
    final accountFilter =
        query.accountId == null
            ? ''
            : 'AND EXISTS ('
                'SELECT 1 FROM entries ae '
                'WHERE ae.transaction_id = t.id AND ae.account_id = ?'
                ') ';
    final topLevelFilter =
        query.topLevelOnly ? 'AND t.parent_transaction_id IS NULL ' : '';
    final fromFilter =
        query.occurredFrom == null ? '' : 'AND t.occurred_at >= ? ';
    final untilFilter =
        query.occurredUntil == null ? '' : 'AND t.occurred_at < ? ';
    final accountDeltaSelect =
        query.accountId == null
            ? 'NULL AS account_delta_minor, '
            : '(SELECT COALESCE(SUM('
                "CASE WHEN aa.account_type IN ('asset', 'expense') THEN "
                "CASE WHEN ae.direction = 'debit' THEN ae.amount_minor "
                'ELSE -ae.amount_minor END '
                'ELSE '
                "CASE WHEN ae.direction = 'credit' THEN ae.amount_minor "
                'ELSE -ae.amount_minor END END'
                '), 0) '
                'FROM entries ae '
                'JOIN accounts aa ON aa.id = ae.account_id '
                'WHERE ae.transaction_id = t.id AND ae.account_id = ?) '
                'AS account_delta_minor, ';
    final variables = <Variable<Object>>[
      if (query.accountId != null) Variable<int>(query.accountId!),
      Variable<String>(BusinessState.current.name),
      if (query.accountId != null) Variable<int>(query.accountId!),
      if (query.occurredFrom != null) Variable<DateTime>(query.occurredFrom!),
      if (query.occurredUntil != null) Variable<DateTime>(query.occurredUntil!),
      Variable<int>(query.limit),
      Variable<int>(query.offset),
    ];

    return _database
        .customSelect(
          'WITH page AS ('
          'SELECT t.id, COALESCE(t.root_transaction_id, t.id) AS root_id, '
          't.parent_transaction_id, t.business_purpose, t.occurred_at, '
          't.currency_code, t.primary_amount_minor, t.counterparty_name, '
          '$accountDeltaSelect'
          't.note, t.is_excluded_from_stats, t.is_excluded_from_budget, '
          "COALESCE(group_concat(a.name, ' / '), '') AS account_names, "
          "MAX(CASE WHEN t.business_purpose = 'dailyExpense' "
          "AND a.account_type = 'expense' THEN a.name "
          "WHEN t.business_purpose = 'dailyIncome' "
          "AND a.account_type = 'income' THEN a.name "
          "WHEN t.business_purpose = 'reimbursementAdvance' "
          "AND expense_category.account_type = 'expense' "
          'THEN expense_category.name END) AS category_name, '
          "MAX(CASE WHEN t.business_purpose = 'dailyExpense' "
          "AND a.account_type = 'expense' THEN a.icon_key "
          "WHEN t.business_purpose = 'dailyIncome' "
          "AND a.account_type = 'income' THEN a.icon_key "
          "WHEN t.business_purpose = 'reimbursementAdvance' "
          "AND expense_category.account_type = 'expense' "
          'THEN expense_category.icon_key END) '
          'AS category_icon_key, '
          "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
          "AND e.direction = 'credit' THEN a.id END) "
          'AS flow_out_account_id, '
          "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
          "AND e.direction = 'debit' THEN a.id END) "
          'AS flow_in_account_id, '
          "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
          "AND e.direction = 'credit' THEN a.name END) "
          'AS flow_out_account_name, '
          "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
          "AND e.direction = 'debit' THEN a.name END) "
          'AS flow_in_account_name, '
          // 还款利息 / 手续费：来自主交易自身的 transaction_details
          '(SELECT COALESCE(SUM(td.amount_minor), 0) '
          'FROM transaction_details td '
          'WHERE td.transaction_id = t.id '
          "AND td.detail_type = 'repaymentInterest') "
          'AS repayment_interest_minor, '
          '(SELECT COALESCE(SUM(td.amount_minor), 0) '
          'FROM transaction_details td '
          'WHERE td.transaction_id = t.id '
          "AND td.detail_type = 'repaymentFee') "
          'AS repayment_fee_minor, '
          '(SELECT COALESCE(SUM(td.amount_minor), 0) '
          'FROM transaction_details td '
          'WHERE td.transaction_id = t.id '
          "AND td.detail_type = 'repaymentDiscount') "
          'AS repayment_discount_minor '
          'FROM transactions t '
          'LEFT JOIN entries e ON e.transaction_id = t.id '
          'LEFT JOIN accounts a ON a.id = e.account_id '
          'LEFT JOIN accounts expense_category '
          'ON expense_category.id = t.reimbursement_expense_account_id '
          'WHERE t.business_state = ? '
          '$topLevelFilter'
          '$accountFilter'
          '$fromFilter'
          '$untilFilter'
          'GROUP BY t.id '
          'ORDER BY t.occurred_at DESC, t.id DESC '
          'LIMIT ? OFFSET ?'
          '), roots AS ('
          'SELECT DISTINCT root_id FROM page'
          '), refund_agg AS ('
          'SELECT c.root_transaction_id AS root_id, '
          'COALESCE(SUM(c.primary_amount_minor), 0) AS total_minor, '
          'COUNT(*) AS child_count '
          'FROM transactions c '
          'JOIN roots r ON r.root_id = c.root_transaction_id '
          'WHERE c.parent_transaction_id IS NOT NULL '
          "AND c.business_purpose = 'refund' "
          "AND c.business_state = 'current' "
          'GROUP BY c.root_transaction_id'
          '), reimbursement_agg AS ('
          'SELECT c.root_transaction_id AS root_id, '
          'COALESCE(SUM(c.primary_amount_minor), 0) AS total_minor, '
          'COUNT(*) AS child_count '
          'FROM transactions c '
          'JOIN roots r ON r.root_id = c.root_transaction_id '
          'WHERE c.parent_transaction_id IS NOT NULL '
          "AND c.business_purpose IN ('reimbursementReceipt', "
          "'reimbursementClose') "
          "AND c.business_state = 'current' "
          'GROUP BY c.root_transaction_id'
          '), reimbursement_gap_agg AS ('
          'SELECT c.root_transaction_id AS root_id, '
          "COALESCE(SUM(CASE WHEN td.detail_type = 'reimbursementGapIncome' "
          'THEN td.amount_minor ELSE 0 END), 0) AS gap_income_minor, '
          "COALESCE(SUM(CASE WHEN td.detail_type = 'reimbursementGapExpense' "
          'THEN td.amount_minor ELSE 0 END), 0) AS gap_expense_minor '
          'FROM transactions c '
          'JOIN roots r ON r.root_id = c.root_transaction_id '
          'JOIN transaction_details td ON td.transaction_id = c.id '
          'WHERE c.parent_transaction_id IS NOT NULL '
          "AND c.business_state = 'current' "
          "AND td.detail_type IN ('reimbursementGapIncome', "
          "'reimbursementGapExpense') "
          'GROUP BY c.root_transaction_id'
          ') '
          'SELECT p.id, p.business_purpose, p.occurred_at, '
          'p.currency_code, p.primary_amount_minor, p.counterparty_name, '
          'p.account_delta_minor, '
          'p.note, p.is_excluded_from_stats, p.is_excluded_from_budget, '
          'p.account_names, p.category_name, p.category_icon_key, '
          'p.flow_out_account_id, p.flow_in_account_id, '
          'p.flow_out_account_name, p.flow_in_account_name, '
          "CASE WHEN p.parent_transaction_id IS NULL "
          "AND p.business_purpose = 'dailyExpense' "
          'THEN COALESCE(ra.total_minor, 0) ELSE 0 END '
          'AS refunded_total_minor, '
          "CASE WHEN p.parent_transaction_id IS NULL "
          "AND p.business_purpose = 'dailyExpense' "
          'THEN COALESCE(ra.child_count, 0) ELSE 0 END '
          'AS refund_child_count, '
          "CASE WHEN p.parent_transaction_id IS NULL "
          "AND p.business_purpose = 'reimbursementAdvance' "
          'THEN COALESCE(ba.total_minor, 0) ELSE 0 END '
          'AS reimbursement_received_minor, '
          "CASE WHEN p.parent_transaction_id IS NULL "
          "AND p.business_purpose = 'reimbursementAdvance' "
          'THEN COALESCE(ba.child_count, 0) ELSE 0 END '
          'AS reimbursement_child_count, '
          "CASE WHEN p.parent_transaction_id IS NULL "
          "AND p.business_purpose = 'reimbursementAdvance' "
          'THEN COALESCE(ga.gap_income_minor, 0) ELSE 0 END '
          'AS reimbursement_gap_income_minor, '
          "CASE WHEN p.parent_transaction_id IS NULL "
          "AND p.business_purpose = 'reimbursementAdvance' "
          'THEN COALESCE(ga.gap_expense_minor, 0) ELSE 0 END '
          'AS reimbursement_gap_expense_minor, '
          'p.repayment_interest_minor, p.repayment_fee_minor, '
          'p.repayment_discount_minor '
          'FROM page p '
          'LEFT JOIN refund_agg ra ON ra.root_id = p.root_id '
          'LEFT JOIN reimbursement_agg ba ON ba.root_id = p.root_id '
          'LEFT JOIN reimbursement_gap_agg ga ON ga.root_id = p.root_id '
          'ORDER BY p.occurred_at DESC, p.id DESC',
          variables: variables,
          readsFrom: {
            _database.transactions,
            _database.transactionDetails,
            _database.entries,
            _database.accounts,
          },
        )
        .watch()
        .map((rows) => rows.map(_mapListItem).toList());
  }

  @override
  Stream<CashflowSummary> watchCashflowSummary(CashflowSummaryQuery query) {
    return _database
        .customSelect(
          'SELECT '
          "COALESCE(SUM(CASE WHEN a.account_type = 'income' THEN "
          "CASE WHEN e.direction = 'credit' THEN e.amount_minor "
          "WHEN e.direction = 'debit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS income_minor, '
          "COALESCE(SUM(CASE WHEN a.account_type = 'expense' THEN "
          "CASE WHEN e.direction = 'debit' THEN e.amount_minor "
          "WHEN e.direction = 'credit' THEN -e.amount_minor "
          'ELSE 0 END ELSE 0 END), 0) AS expense_minor '
          'FROM entries e '
          'JOIN transactions t ON t.id = e.transaction_id '
          'JOIN accounts a ON a.id = e.account_id '
          "WHERE t.business_state = 'current' "
          'AND t.is_excluded_from_stats = 0 '
          'AND t.currency_code = ? '
          'AND t.occurred_at >= ? '
          'AND t.occurred_at < ? '
          "AND a.account_type IN ('income', 'expense')",
          variables: [
            Variable<String>(query.currencyCode),
            Variable<DateTime>(query.occurredFrom),
            Variable<DateTime>(query.occurredUntil),
          ],
          readsFrom: {
            _database.transactions,
            _database.entries,
            _database.accounts,
          },
        )
        .watchSingle()
        .map(
          (row) => CashflowSummary(
            income: Money(
              minorUnits: row.read<int>('income_minor'),
              currency: query.currencyCode,
            ),
            expense: Money(
              minorUnits: row.read<int>('expense_minor'),
              currency: query.currencyCode,
            ),
          ),
        );
  }

  @override
  Stream<TransactionDetailView?> watchTransactionDetail(int transactionId) {
    return _database
        .customSelect(
          'SELECT t.id FROM transactions t '
          'LEFT JOIN transaction_details td ON td.transaction_id = t.id '
          'LEFT JOIN entries e ON e.transaction_id = t.id '
          'LEFT JOIN accounts a ON a.id = e.account_id '
          'WHERE t.id = ? OR t.parent_transaction_id = ? '
          'LIMIT 1',
          variables: [
            Variable<int>(transactionId),
            Variable<int>(transactionId),
          ],
          readsFrom: {
            _database.transactions,
            _database.transactionDetails,
            _database.entries,
            _database.accounts,
          },
        )
        .watch()
        .asyncMap((_) => _getTransactionDetail(transactionId));
  }

  @override
  Future<domain.Transaction?> findTransactionById(int transactionId) async {
    final row =
        await (_database.select(_database.transactions)
          ..where((t) => t.id.equals(transactionId))).getSingleOrNull();
    if (row == null) return null;
    return _mapTransaction(row);
  }

  @override
  Future<Money> getRefundedTotal(
    int rootTransactionId, {
    String currencyCode = Money.defaultCurrency,
  }) async {
    final row =
        await _database
            .customSelect(
              'SELECT COALESCE(SUM(t.primary_amount_minor), 0) AS total '
              'FROM transactions t '
              'WHERE t.root_transaction_id = ? '
              "AND t.business_purpose = 'refund' "
              "AND t.business_state = 'current'",
              variables: [Variable<int>(rootTransactionId)],
              readsFrom: {_database.transactions},
            )
            .getSingle();
    return Money(minorUnits: row.read<int>('total'), currency: currencyCode);
  }

  @override
  Future<ReimbursementSummary?> getReimbursementSummary(
    int rootTransactionId,
  ) async {
    final advance =
        await (_database.select(_database.transactions)..where(
          (t) =>
              t.rootTransactionId.equals(rootTransactionId) &
              t.parentTransactionId.isNull() &
              t.businessPurpose.equalsValue(
                BusinessPurpose.reimbursementAdvance,
              ) &
              t.businessState.equalsValue(BusinessState.current),
        )).getSingleOrNull();
    if (advance == null) {
      return null;
    }

    final children =
        await (_database.select(_database.transactions)..where(
          (t) =>
              t.rootTransactionId.equals(rootTransactionId) &
              t.businessPurpose.isInValues({
                BusinessPurpose.reimbursementReceipt,
                BusinessPurpose.reimbursementClose,
              }) &
              t.businessState.equalsValue(BusinessState.current),
        )).get();

    var receivedMinor = 0;
    var isClosed = false;
    for (final child in children) {
      receivedMinor += child.primaryAmountMinor;
      if (child.businessPurpose == BusinessPurpose.reimbursementClose) {
        isClosed = true;
      }
    }

    final advanceAmount = Money(
      minorUnits: advance.primaryAmountMinor,
      currency: advance.currencyCode,
    );
    final receivedAmount = Money(
      minorUnits: receivedMinor,
      currency: advance.currencyCode,
    );
    final outstanding =
        isClosed
            ? Money(minorUnits: 0, currency: advance.currencyCode)
            : advanceAmount - receivedAmount;
    return ReimbursementSummary(
      advanceAmount: advanceAmount,
      receivedAmount: receivedAmount,
      outstanding: outstanding,
      isClosed: isClosed,
    );
  }

  @override
  Future<int> getDetailAmountSum({
    required Iterable<int> transactionIds,
    required TransactionDetailType detailType,
  }) async {
    final ids = transactionIds.toSet();
    if (ids.isEmpty) return 0;
    final sumAmount = _database.transactionDetails.amountMinor.sum();
    final row =
        await (_database.selectOnly(_database.transactionDetails)
              ..addColumns([sumAmount])
              ..where(
                _database.transactionDetails.transactionId.isIn(ids) &
                    _database.transactionDetails.detailType.equalsValue(
                      detailType,
                    ),
              ))
            .getSingle();
    return row.read(sumAmount) ?? 0;
  }

  Future<TransactionDetailView?> _getTransactionDetail(
    int transactionId,
  ) async {
    final transaction =
        await (_database.select(_database.transactions)
          ..where((row) => row.id.equals(transactionId))).getSingleOrNull();
    if (transaction == null) {
      return null;
    }

    final details =
        await (_database.select(_database.transactionDetails)
              ..where((row) => row.transactionId.equals(transactionId))
              ..orderBy([(row) => OrderingTerm.asc(row.lineNo)]))
            .get();

    final entryRows =
        await (_database.select(_database.entries).join([
                innerJoin(
                  _database.accounts,
                  _database.accounts.id.equalsExp(_database.entries.accountId),
                ),
              ])
              ..where(_database.entries.transactionId.equals(transactionId))
              ..orderBy([OrderingTerm.asc(_database.entries.id)]))
            .get();

    final children = await _loadChildren(transactionId);
    final history = await _loadHistory(
      rootTransactionId: transaction.rootTransactionId ?? transaction.id,
      excludeTransactionId: transaction.id,
    );
    final category = await _resolveDetailCategory(transaction);
    Money? refundedTotal;
    if (transaction.businessPurpose == BusinessPurpose.dailyExpense) {
      refundedTotal = await getRefundedTotal(
        transaction.rootTransactionId ?? transaction.id,
        currencyCode: transaction.currencyCode,
      );
    }
    ReimbursementSummary? reimbursementSummary;
    if (transaction.businessPurpose == BusinessPurpose.reimbursementAdvance) {
      reimbursementSummary = await getReimbursementSummary(
        transaction.rootTransactionId ?? transaction.id,
      );
    }

    return TransactionDetailView(
      transaction: _mapTransaction(transaction),
      details: [
        for (final detail in details)
          TransactionDetailLineView(
            lineNo: detail.lineNo,
            type: detail.detailType,
            amount: Money(
              minorUnits: detail.amountMinor,
              currency: transaction.currencyCode,
            ),
          ),
      ],
      entries: [
        for (final row in entryRows)
          EntryLineView(
            accountId: row.readTable(_database.accounts).id,
            accountName: row.readTable(_database.accounts).name,
            accountType: row.readTable(_database.accounts).accountType,
            accountIconKey: row.readTable(_database.accounts).iconKey,
            direction: row.readTable(_database.entries).direction,
            amount: Money(
              minorUnits: row.readTable(_database.entries).amountMinor,
              currency: transaction.currencyCode,
            ),
          ),
      ],
      children: children,
      history: history,
      categoryName: category?.name,
      categoryIconKey: category?.iconKey,
      refundedTotal: refundedTotal,
      reimbursementSummary: reimbursementSummary,
    );
  }

  Future<AccountRow?> _resolveDetailCategory(TransactionRow transaction) async {
    if (transaction.businessPurpose == BusinessPurpose.reimbursementAdvance) {
      final categoryId = transaction.reimbursementExpenseAccountId;
      if (categoryId == null) return null;
      return (_database.select(_database.accounts)
        ..where((a) => a.id.equals(categoryId))).getSingleOrNull();
    }
    final type = switch (transaction.businessPurpose) {
      BusinessPurpose.dailyExpense ||
      BusinessPurpose.refund => AccountType.expense,
      BusinessPurpose.dailyIncome => AccountType.income,
      _ => null,
    };
    if (type == null) return null;
    final rows =
        await (_database.select(_database.entries).join([
                innerJoin(
                  _database.accounts,
                  _database.accounts.id.equalsExp(_database.entries.accountId),
                ),
              ])
              ..where(
                _database.entries.transactionId.equals(transaction.id) &
                    _database.accounts.accountType.equalsValue(type),
              )
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.readTable(_database.accounts);
  }

  Future<List<TransactionListItem>> _loadChildren(int parentId) async {
    final variables = <Variable<Object>>[
      Variable<int>(parentId),
      Variable<String>(BusinessState.current.name),
    ];
    final rows =
        await _database
            .customSelect(
              'SELECT t.id, t.business_purpose, t.occurred_at, '
              't.currency_code, t.primary_amount_minor, t.counterparty_name, '
              'NULL AS account_delta_minor, '
              't.note, t.is_excluded_from_stats, t.is_excluded_from_budget, '
              "COALESCE(group_concat(a.name, ' / '), '') AS account_names, "
              'NULL AS category_name, NULL AS category_icon_key, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'credit' THEN a.id END) "
              'AS flow_out_account_id, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'debit' THEN a.id END) "
              'AS flow_in_account_id, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'credit' THEN a.name END) "
              'AS flow_out_account_name, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'debit' THEN a.name END) "
              'AS flow_in_account_name, '
              '0 AS refunded_total_minor, 0 AS refund_child_count, '
              '0 AS reimbursement_received_minor, 0 AS reimbursement_child_count, '
              '0 AS reimbursement_gap_income_minor, '
              '0 AS reimbursement_gap_expense_minor, '
              '0 AS repayment_interest_minor, 0 AS repayment_fee_minor, '
              '0 AS repayment_discount_minor '
              'FROM transactions t '
              'LEFT JOIN entries e ON e.transaction_id = t.id '
              'LEFT JOIN accounts a ON a.id = e.account_id '
              'WHERE t.parent_transaction_id = ? AND t.business_state = ? '
              'GROUP BY t.id '
              'ORDER BY t.occurred_at DESC, t.id DESC',
              variables: variables,
              readsFrom: {
                _database.transactions,
                _database.entries,
                _database.accounts,
              },
            )
            .get();
    return rows.map(_mapListItem).toList();
  }

  Future<List<TransactionListItem>> _loadHistory({
    required int rootTransactionId,
    required int excludeTransactionId,
  }) async {
    final rows =
        await _database
            .customSelect(
              'SELECT t.id, t.business_purpose, t.occurred_at, '
              't.currency_code, t.primary_amount_minor, t.counterparty_name, '
              'NULL AS account_delta_minor, '
              't.note, t.is_excluded_from_stats, t.is_excluded_from_budget, '
              "COALESCE(group_concat(a.name, ' / '), '') AS account_names, "
              "MAX(CASE WHEN t.business_purpose = 'dailyExpense' "
              "AND a.account_type = 'expense' THEN a.name "
              "WHEN t.business_purpose = 'dailyIncome' "
              "AND a.account_type = 'income' THEN a.name "
              "WHEN t.business_purpose = 'reimbursementAdvance' "
              "AND expense_category.account_type = 'expense' "
              'THEN expense_category.name END) AS category_name, '
              "MAX(CASE WHEN t.business_purpose = 'dailyExpense' "
              "AND a.account_type = 'expense' THEN a.icon_key "
              "WHEN t.business_purpose = 'dailyIncome' "
              "AND a.account_type = 'income' THEN a.icon_key "
              "WHEN t.business_purpose = 'reimbursementAdvance' "
              "AND expense_category.account_type = 'expense' "
              'THEN expense_category.icon_key END) AS category_icon_key, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'credit' THEN a.id END) "
              'AS flow_out_account_id, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'debit' THEN a.id END) "
              'AS flow_in_account_id, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'credit' THEN a.name END) "
              'AS flow_out_account_name, '
              "MAX(CASE WHEN a.account_type IN ('asset', 'liability') "
              "AND e.direction = 'debit' THEN a.name END) "
              'AS flow_in_account_name, '
              '0 AS refunded_total_minor, 0 AS refund_child_count, '
              '0 AS reimbursement_received_minor, 0 AS reimbursement_child_count, '
              '0 AS reimbursement_gap_income_minor, '
              '0 AS reimbursement_gap_expense_minor, '
              '0 AS repayment_interest_minor, 0 AS repayment_fee_minor, '
              '0 AS repayment_discount_minor '
              'FROM transactions t '
              'LEFT JOIN entries e ON e.transaction_id = t.id '
              'LEFT JOIN accounts a ON a.id = e.account_id '
              'LEFT JOIN accounts expense_category '
              'ON expense_category.id = t.reimbursement_expense_account_id '
              'WHERE t.root_transaction_id = ? AND t.id <> ? '
              "AND (t.business_state <> 'current' "
              "OR t.mutation_kind <> 'original') "
              'GROUP BY t.id '
              'ORDER BY t.created_at DESC, t.id DESC',
              variables: [
                Variable<int>(rootTransactionId),
                Variable<int>(excludeTransactionId),
              ],
              readsFrom: {
                _database.transactions,
                _database.entries,
                _database.accounts,
              },
            )
            .get();
    return rows.map(_mapListItem).toList();
  }

  TransactionListItem _mapListItem(QueryRow row) {
    final currencyCode = row.read<String>('currency_code');
    Money? optionalMoney(String column) {
      final value = row.read<int>(column);
      if (value == 0) return null;
      return Money(minorUnits: value, currency: currencyCode);
    }

    return TransactionListItem(
      id: row.read<int>('id'),
      businessPurpose: BusinessPurpose.values.byName(
        row.read<String>('business_purpose'),
      ),
      occurredAt: row.read<DateTime>('occurred_at'),
      primaryAmount: Money(
        minorUnits: row.read<int>('primary_amount_minor'),
        currency: currencyCode,
      ),
      accountBalanceDelta:
          row.read<int?>('account_delta_minor') == null
              ? null
              : Money(
                minorUnits: row.read<int>('account_delta_minor'),
                currency: currencyCode,
              ),
      counterpartyName: row.read<String?>('counterparty_name'),
      note: row.read<String?>('note'),
      accountNames: row.read<String>('account_names'),
      categoryName: row.read<String?>('category_name'),
      categoryIconKey: row.read<String?>('category_icon_key'),
      flowOutAccountId: row.read<int?>('flow_out_account_id'),
      flowInAccountId: row.read<int?>('flow_in_account_id'),
      flowOutAccountName: row.read<String?>('flow_out_account_name'),
      flowInAccountName: row.read<String?>('flow_in_account_name'),
      isExcludedFromStats: row.read<bool>('is_excluded_from_stats'),
      isExcludedFromBudget: row.read<bool>('is_excluded_from_budget'),
      refundedTotal: optionalMoney('refunded_total_minor'),
      refundChildCount: row.read<int>('refund_child_count'),
      reimbursementReceivedTotal: optionalMoney('reimbursement_received_minor'),
      reimbursementChildCount: row.read<int>('reimbursement_child_count'),
      reimbursementGapIncome: optionalMoney('reimbursement_gap_income_minor'),
      reimbursementGapExpense: optionalMoney('reimbursement_gap_expense_minor'),
      repaymentInterest: optionalMoney('repayment_interest_minor'),
      repaymentFee: optionalMoney('repayment_fee_minor'),
      repaymentDiscount: optionalMoney('repayment_discount_minor'),
    );
  }

  domain.Transaction _mapTransaction(TransactionRow row) {
    return domain.Transaction(
      id: row.id,
      rootTransactionId: row.rootTransactionId ?? row.id,
      businessPurpose: row.businessPurpose,
      occurredAt: row.occurredAt,
      currencyCode: row.currencyCode,
      primaryAmount: Money(
        minorUnits: row.primaryAmountMinor,
        currency: row.currencyCode,
      ),
      counterpartyName: row.counterpartyName,
      note: row.note,
      parentTransactionId: row.parentTransactionId,
      reimbursementExpenseAccountId: row.reimbursementExpenseAccountId,
      mutationKind: row.mutationKind,
      mutationPreviousTransactionId: row.mutationPreviousTransactionId,
      mutationReason: row.mutationReason,
      businessState: row.businessState,
      isExcludedFromStats: row.isExcludedFromStats,
      isExcludedFromBudget: row.isExcludedFromBudget,
      sourceKind: row.sourceKind,
      ownership:
          row.ownerType == null
              ? null
              : TransactionOwnership(
                ownerType: row.ownerType!,
                ownerId: row.ownerId,
                ownerRole: row.ownerRole,
              ),
      createdAt: row.createdAt,
    );
  }
}
