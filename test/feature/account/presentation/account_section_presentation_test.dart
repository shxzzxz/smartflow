import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/analytics/analytics_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/presentation/account_section_presentation.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test(
    'sections use the view group and account order and calculate neutral net totals',
    () {
      final view = AssetView(
        id: 'daily',
        name: '日常',
        accountIds: ['liability', 'asset'],
        groups: [
          AssetViewGroup(id: 'daily', name: '日常'),
          AssetViewGroup(id: 'empty', name: '空分组'),
        ],
        accountGroupIds: {'asset': 'daily', 'liability': 'daily'},
      );
      final sections = buildActiveAccountSections([
        _account('asset', balance: 10000),
        _account('outside', balance: 99999),
        _account('liability', kind: AccountProfileKind.credit, balance: 2500),
      ], view);
      expect(sections.map((section) => section.title), ['日常', '空分组']);
      expect(sections.first.accounts.map((account) => account.id), [
        'liability',
        'asset',
      ]);
      expect(sections.first.netTotal.minorUnits, 7500);
      expect(sections.last.accounts, isEmpty);
    },
  );

  test(
    'archived sections follow their view and keep accounts from removed groups ungrouped',
    () {
      final view = AssetView(
        id: 'archive-view',
        name: '日常',
        accountIds: ['credit', 'removed', 'ungrouped'],
        groups: [
          AssetViewGroup(id: 'empty', name: '空分组'),
          AssetViewGroup(id: 'credit', name: '信用'),
          AssetViewGroup(id: 'removed-group', name: '旧分组'),
        ],
        accountGroupIds: {'credit': 'credit', 'removed': 'removed-group'},
      ).deleteGroup('removed-group');
      final sections = buildArchivedAccountSections([
        _account('credit', archived: true),
        _account('removed', archived: true),
        _account('ungrouped', archived: true),
        _account('outside', archived: true),
      ], view);
      expect(sections.map((section) => section.title), ['信用', '未分组']);
      expect(sections.last.accounts.map((account) => account.id), [
        'removed',
        'ungrouped',
      ]);
    },
  );
}

AccountView _account(
  String id, {
  AccountProfileKind kind = AccountProfileKind.fund,
  int balance = 0,
  bool archived = false,
}) => AccountView(
  id: id,
  name: id,
  kind: kind,
  balance: Money(minorUnits: balance),
  iconKey: null,
  isArchived: archived,
);
