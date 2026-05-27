import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

const _asset = Account(
  id: 1,
  name: 'Cash',
  type: AccountType.asset,
  balance: Money(minorUnits: 10000),
);

const _liability = Account(
  id: 2,
  name: 'CreditCard',
  type: AccountType.liability,
  subtype: AccountSubtype.creditCard,
  balance: Money(minorUnits: 5000),
);

const _expense = Account(
  id: 3,
  name: 'Food',
  type: AccountType.expense,
  balance: Money(minorUnits: 0),
);

void main() {
  group('AccountTypeBehavior', () {
    test('isUserAccount only allows asset/liability', () {
      expect(AccountType.asset.isUserAccount, isTrue);
      expect(AccountType.liability.isUserAccount, isTrue);
      expect(AccountType.equity.isUserAccount, isFalse);
      expect(AccountType.income.isUserAccount, isFalse);
      expect(AccountType.expense.isUserAccount, isFalse);
    });

    test('isCategory only allows income/expense', () {
      expect(AccountType.income.isCategory, isTrue);
      expect(AccountType.expense.isCategory, isTrue);
      expect(AccountType.asset.isCategory, isFalse);
      expect(AccountType.liability.isCategory, isFalse);
      expect(AccountType.equity.isCategory, isFalse);
    });

    test('supportsManualBalance excludes reimbursement subtype on asset', () {
      expect(AccountType.asset.supportsManualBalance(null), isTrue);
      expect(
        AccountType.asset.supportsManualBalance(AccountSubtype.bankCard),
        isTrue,
      );
      expect(
        AccountType.asset.supportsManualBalance(AccountSubtype.reimbursement),
        isFalse,
      );
      expect(AccountType.liability.supportsManualBalance(null), isTrue);
      expect(AccountType.expense.supportsManualBalance(null), isFalse);
      expect(AccountType.income.supportsManualBalance(null), isFalse);
    });
  });

  group('Account.isArchived / supportsManualBalance', () {
    test('isArchived reflects archivedAt', () {
      expect(_asset.isArchived, isFalse);
      final archived = _asset.copyWith(archivedAt: DateTime(2026, 5));
      expect(archived.isArchived, isTrue);
    });

    test('supportsManualBalance delegates to AccountType', () {
      expect(_asset.supportsManualBalance, isTrue);
      expect(_liability.supportsManualBalance, isTrue);
      expect(_expense.supportsManualBalance, isFalse);
    });
  });

  group('Account.checkEditable', () {
    test('passes for active user account', () {
      expect(_asset.checkEditable(), isNull);
      expect(_liability.checkEditable(), isNull);
    });

    test('rejects archived account', () {
      final archived = _asset.copyWith(archivedAt: DateTime(2026, 5));
      expect(archived.checkEditable()?.code, 'account_archived');
    });

    test('rejects non-user account type', () {
      expect(_expense.checkEditable()?.code, 'account_type_not_editable');
    });
  });

  group('Account.changeProfile', () {
    test('null name keeps current instance', () {
      final result = _asset.changeProfile(const AccountProfilePatch());
      expect(result, isA<Success<Account>>());
      expect((result as Success<Account>).value.name, _asset.name);
    });

    test('blank name fails', () {
      final result = _asset.changeProfile(
        const AccountProfilePatch(name: '   '),
      );
      expect(
        (result as FailureResult<Account>).failure.code,
        'account_name_required',
      );
    });

    test('same trimmed name keeps current instance', () {
      final result = _asset.changeProfile(
        const AccountProfilePatch(name: 'Cash'),
      );
      expect((result as Success<Account>).value.name, _asset.name);
    });

    test('different trimmed name returns new instance with trimmed value', () {
      final result = _asset.changeProfile(
        const AccountProfilePatch(name: ' Wallet '),
      );
      final account = (result as Success<Account>).value;
      expect(account.name, 'Wallet');
      expect(account.id, _asset.id);
    });
  });

  group('Account.targetBalanceDeltaTo', () {
    test('archived fails', () {
      final archived = _asset.copyWith(archivedAt: DateTime(2026, 5));
      final result = archived.targetBalanceDeltaTo(
        const Money(minorUnits: 5000),
      );
      expect((result as FailureResult<Money>).failure.code, 'account_archived');
    });

    test('reimbursement asset is rejected', () {
      const reimbursement = Account(
        id: 5,
        name: 'Reimbursable',
        type: AccountType.asset,
        subtype: AccountSubtype.reimbursement,
        balance: Money(minorUnits: 0),
      );
      final result = reimbursement.targetBalanceDeltaTo(
        const Money(minorUnits: 1000),
      );
      expect(
        (result as FailureResult<Money>).failure.code,
        'account_target_balance_not_supported',
      );
    });

    test('negative target is rejected', () {
      final result = _asset.targetBalanceDeltaTo(const Money(minorUnits: -100));
      expect(
        (result as FailureResult<Money>).failure.code,
        'account_target_balance_negative',
      );
    });

    test('zero delta is rejected', () {
      final result = _asset.targetBalanceDeltaTo(
        const Money(minorUnits: 10000),
      );
      expect(
        (result as FailureResult<Money>).failure.code,
        'balance_adjustment_zero_delta',
      );
    });

    test('positive delta succeeds', () {
      final result = _asset.targetBalanceDeltaTo(
        const Money(minorUnits: 15000),
      );
      expect((result as Success<Money>).value, const Money(minorUnits: 5000));
    });

    test('negative delta succeeds', () {
      final result = _asset.targetBalanceDeltaTo(const Money(minorUnits: 6000));
      expect((result as Success<Money>).value, const Money(minorUnits: -4000));
    });
  });

  group('Account.checkValidCategoryParent', () {
    const parent = Account(
      id: 10,
      name: 'Food',
      type: AccountType.expense,
      balance: Money(minorUnits: 0),
    );

    test('passes when active / type matches / parentId == null', () {
      expect(parent.checkValidCategoryParent(AccountType.expense), isNull);
    });

    test('rejects archived parent', () {
      final archived = parent.copyWith(archivedAt: DateTime(2026, 5));
      expect(
        archived.checkValidCategoryParent(AccountType.expense)?.code,
        'category_parent_archived',
      );
    });

    test('rejects type mismatch', () {
      expect(
        parent.checkValidCategoryParent(AccountType.income)?.code,
        'category_parent_type_mismatch',
      );
    });

    test('rejects when parent itself has a parent (depth limit)', () {
      final nested = parent.copyWith(parentId: 99);
      expect(
        nested.checkValidCategoryParent(AccountType.expense)?.code,
        'category_depth_exceeded',
      );
    });
  });
}
