import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../entity/credit_liability_account.dart';
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
  });

  final String id;
  final String accountId;
  final CreditLiabilityAccountKind kind;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
}

class CreditLiabilityAccountPersistencePatch {
  const CreditLiabilityAccountPersistencePatch({
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext,
  });

  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final bool? billingDayToNext;
}

abstract interface class CreditAccountRepository {
  Future<CreditLiabilityAccount?> findByAccountId(String accountId);

  Future<List<CreditLiabilityAccount>> listAll();

  Stream<Map<String, CreditLiabilityAccount>> watchByAccountId();

  Future<void> insert(CreditLiabilityAccountDraft draft);

  Future<void> update(
    String accountId,
    CreditLiabilityAccountPersistencePatch patch,
  );

  Future<void> delete(String accountId);
}
