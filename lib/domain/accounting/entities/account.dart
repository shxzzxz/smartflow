import '../../../core/money/money.dart';
import '../enums/accounting_enums.dart';
import '../ledger/ledger_rules.dart';
import '../ledger/post_receipt.dart';
import 'transaction.dart';

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.subtype,
    this.parentId,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.sortOrder = 0,
    this.isHidden = false,
    this.archivedAt,
    this.systemKey,
    this.source = AccountSource.user,
  });

  final int id;
  final String name;
  final AccountType type;
  final AccountSubtype? subtype;
  final int? parentId;
  final Money balance;
  final String? iconKey;
  final String? note;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final int sortOrder;
  final bool isHidden;
  final DateTime? archivedAt;
  final SystemKey? systemKey;
  final AccountSource source;

  Account applyTransaction(Transaction transaction) {
    var account = this;
    for (final entry in transaction.entries) {
      if (entry.accountId != id) continue;
      account = account.applyEntryImpact(entry);
    }
    return account;
  }

  Account applyEntryImpact(ReceiptEntry entry) {
    final delta = balanceDeltaMinor(
      accountType: type,
      direction: entry.direction,
      amountMinor: entry.amount.minorUnits,
    );
    return copyWith(balance: Money(minorUnits: balance.minorUnits + delta));
  }

  Account removeEntryImpact(ReceiptEntry entry) {
    final delta = balanceDeltaMinor(
      accountType: type,
      direction: entry.direction,
      amountMinor: entry.amount.minorUnits,
    );
    return copyWith(balance: Money(minorUnits: balance.minorUnits - delta));
  }

  Account copyWith({
    String? name,
    AccountType? type,
    AccountSubtype? subtype,
    int? parentId,
    Money? balance,
    String? iconKey,
    String? note,
    Money? creditLimit,
    int? billingDay,
    int? repaymentDay,
    int? sortOrder,
    bool? isHidden,
    DateTime? archivedAt,
    SystemKey? systemKey,
    AccountSource? source,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      parentId: parentId ?? this.parentId,
      balance: balance ?? this.balance,
      iconKey: iconKey ?? this.iconKey,
      note: note ?? this.note,
      creditLimit: creditLimit ?? this.creditLimit,
      billingDay: billingDay ?? this.billingDay,
      repaymentDay: repaymentDay ?? this.repaymentDay,
      sortOrder: sortOrder ?? this.sortOrder,
      isHidden: isHidden ?? this.isHidden,
      archivedAt: archivedAt ?? this.archivedAt,
      systemKey: systemKey ?? this.systemKey,
      source: source ?? this.source,
    );
  }
}
