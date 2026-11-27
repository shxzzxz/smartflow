import 'dart:async';
import 'package:smartflow/application/analytics/analytics_command_api.dart';
import 'package:smartflow/application/analytics/analytics_query_api.dart';
import 'package:smartflow/application/analytics/asset_view/port/asset_view_preferences_store.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/analytics/valobj/analytics_error_code.dart';
import 'package:smartflow/domain/analytics/valobj/initial_asset_view_groups.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

class FakeAssetViewQueryService implements AssetViewQueryService {
  FakeAssetViewQueryService({
    List<AssetView>? views,
    this.statistics,
    Iterable<String> accountIds = const [],
    this.profiles = const {},
  }) : views =
           views ??
           [
             configureAssetViewAccounts(
               id: AssetView.defaultId,
               name: AssetView.defaultName,
               accountIds: accountIds,
               profiles: {
                 for (final id in accountIds)
                   id: profiles[id] ?? AccountProfileKind.fund,
               },
             ),
           ];
  final List<AssetView> views;
  final Map<String, AccountProfileKind> profiles;
  final AssetViewStatistics Function(AssetView)? statistics;
  final _changes = StreamController<List<AssetView>>.broadcast(sync: true);
  void notify() => _changes.add(List.unmodifiable(views));
  Future<void> close() => _changes.close();
  @override
  Future<AssetView?> findView(String id) async =>
      views.where((view) => view.id == id).firstOrNull;
  @override
  Future<List<AssetView>> findViews() async => List.unmodifiable(views);
  @override
  Stream<List<AssetView>> watchViews() async* {
    yield List.unmodifiable(views);
    yield* _changes.stream;
  }

  @override
  Stream<AssetViewStatistics> watchStatistics(AssetView view, DateTime asOf) =>
      Stream.value(
        statistics?.call(view) ??
            const AssetViewStatistics(
              assets: Money(minorUnits: 0),
              liabilities: Money(minorUnits: 0),
              netAssetChange: Money(minorUnits: 0),
            ),
      );
}

class MemoryAssetViewPreferences implements AssetViewPreferencesStore {
  MemoryAssetViewPreferences([this.selected]);
  String? selected;
  @override
  Future<String?> readSelectedViewId() async => selected;
  @override
  Future<void> saveSelectedViewId(String id) async {
    selected = id;
  }
}

class FakeAssetViewAppService implements AssetViewAppService {
  FakeAssetViewAppService(this.queries);
  final FakeAssetViewQueryService queries;
  final savedCommands = <SaveAssetViewCommand>[];
  final createdGroups = <({String viewId, String name})>[];
  final groupOrders = <({String viewId, List<String> ids})>[];
  final accountMoves =
      <
        ({String viewId, String accountId, String? groupId, List<String> ids})
      >[];
  bool failSave = false;
  int _next = 0;
  @override
  Future<AssetView> saveView(SaveAssetViewCommand command) async {
    savedCommands.add(command);
    if (failSave) {
      throw BusinessException(
        AnalyticsErrorCode.invalidReferences,
        message: '测试保存失败',
      );
    }
    final previous = command.id == null
        ? null
        : await queries.findView(command.id!);
    final view = configureAssetViewAccounts(
      id: command.id ?? 'created-view-${++_next}',
      name: command.name,
      accountIds: command.accountIds,
      source: previous ?? command.copyFrom,
      profiles: {
        for (final id in command.accountIds)
          id: queries.profiles[id] ?? AccountProfileKind.fund,
      },
      sortOrder: previous?.sortOrder ?? queries.views.length,
      version: (previous?.version ?? -1) + 1,
    );
    _replace(view);
    return view;
  }

  @override
  Future<void> deleteView(String id) async {
    queries.views.removeWhere((view) => view.id == id);
    queries.notify();
  }

  @override
  Future<void> reorderViews(List<String> orderedIds) async {
    final old = [...queries.views];
    queries.views
      ..clear()
      ..addAll([
        for (var index = 0; index < orderedIds.length; index++)
          old
              .firstWhere((view) => view.id == orderedIds[index])
              .copyWith(sortOrder: index),
      ]);
    queries.notify();
  }

  @override
  Future<void> createGroup(String viewId, String name) async {
    createdGroups.add((viewId: viewId, name: name));
    _update(
      viewId,
      (view) => view.addGroup(
        AssetViewGroup(id: 'created-group-${++_next}', name: name),
      ),
    );
  }

  @override
  Future<void> renameGroup(String viewId, String id, String name) async =>
      _update(viewId, (view) => view.renameGroup(id, name));
  @override
  Future<void> deleteGroup(String viewId, String id) async =>
      _update(viewId, (view) => view.deleteGroup(id));
  @override
  Future<void> reorderGroups(String viewId, List<String> ids) async {
    groupOrders.add((viewId: viewId, ids: ids));
    _update(viewId, (view) => view.reorderGroups(ids));
  }

  @override
  Future<void> moveAccountToGroup(
    String viewId,
    String accountId,
    String? groupId,
    List<String> ids,
  ) async {
    accountMoves.add((
      viewId: viewId,
      accountId: accountId,
      groupId: groupId,
      ids: ids,
    ));
    _update(
      viewId,
      (view) =>
          view.moveAccount(accountId, groupId).reorderAccounts(groupId, ids),
    );
  }

  void _update(String id, AssetView Function(AssetView) update) {
    final view = queries.views.firstWhere((view) => view.id == id);
    _replace(update(view).copyWith(version: view.version + 1));
  }

  void _replace(AssetView view) {
    final index = queries.views.indexWhere((item) => item.id == view.id);
    if (index < 0) {
      queries.views.add(view);
    } else {
      queries.views[index] = view;
    }
    queries.notify();
  }
}

class FakeAssetAccountQueryService implements AccountQueryService {
  FakeAssetAccountQueryService(this.accounts);
  final List<Account> accounts;
  @override
  Future<Account?> findAccountById(String id) async =>
      accounts.where((account) => account.id == id).firstOrNull;
  @override
  Future<List<Account>> findAccounts(Set<AccountType> types) async => accounts
      .where((account) => !account.isArchived && types.contains(account.type))
      .toList();
  @override
  Future<Map<String, Account>> findAccountsById() async => {
    for (final account in accounts) account.id: account,
  };
  @override
  Stream<List<Account>> watchAccounts(Set<AccountType> types) =>
      Stream.fromFuture(findAccounts(types));
  @override
  Stream<Map<String, Account>> watchAccountsById() =>
      Stream.fromFuture(findAccountsById());
  @override
  Stream<List<Account>> watchAccountsForUsage(AccountUsage usage) =>
      watchAccounts({AccountType.asset, AccountType.liability});
  @override
  Stream<List<Account>> watchCategories(AccountType type) =>
      watchAccounts({type});
}
