import '../query/account_reconciliation_queries.dart';
import '../query/account_reconciliation_read_models.dart';

abstract interface class AccountReconciliationRepository {
  Stream<List<DailyAccountLedgerState>> watchCurrentDays(
    AccountReconciliationQuery query,
  );

  Stream<List<AccountReconciliationDaySnapshot>> watchSnapshots(
    AccountReconciliationQuery query,
  );

  Future<List<DailyAccountLedgerState>> findCurrentDays(
    AccountReconciliationQuery query,
  );

  Future<void> replaceSnapshots({
    required AccountReconciliationQuery query,
    required Iterable<DailyAccountLedgerState> currentDays,
    required DateTime confirmedAt,
  });

  Future<void> deleteForAccount(String accountId);
}
