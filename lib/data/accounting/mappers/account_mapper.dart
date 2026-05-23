import '../../../core/money/money.dart';
import '../../../domain/accounting/entities/account.dart';
import '../../app_database.dart';

Account mapAccount(AccountRow row) {
  return Account(
    id: row.id,
    name: row.name,
    type: row.accountType,
    subtype: row.accountSubtype,
    parentId: row.parentId,
    currencyCode: row.currencyCode,
    balance: Money(minorUnits: row.balanceMinor, currency: row.currencyCode),
    iconKey: row.iconKey,
    note: row.note,
    creditLimit:
        row.creditLimitMinor == null
            ? null
            : Money(
              minorUnits: row.creditLimitMinor!,
              currency: row.currencyCode,
            ),
    billingDay: row.billingDay,
    repaymentDay: row.repaymentDay,
    sortOrder: row.sortOrder,
    isHidden: row.isHidden,
    archivedAt: row.archivedAt,
    systemKey: row.systemKey,
    source: row.source,
  );
}
