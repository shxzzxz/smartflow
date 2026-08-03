import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';

class CreateCreditLiabilityAccountCommand {
  const CreateCreditLiabilityAccountCommand({
    required this.name,
    required this.kind,
    this.openingBalance = const Money(minorUnits: 0),
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext = true,
    this.iconKey,
    this.note,
    this.groupId,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final String name;
  final CreditLiabilityAccountKind kind;
  final Money openingBalance;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
  final String? iconKey;
  final String? note;
  final String? groupId;
  final int sortOrder;
  final bool isHidden;
}

class EditCreditLiabilityAccountCommand {
  const EditCreditLiabilityAccountCommand({
    required this.accountId,
    this.name,
    this.iconKey,
    this.note,
    this.groupId,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext,
    this.targetBalance,
  });

  final String accountId;
  final String? name;
  final Patch<String>? iconKey;
  final Patch<String>? note;
  final Patch<String>? groupId;
  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final bool? billingDayToNext;
  final Money? targetBalance;
}
