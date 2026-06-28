import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/entity/credit_liability_account.dart';
import '../../../domain/credit/port/credit_account_repository.dart';
import '../../../domain/credit/valobj/bill_period.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../database/app_database.dart';
import '../../database/patch_value.dart';

class DriftCreditAccountRepository implements CreditAccountRepository {
  DriftCreditAccountRepository(this._database);

  final AppDatabase _database;

  @override
  Future<CreditLiabilityAccount?> findByAccountId(String accountId) async {
    final row =
        await (_database.select(_database.creditLiabilityAccounts)..where(
          (table) => table.accountId.equals(accountId),
        )).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Stream<Map<String, CreditLiabilityAccount>> watchByAccountId() {
    return _database.select(_database.creditLiabilityAccounts).watch().map((
      rows,
    ) {
      return {for (final row in rows) row.accountId: _map(row)};
    });
  }

  @override
  Future<void> insert(CreditLiabilityAccountDraft draft) async {
    final account = CreditLiabilityAccount(
      id: draft.id,
      accountId: draft.accountId,
      kind: draft.kind,
      creditLimit: draft.creditLimit,
      billingDay: draft.billingDay,
      repaymentDay: draft.repaymentDay,
      billingStartPeriod: draft.billingStartPeriod,
      billingDayToNext: draft.billingDayToNext,
    );
    final now = DateTime.now();
    await _database
        .into(_database.creditLiabilityAccounts)
        .insert(
          CreditLiabilityAccountsCompanion.insert(
            id: account.id,
            accountId: account.accountId,
            kind: account.kind,
            creditLimitMinor: Value(account.creditLimit?.minorUnits),
            billingDay: Value(account.billingDay),
            repaymentDay: Value(account.repaymentDay),
            billingStartPeriod: Value(account.billingStartPeriod?.toInt()),
            billingDayToNext: Value(account.billingDayToNext),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<void> update(
    String accountId,
    CreditLiabilityAccountPersistencePatch patch,
  ) async {
    final updated = await (_database.update(_database.creditLiabilityAccounts)
      ..where((table) => table.accountId.equals(accountId))).write(
      CreditLiabilityAccountsCompanion(
        creditLimitMinor: patch.creditLimit.toMappedValue(
          (money) => money.minorUnits,
        ),
        billingDay: patch.billingDay.toValue(),
        repaymentDay: patch.repaymentDay.toValue(),
        billingStartPeriod: patch.billingStartPeriod.toMappedValue(
          (period) => period.toInt(),
        ),
        billingDayToNext:
            patch.billingDayToNext == null
                ? const Value.absent()
                : Value(patch.billingDayToNext!),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (updated != 1) {
      throw BusinessException(CreditErrorCode.accountPersistenceConflict);
    }
  }

  CreditLiabilityAccount _map(CreditLiabilityAccountRow row) {
    return CreditLiabilityAccount(
      id: row.id,
      accountId: row.accountId,
      kind: row.kind,
      creditLimit:
          row.creditLimitMinor == null
              ? null
              : Money(minorUnits: row.creditLimitMinor!),
      billingDay: row.billingDay,
      repaymentDay: row.repaymentDay,
      billingStartPeriod:
          row.billingStartPeriod == null
              ? null
              : BillPeriod.fromInt(row.billingStartPeriod!),
      billingDayToNext: row.billingDayToNext,
    );
  }
}
