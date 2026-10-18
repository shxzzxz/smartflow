import '../../application/credit/installment/query/port/installment_statistics_change_source.dart';
import '../database/app_database.dart';

class DriftInstallmentStatisticsChangeSource
    implements InstallmentStatisticsChangeSource {
  const DriftInstallmentStatisticsChangeSource(this._database);

  final AppDatabase _database;

  @override
  Stream<void> watchChanges() {
    return _database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _database.installmentContracts,
            _database.installmentSchedules,
            _database.bills,
            _database.billItems,
            _database.repayments,
            _database.repaymentItems,
          },
        )
        .watch()
        .map((_) {});
  }
}
