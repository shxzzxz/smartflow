import 'package:drift/drift.dart';

import '../../../domain/accounting/enums/accounting_enums.dart';
import '../../../domain/accounting/repositories/system_account_resolver.dart';
import '../../app_database.dart';

class DriftSystemAccountResolver implements SystemAccountResolver {
  const DriftSystemAccountResolver(this._database);

  final AppDatabase _database;

  @override
  Future<int> resolveOpeningBalance({String currencyCode = 'CNY'}) {
    return _resolve(
      systemKey: SystemKey.openingBalance,
      accountType: AccountType.equity,
      defaultName: '系统期初余额($currencyCode)',
      currencyCode: currencyCode,
    );
  }

  @override
  Future<int> resolveReimbursementGapIncome({String currencyCode = 'CNY'}) {
    return _resolve(
      systemKey: SystemKey.reimbursementGapIncome,
      accountType: AccountType.income,
      defaultName: '报销差额收入',
      currencyCode: currencyCode,
    );
  }

  @override
  Future<int> resolveDebtInterestExpense({String currencyCode = 'CNY'}) {
    return _resolve(
      systemKey: SystemKey.debtInterestExpense,
      accountType: AccountType.expense,
      defaultName: '利息',
      currencyCode: currencyCode,
    );
  }

  @override
  Future<int> resolveDebtFeeExpense({String currencyCode = 'CNY'}) {
    return _resolve(
      systemKey: SystemKey.debtFeeExpense,
      accountType: AccountType.expense,
      defaultName: '手续费',
      currencyCode: currencyCode,
    );
  }

  @override
  Future<int> resolveDiscountIncome({String currencyCode = 'CNY'}) {
    return _resolve(
      systemKey: SystemKey.discountIncome,
      accountType: AccountType.income,
      defaultName: '优惠',
      currencyCode: currencyCode,
    );
  }

  @override
  Future<int> resolveGhostAccount({String currencyCode = 'CNY'}) {
    return _resolve(
      systemKey: SystemKey.ghostAccount,
      accountType: AccountType.equity,
      defaultName: '幽灵账户',
      currencyCode: currencyCode,
    );
  }

  Future<int> _resolve({
    required SystemKey systemKey,
    required AccountType accountType,
    required String defaultName,
    required String currencyCode,
  }) async {
    final existing =
        await (_database.select(_database.accounts)..where(
          (account) =>
              account.systemKey.equalsValue(systemKey) &
              account.currencyCode.equals(currencyCode),
        )).getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }

    throw StateError(
      'Missing builtin account "$defaultName" '
      '($systemKey, $accountType, $currencyCode).',
    );
  }
}
