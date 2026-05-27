import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/data/app_database.dart';

class DriftSystemAccountResolver implements SystemAccountResolver {
  const DriftSystemAccountResolver(this._database);

  final AppDatabase _database;

  @override
  Future<String> resolveOpeningBalance() {
    return _resolve(
      systemKey: SystemKey.openingBalance,
      accountType: AccountType.equity,
      defaultName: '系统期初余额',
    );
  }

  @override
  Future<String> resolveReimbursementGapIncome() {
    return _resolve(
      systemKey: SystemKey.reimbursementGapIncome,
      accountType: AccountType.income,
      defaultName: '报销差额收入',
    );
  }

  @override
  Future<String> resolveDebtInterestExpense() {
    return _resolve(
      systemKey: SystemKey.debtInterestExpense,
      accountType: AccountType.expense,
      defaultName: '利息',
    );
  }

  @override
  Future<String> resolveDebtFeeExpense() {
    return _resolve(
      systemKey: SystemKey.debtFeeExpense,
      accountType: AccountType.expense,
      defaultName: '手续费',
    );
  }

  @override
  Future<String> resolveDiscountIncome() {
    return _resolve(
      systemKey: SystemKey.discountIncome,
      accountType: AccountType.income,
      defaultName: '优惠',
    );
  }

  @override
  Future<String> resolveGhostAccount() {
    return _resolve(
      systemKey: SystemKey.ghostAccount,
      accountType: AccountType.equity,
      defaultName: '幽灵账户',
    );
  }

  Future<String> _resolve({
    required SystemKey systemKey,
    required AccountType accountType,
    required String defaultName,
  }) async {
    final existing =
        await (_database.select(_database.accounts)..where(
          (account) => account.systemKey.equalsValue(systemKey),
        )).getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }

    throw StateError(
      'Missing builtin account "$defaultName" '
      '($systemKey, $accountType).',
    );
  }
}
