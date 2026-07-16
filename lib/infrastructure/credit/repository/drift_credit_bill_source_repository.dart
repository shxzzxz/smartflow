import 'package:drift/drift.dart';

import '../../../domain/credit/port/credit_bill_source_repository.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../database/app_database.dart';

class DriftCreditBillSourceRepository implements CreditBillSourceRepository {
  const DriftCreditBillSourceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<int> netConsumptionMinor({
    required String accountId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final increases = await _sumEntries(
      accountId: accountId,
      direction: EntryDirection.credit,
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      purposes: const {
        BusinessPurpose.dailyExpense,
        BusinessPurpose.transfer,
        BusinessPurpose.reimbursementAdvance,
      },
    );
    final refunds = await _sumEntries(
      accountId: accountId,
      direction: EntryDirection.debit,
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      purposes: const {BusinessPurpose.refund},
    );
    final net = increases - refunds;
    return net < 0 ? 0 : net;
  }

  Future<int> _sumEntries({
    required String accountId,
    required EntryDirection direction,
    required DateTime startInclusive,
    required DateTime endExclusive,
    required Set<BusinessPurpose> purposes,
  }) async {
    final sumExpr = _database.entries.amountMinor.sum();
    final query =
        _database.selectOnly(_database.entries).join([
            innerJoin(
              _database.transactions,
              _database.transactions.id.equalsExp(
                _database.entries.transactionId,
              ),
            ),
          ])
          ..addColumns([sumExpr])
          ..where(_database.entries.accountId.equals(accountId))
          ..where(_database.entries.direction.equalsValue(direction))
          ..where(
            _database.transactions.businessState.equalsValue(
              BusinessState.current,
            ),
          )
          ..where(_database.transactions.businessPurpose.isInValues(purposes))
          ..where(
            _database.transactions.postedAt.isBiggerOrEqualValue(
              startInclusive,
            ),
          )
          ..where(
            _database.transactions.postedAt.isSmallerThanValue(endExclusive),
          );
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0;
  }
}
