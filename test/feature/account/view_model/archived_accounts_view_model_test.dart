// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/account/view_model/archived_accounts_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('stays loading while an account source is not ready', () {
    final container = _container(
      accounts: const AsyncValue.loading(),
      groups: const Stream.empty(),
    );

    expect(
      container.read(archivedAccountsViewModelProvider),
      isA<ArchivedAccountsPageLoading>(),
    );
  });

  test('maps an archived account source failure to a safe UI error', () {
    final container = _container(
      accounts: AsyncValue.error(
        StateError('database details'),
        StackTrace.empty,
      ),
      groups: const Stream.empty(),
    );

    final state = container.read(archivedAccountsViewModelProvider);

    expect(state, isA<ArchivedAccountsPageError>());
    final error = (state as ArchivedAccountsPageError).error;
    expect(error.code, 'account.archived.load_failed');
    expect(error.message, '已归档账户加载失败，请稍后重试');
    expect(error.message, isNot(contains('database details')));
  });

  test('maps an account group source failure to a safe UI error', () async {
    final container = _container(
      accounts: const AsyncValue.data([]),
      groups: Stream.error(StateError('group query details')),
    );
    final sub = container.listen(archivedAccountsViewModelProvider, (_, _) {});
    addTearDown(sub.close);

    await _flush();

    final state = container.read(archivedAccountsViewModelProvider);
    expect(state, isA<ArchivedAccountsPageError>());
    final error = (state as ArchivedAccountsPageError).error;
    expect(error.code, 'account.archived.load_failed');
    expect(error.message, isNot(contains('group query details')));
  });

  test('maps loaded sources to immutable archived sections', () async {
    final container = _container(
      accounts: AsyncValue.data([
        _account(id: 'card', groupId: 'credit'),
        _account(id: 'orphan', groupId: 'removed'),
      ]),
      groups: Stream.value([AccountGroup(id: 'credit', name: '信用')]),
    );
    final sub = container.listen(archivedAccountsViewModelProvider, (_, _) {});
    addTearDown(sub.close);

    await _flush();

    final state = container.read(archivedAccountsViewModelProvider);
    expect(state, isA<ArchivedAccountsPageLoaded>());
    final loaded = state as ArchivedAccountsPageLoaded;
    expect(loaded.sections.map((section) => section.title), ['信用', '未分组']);
    expect(() => loaded.sections.clear(), throwsUnsupportedError);
    expect(
      () => loaded.sections.first.accounts.clear(),
      throwsUnsupportedError,
    );
  });
}

ProviderContainer _container({
  required AsyncValue<List<AccountView>> accounts,
  required Stream<List<AccountGroup>> groups,
}) {
  final container = ProviderContainer(
    overrides: [
      archivedAccountViewsProvider.overrideWith((ref) => accounts),
      accountGroupsProvider.overrideWith((ref) => groups),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AccountView _account({required String id, required String groupId}) {
  return AccountView(
    id: id,
    name: id,
    kind: AccountProfileKind.credit,
    balance: Money.zero(),
    iconKey: null,
    isArchived: true,
    groupId: groupId,
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
