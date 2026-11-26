// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/analytics/analytics_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/account/view_model/archived_accounts_view_model.dart';
import 'package:smartflow/feature/account/view_model/asset_views_provider.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('stays loading while an account source is not ready', () {
    final container = _container(
      accounts: const AsyncLoading(),
      view: const AsyncLoading(),
    );
    expect(
      container.read(archivedAccountsViewModelProvider),
      isA<ArchivedAccountsPageLoading>(),
    );
  });
  test('maps an archived account source failure to a safe UI error', () {
    final container = _container(
      accounts: AsyncError(StateError('database details'), StackTrace.empty),
      view: const AsyncLoading(),
    );
    final state =
        container.read(archivedAccountsViewModelProvider)
            as ArchivedAccountsPageError;
    expect(state.error.code, 'account.archived.load_failed');
    expect(state.error.message, '已归档账户加载失败，请稍后重试');
    expect(state.error.message, isNot(contains('database details')));
  });
  test('maps a view source failure to a safe UI error', () {
    final container = _container(
      accounts: const AsyncData([]),
      view: AsyncError(StateError('view query details'), StackTrace.empty),
    );
    final state =
        container.read(archivedAccountsViewModelProvider)
            as ArchivedAccountsPageError;
    expect(state.error.code, 'account.archived.load_failed');
    expect(state.error.message, isNot(contains('view query details')));
  });
  test('loaded archived sections follow the view and remain immutable', () {
    final view = AssetView(
      id: 'view',
      name: '归档视图',
      accountIds: ['card', 'ungrouped'],
      groups: [AssetViewGroup(id: 'credit', name: '信用')],
      accountGroupIds: {'card': 'credit'},
    );
    final container = _container(
      accounts: AsyncData([
        _account('card'),
        _account('ungrouped'),
        _account('outside'),
      ]),
      view: AsyncData(view),
    );
    final state =
        container.read(archivedAccountsViewModelProvider)
            as ArchivedAccountsPageLoaded;
    expect(state.sections.map((section) => section.title), ['信用', '未分组']);
    expect(() => state.sections.clear(), throwsUnsupportedError);
    expect(() => state.sections.first.accounts.clear(), throwsUnsupportedError);
  });
}

ProviderContainer _container({
  required AsyncValue<List<AccountView>> accounts,
  required AsyncValue<AssetView> view,
}) {
  final container = ProviderContainer(
    overrides: [
      archivedAccountViewsProvider.overrideWithValue(accounts),
      selectedAssetViewProvider.overrideWithValue(view),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AccountView _account(String id) => AccountView(
  id: id,
  name: id,
  kind: AccountProfileKind.credit,
  balance: Money.zero(),
  iconKey: null,
  isArchived: true,
);
