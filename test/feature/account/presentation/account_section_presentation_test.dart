import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/presentation/account_section_presentation.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test(
    'active sections retain empty groups and calculate their net amount',
    () {
      final sections = buildActiveAccountSections(
        [
          _account(id: 'asset', groupId: 'daily', balanceMinor: 10000),
          _account(
            id: 'liability',
            groupId: 'daily',
            kind: AccountProfileKind.credit,
            balanceMinor: 2500,
          ),
        ],
        [
          AccountGroup(id: 'daily', name: '日常'),
          AccountGroup(id: 'empty', name: '空分组'),
        ],
      );

      expect(sections.map((section) => section.title), ['日常', '空分组']);
      expect(sections.first.netTotal.minorUnits, 7500);
      expect(sections.last.accounts, isEmpty);
    },
  );

  test('archived sections omit empty groups and collect orphaned accounts', () {
    final sections = buildArchivedAccountSections(
      [
        _account(id: 'credit', groupId: 'credit'),
        _account(id: 'orphan', groupId: 'removed'),
        _account(id: 'ungrouped'),
      ],
      [
        AccountGroup(id: 'empty', name: '空分组'),
        AccountGroup(id: 'credit', name: '信用'),
      ],
    );

    expect(sections.map((section) => section.title), ['信用', '未分组']);
    expect(sections.last.accounts.map((account) => account.id), [
      'orphan',
      'ungrouped',
    ]);
  });
}

AccountView _account({
  required String id,
  String? groupId,
  AccountProfileKind kind = AccountProfileKind.fund,
  int balanceMinor = 0,
}) {
  return AccountView(
    id: id,
    name: id,
    kind: kind,
    balance: Money(minorUnits: balanceMinor),
    iconKey: null,
    isArchived: false,
    groupId: groupId,
  );
}
