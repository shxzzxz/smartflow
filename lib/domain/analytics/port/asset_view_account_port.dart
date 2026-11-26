import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../shared/account_profile/account_profile_kind.dart';

class AssetViewAccountDraft {
  const AssetViewAccountDraft({
    required this.transactionBookId,
    required this.profile,
    required this.name,
    required this.openingBalance,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext = true,
  });
  final String transactionBookId;
  final AccountProfileKind profile;
  final String name;
  final Money openingBalance;
  final String? iconKey;
  final String? note;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
}

class AssetViewAccountEdit {
  const AssetViewAccountEdit({
    required this.transactionBookId,
    required this.accountId,
    required this.profile,
    required this.name,
    required this.iconKey,
    required this.note,
    this.targetBalance,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext,
  });
  final String transactionBookId;
  final String accountId;
  final AccountProfileKind profile;
  final String name;
  final Patch<String> iconKey;
  final Patch<String> note;
  final Money? targetBalance;
  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final bool? billingDayToNext;
}

abstract interface class AssetViewAccountPort {
  Future<String> createAccount(AssetViewAccountDraft draft);
  Future<void> editAccount(AssetViewAccountEdit edit);
}
