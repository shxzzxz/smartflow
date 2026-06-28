import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';

abstract interface class CreditAccountQueryService {
  Stream<Map<String, CreditLiabilityAccount>>
  watchCreditLiabilityAccountsByAccountId();

  Future<CreditLiabilityAccount?> findByAccountId(String accountId);
}

class CreditAccountQueryServiceImpl implements CreditAccountQueryService {
  const CreditAccountQueryServiceImpl({
    required CreditAccountRepository creditAccounts,
  }) : _creditAccounts = creditAccounts;

  final CreditAccountRepository _creditAccounts;

  @override
  Stream<Map<String, CreditLiabilityAccount>>
  watchCreditLiabilityAccountsByAccountId() {
    return _creditAccounts.watchByAccountId();
  }

  @override
  Future<CreditLiabilityAccount?> findByAccountId(String accountId) {
    return _creditAccounts.findByAccountId(accountId);
  }
}
