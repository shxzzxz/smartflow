import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../enums/accounting_enums.dart';

class CreateAccountCommand {
  const CreateAccountCommand({
    required this.name,
    required this.type,
    this.currencyCode = Money.defaultCurrency,
    this.openingBalance = const Money(minorUnits: 0),
    this.subtype,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final String name;
  final AccountType type;
  final String currencyCode;
  final Money openingBalance;
  final AccountSubtype? subtype;
  final String? iconKey;
  final String? note;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final int sortOrder;
  final bool isHidden;
}

class EditAccountCommand {
  const EditAccountCommand({
    required this.id,
    this.name,
    this.sortOrder,
    this.isHidden,
    this.subtype,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.targetBalance,
  });

  final int id;
  final String? name;
  final int? sortOrder;
  final bool? isHidden;
  final Patch<AccountSubtype>? subtype;
  final Patch<String>? iconKey;
  final Patch<String>? note;
  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final Money? targetBalance;
}
