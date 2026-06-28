import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../database/app_database.dart';

Account mapAccount(AccountRow row) {
  return Account(
    id: row.id,
    name: row.name,
    type: row.accountType,
    subtype: row.accountSubtype,
    profileKey: row.accountProfileKey,
    parentId: row.parentId,
    balance: Money(minorUnits: row.balanceMinor),
    iconKey: row.iconKey,
    note: row.note,
    sortOrder: row.sortOrder,
    isHidden: row.isHidden,
    archivedAt: row.archivedAt,
    version: row.version,
    systemKey: row.systemKey,
    source: row.source,
  );
}
