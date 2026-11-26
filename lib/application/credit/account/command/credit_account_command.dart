import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';

class CreateCreditLiabilityAccountCommand {
  const CreateCreditLiabilityAccountCommand({
    this.transactionBookId,
    required this.name,
    required this.kind,
    this.openingBalance = const Money(minorUnits: 0),
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext = true,
    this.iconKey,
    this.note,
    this.isHidden = false,
  });

  final String? transactionBookId;
  final String name;
  final CreditLiabilityAccountKind kind;
  final Money openingBalance;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
  final String? iconKey;
  final String? note;
  final bool isHidden;
}

class EditCreditLiabilityAccountCommand {
  const EditCreditLiabilityAccountCommand({
    this.transactionBookId,
    required this.accountId,
    this.name,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext,
    this.targetBalance,
  });

  final String? transactionBookId;
  final String accountId;
  final String? name;
  final Patch<String>? iconKey;
  final Patch<String>? note;
  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final bool? billingDayToNext;
  final Money? targetBalance;
}

class DeleteCreditLiabilityAccountCommand {
  const DeleteCreditLiabilityAccountCommand({required this.accountId});

  final String accountId;
}
