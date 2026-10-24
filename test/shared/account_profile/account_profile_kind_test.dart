import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/shared/account_profile/account_selection_policy.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  test('defines the classification and owner for every account profile', () {
    const expectations = [
      (
        AccountProfileKind.fund,
        AccountType.asset,
        AccountSubtype.fund,
        AccountProfileOwner.ledger,
      ),
      (
        AccountProfileKind.reimbursement,
        AccountType.asset,
        AccountSubtype.receivable,
        AccountProfileOwner.ledger,
      ),
      (
        AccountProfileKind.receivable,
        AccountType.asset,
        AccountSubtype.receivable,
        AccountProfileOwner.ledger,
      ),
      (
        AccountProfileKind.payable,
        AccountType.liability,
        AccountSubtype.payable,
        AccountProfileOwner.ledger,
      ),
      (
        AccountProfileKind.credit,
        AccountType.liability,
        AccountSubtype.payable,
        AccountProfileOwner.credit,
      ),
      (
        AccountProfileKind.loan,
        AccountType.liability,
        AccountSubtype.loan,
        AccountProfileOwner.credit,
      ),
    ];

    for (final (profile, type, subtype, owner) in expectations) {
      expect(profile.accountType, type);
      expect(profile.accountSubtype, subtype);
      expect(profile.owner, owner);
      expect(
        isAccountProfileCompatible(
          type: type,
          subtype: subtype,
          profileKey: profile.key,
        ),
        isTrue,
      );
    }
  });

  test('rejects missing, unknown, or incompatible account profiles', () {
    for (final profileKey in [null, '', 'unknown.profile']) {
      expect(
        isAccountProfileCompatible(
          type: AccountType.asset,
          subtype: AccountSubtype.fund,
          profileKey: profileKey,
        ),
        isFalse,
      );
    }
    expect(
      isAccountProfileCompatible(
        type: AccountType.asset,
        subtype: AccountSubtype.receivable,
        profileKey: AccountProfileKind.fund.key,
      ),
      isFalse,
    );
  });

  test('all receivable profiles support receivable transaction roles', () {
    final accounts = [
      _receivable(AccountProfileKind.reimbursement),
      _receivable(AccountProfileKind.receivable),
    ];
    const purposes = [
      AccountSelectionPurpose.advanceReceivable,
      AccountSelectionPurpose.ordinaryReceivable,
      AccountSelectionPurpose.receivable,
    ];

    for (final account in accounts) {
      for (final purpose in purposes) {
        expect(accountMatchesSelectionPurpose(account, purpose), isTrue);
      }
      expect(
        accountMatchesSelectionPurpose(account, AccountSelectionPurpose.fund),
        isFalse,
      );
    }
  });
}

Account _receivable(AccountProfileKind kind) => Account(
  id: kind.key,
  name: kind.label,
  type: AccountType.asset,
  subtype: AccountSubtype.receivable,
  profileKey: kind.key,
  balance: Money.zero(),
);
