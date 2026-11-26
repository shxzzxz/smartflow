import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/analytics/entity/asset_view.dart';
import '../../../../domain/analytics/port/asset_view_repository.dart';
import '../../../../domain/analytics/port/asset_view_references_port.dart';
import '../../../../domain/analytics/valobj/analytics_error_code.dart';
import '../../../../domain/analytics/valobj/initial_asset_view_groups.dart';
import '../../../shared/transaction_runner.dart';
import 'asset_view_command.dart';

abstract interface class AssetViewAppService {
  Future<AssetView> saveView(SaveAssetViewCommand command);
  Future<void> deleteView(String id);
  Future<void> reorderViews(List<String> orderedIds);
  Future<void> createGroup(String viewId, String name);
  Future<void> renameGroup(String viewId, String groupId, String name);
  Future<void> deleteGroup(String viewId, String groupId);
  Future<void> reorderGroups(String viewId, List<String> orderedIds);
  Future<void> moveAccountToGroup(
    String viewId,
    String accountId,
    String? groupId,
    List<String> orderedAccountIds,
  );
}

class AssetViewAppServiceImpl implements AssetViewAppService {
  const AssetViewAppServiceImpl({
    required AssetViewRepository views,
    required AssetViewReferencesPort references,
    required TransactionRunner transactionRunner,
    required IdGenerator ids,
  }) : _views = views,
       _references = references,
       _runner = transactionRunner,
       _ids = ids;

  final AssetViewRepository _views;
  final AssetViewReferencesPort _references;
  final TransactionRunner _runner;
  final IdGenerator _ids;

  @override
  Future<AssetView> saveView(SaveAssetViewCommand command) =>
      _runner.run(() async {
        final views = await _views.findViews();
        final previous = command.id == null
            ? null
            : await _requireView(command.id!);
        if (previous != null && command.expectedVersion != previous.version) {
          throw BusinessException(AnalyticsErrorCode.concurrentUpdate);
        }
        final references = await _references.readReferences();
        final added = command.accountIds.toSet().difference(
          previous?.accountIds.toSet() ?? {},
        );
        if (!references.accounts.keys.toSet().containsAll(added)) {
          throw BusinessException(AnalyticsErrorCode.invalidReferences);
        }
        final view = configureAssetViewAccounts(
          id: previous?.id ?? _ids.newId(),
          name: command.name,
          accountIds: command.accountIds,
          source: previous ?? command.copyFrom,
          profiles: {
            for (final entry in references.accounts.entries)
              entry.key: entry.value.profile,
          },
          version: previous?.version ?? 0,
          sortOrder:
              previous?.sortOrder ??
              views.fold(
                    0,
                    (order, view) =>
                        view.sortOrder > order ? view.sortOrder : order,
                  ) +
                  1,
        );
        if (views.any(
          (other) => other.id != view.id && other.name == view.name,
        )) {
          throw BusinessException(AnalyticsErrorCode.nameExists);
        }
        if (previous == null) {
          await _views.create(view);
          return view;
        }
        await _views.save(view);
        return view.copyWith(version: view.version + 1);
      });

  @override
  Future<void> deleteView(String id) => _runner.run(() async {
    final view = await _requireView(id);
    if (view.isBuiltin) throw BusinessException(AnalyticsErrorCode.builtinView);
    await _views.delete(id);
  });

  @override
  Future<void> reorderViews(List<String> orderedIds) => _runner.run(() async {
    final views = await _views.findViews();
    if (orderedIds.isEmpty ||
        orderedIds.first != AssetView.defaultId ||
        orderedIds.length != views.length ||
        orderedIds.toSet().length != views.length ||
        !orderedIds.toSet().containsAll(views.map((view) => view.id))) {
      throw BusinessException(AnalyticsErrorCode.invalidView);
    }
    for (var index = 0; index < orderedIds.length; index++) {
      final view = views.firstWhere((view) => view.id == orderedIds[index]);
      if (view.sortOrder != index) {
        await _views.save(view.copyWith(sortOrder: index));
      }
    }
  });

  @override
  Future<void> createGroup(String viewId, String name) => _update(
    viewId,
    (view) => view.addGroup(AssetViewGroup(id: _ids.newId(), name: name)),
  );
  @override
  Future<void> renameGroup(String viewId, String groupId, String name) =>
      _update(viewId, (view) => view.renameGroup(groupId, name));
  @override
  Future<void> deleteGroup(String viewId, String groupId) =>
      _update(viewId, (view) => view.deleteGroup(groupId));
  @override
  Future<void> reorderGroups(String viewId, List<String> orderedIds) =>
      _update(viewId, (view) => view.reorderGroups(orderedIds));
  @override
  Future<void> moveAccountToGroup(
    String viewId,
    String accountId,
    String? groupId,
    List<String> orderedAccountIds,
  ) => _runner.run(() async {
    final view = await _requireView(viewId);
    final account = (await _references.readReferences()).accounts[accountId];
    if (account == null || account.isArchived) {
      throw BusinessException(AnalyticsErrorCode.invalidReferences);
    }
    await _views.save(
      view
          .moveAccount(accountId, groupId)
          .reorderAccounts(groupId, orderedAccountIds),
    );
  });

  Future<void> _update(String id, AssetView Function(AssetView) update) =>
      _runner.run(() async => _views.save(update(await _requireView(id))));
  Future<AssetView> _requireView(String id) async {
    final view = await _views.findView(id);
    if (view == null) throw BusinessException(AnalyticsErrorCode.viewNotFound);
    return view;
  }
}
