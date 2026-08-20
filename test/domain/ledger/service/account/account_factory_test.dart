import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/ledger/service/account/account_factory.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

void main() {
  const factory = AccountFactory();

  test('creates every supported ledger account classification', () {
    const classifications = [
      (AccountType.asset, AccountSubtype.fund),
      (AccountType.asset, AccountSubtype.receivable),
      (AccountType.liability, AccountSubtype.payable),
      (AccountType.liability, AccountSubtype.loan),
    ];

    for (final (type, subtype) in classifications) {
      final account = factory.createUserAccount(
        id: subtype.name,
        name: subtype.name,
        type: type,
        subtype: subtype,
        profileKey: 'opaque-product-metadata',
      );
      expect(account.type, type);
      expect(account.subtype, subtype);
      expect(account.profileKey, 'opaque-product-metadata');
    }
  });

  test('rejects a missing ledger classification', () {
    expect(
      () => factory.createUserAccount(
        id: 'missing',
        name: 'missing',
        type: AccountType.asset,
      ),
      throwsA(isA<BusinessException>()),
    );
  });
}
