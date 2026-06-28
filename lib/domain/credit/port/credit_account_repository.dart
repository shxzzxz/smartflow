import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../entity/credit_liability_account.dart';
import '../valobj/bill_period.dart';
import '../valobj/credit_account_enums.dart';

class CreditLiabilityAccountDraft {
  const CreditLiabilityAccountDraft({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.billingDayToNext,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
  });

  final String id;
  final String accountId;
  final CreditLiabilityAccountKind kind;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final BillPeriod? billingStartPeriod;
  final bool billingDayToNext;
}

class CreditLiabilityAccountPersistencePatch {
  const CreditLiabilityAccountPersistencePatch({
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
    this.billingDayToNext,
  });

  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final Patch<BillPeriod>? billingStartPeriod;
  final bool? billingDayToNext;
}

abstract interface class CreditAccountRepository {
  Future<CreditLiabilityAccount?> findByAccountId(String accountId);

  Stream<Map<String, CreditLiabilityAccount>> watchByAccountId();

  Future<void> insert(CreditLiabilityAccountDraft draft);

  Future<void> update(
    String accountId,
    CreditLiabilityAccountPersistencePatch patch,
  );
}
