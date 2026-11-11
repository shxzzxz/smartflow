import 'package:drift/drift.dart';

/// User-confirmed daily account ledger state.
///
/// The row deliberately stores no balance: the expected closing balance is a
/// transient query input used to derive daily expected balances.
@DataClassName('AccountReconciliationSnapshotRow')
class AccountReconciliationSnapshots extends Table {
  TextColumn get accountId => text().named('account_id')();
  IntColumn get ledgerDateKey => integer().named('ledger_date_key')();
  DateTimeColumn get latestTransactionUpdatedAt =>
      dateTime().named('latest_transaction_updated_at')();
  IntColumn get transactionCount => integer().named('transaction_count')();
  DateTimeColumn get confirmedAt => dateTime().named('confirmed_at')();

  @override
  Set<Column> get primaryKey => {accountId, ledgerDateKey};

  @override
  List<String> get customConstraints => ['CHECK (transaction_count > 0)'];
}
