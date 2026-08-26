import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';

/// 按 system_key 返回固定 id 的解析器,让测试无需建库也能过账。
class FakeSystemAccountResolver implements ReceivableSystemAccountResolver {
  const FakeSystemAccountResolver({
    this.openingBalance = 'system-opening-balance',
    this.reimbursementGapIncome = 'system-gap-income',
    this.interestExpense = 'system-interest-expense',
    this.feeExpense = 'system-fee-expense',
    this.discountIncome = 'system-discount-income',
    this.interestIncome = 'system-interest-income',
    this.badDebtExpense = 'system-bad-debt-expense',
    this.debtReliefIncome = 'system-debt-relief-income',
    this.ghostAccount = 'system-ghost',
  });

  final String openingBalance;
  final String reimbursementGapIncome;
  final String interestExpense;
  final String feeExpense;
  final String discountIncome;
  final String interestIncome;
  final String badDebtExpense;
  final String debtReliefIncome;
  final String ghostAccount;

  @override
  Future<String> resolveOpeningBalance() async => openingBalance;

  @override
  Future<String> resolveReimbursementGapIncome() async =>
      reimbursementGapIncome;

  @override
  Future<String> resolveInterestExpense() async => interestExpense;

  @override
  Future<String> resolveFeeExpense() async => feeExpense;

  @override
  Future<String> resolveDiscountIncome() async => discountIncome;

  @override
  Future<String> resolveInterestIncome() async => interestIncome;

  @override
  Future<String> resolveBadDebtExpense() async => badDebtExpense;

  @override
  Future<String> resolveDebtReliefIncome() async => debtReliefIncome;

  @override
  Future<String> resolveGhostAccount() async => ghostAccount;
}
