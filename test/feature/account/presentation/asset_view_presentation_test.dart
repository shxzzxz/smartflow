import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/analytics/analytics_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/presentation/asset_view_presentation.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  final accounts = [
    _account('cash', AccountProfileKind.fund, 10000),
    _account('other-cash', AccountProfileKind.fund, 20000),
    _account('credit', AccountProfileKind.credit, 5000),
    _account('zero', AccountProfileKind.prepaidExpense, 0),
  ];
  final view = AssetView(
    id: 'daily',
    name: '日常',
    accountIds: ['cash', 'credit', 'zero'],
    groups: [
      AssetViewGroup(id: 'family', name: '家庭'),
      AssetViewGroup(id: 'prepaid', name: '预付'),
      AssetViewGroup(id: 'empty', name: '空组'),
    ],
    accountGroupIds: {'cash': 'family', 'credit': 'family', 'zero': 'prepaid'},
  );

  test('list cards use the selected view scope and type filter', () {
    final all = buildAssetViewLayout(view, accounts, AssetAccountFilter.all);
    expect(all.sections.map((section) => section.id), ['family', 'prepaid']);
    expect(all.sections.first.accounts.map((account) => account.id), [
      'cash',
      'credit',
    ]);
    final asset = buildAssetViewLayout(
      view,
      accounts,
      AssetAccountFilter.asset,
    );
    expect(asset.sections.first.accounts.map((account) => account.id), [
      'cash',
    ]);
    expect(asset.sections.last.accounts.single.id, 'zero');
    final liability = buildAssetViewLayout(
      view,
      accounts,
      AssetAccountFilter.liability,
    );
    expect(liability.sections.single.accounts.single.id, 'credit');
  });

  test('the same account follows each view own grouping and order', () {
    final second = AssetView(
      id: 'second',
      name: '另一个视图',
      accountIds: ['credit', 'cash'],
      groups: [AssetViewGroup(id: 'spare', name: '备用')],
      accountGroupIds: {'cash': 'spare', 'credit': 'spare'},
    );
    final layout = buildAssetViewLayout(
      second,
      accounts,
      AssetAccountFilter.all,
    );
    expect(layout.sections.single.title, '备用');
    expect(layout.sections.single.accounts.map((account) => account.id), [
      'credit',
      'cash',
    ]);
    expect(
      buildAssetViewLayout(
        view,
        accounts,
        AssetAccountFilter.all,
      ).sections.first.title,
      '家庭',
    );
  });

  test(
    'empty groups disappear while zero balance accounts remain reachable',
    () {
      final zero = view.copyWith(
        accountIds: ['zero'],
        accountGroupIds: {'zero': 'prepaid'},
      );
      final layout = buildAssetViewLayout(
        zero,
        accounts,
        AssetAccountFilter.all,
      );
      expect(layout.sections.map((section) => section.id), ['prepaid']);
      expect(layout.sections.single.accounts.single.id, 'zero');
    },
  );

  test('sorting a visible subset preserves hidden account positions', () {
    expect(
      mergeVisibleOrder(['a', 'archived', 'b', 'other-type'], ['b', 'a']),
      ['b', 'archived', 'a', 'other-type'],
    );
  });
}

AccountView _account(String id, AccountProfileKind kind, int balance) =>
    AccountView(
      id: id,
      name: id,
      kind: kind,
      balance: Money(minorUnits: balance),
      iconKey: null,
      isArchived: false,
    );
