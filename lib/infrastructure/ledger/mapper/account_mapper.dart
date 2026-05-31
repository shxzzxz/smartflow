import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../database/app_database.dart';

Account mapAccount(AccountRow row) {
  return Account(
    id: row.id,
    name: row.name,
    type: row.accountType,
    subtype: row.accountSubtype,
    parentId: row.parentId,
    balance: Money(minorUnits: row.balanceMinor),
    iconKey: row.iconKey,
    note: row.note,
    creditLimit:
        row.creditLimitMinor == null
            ? null
            : Money(minorUnits: row.creditLimitMinor!),
    billingDay: row.billingDay,
    repaymentDay: row.repaymentDay,
    sortOrder: row.sortOrder,
    isHidden: row.isHidden,
    archivedAt: row.archivedAt,
    version: row.version,
    systemKey: row.systemKey,
    source: row.source,
  );
}
