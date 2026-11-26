import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'account_organization_view_model.g.dart';

final _logger = Logger('feature.account.organization');

/// All organization commands apply to one saved asset view.
@riverpod
class AccountOrganizationViewModel extends _$AccountOrganizationViewModel {
  @override
  void build(String viewId) {}

  Future<UiActionOutcome<void>> moveAccount({
    required String accountId,
    required String? targetGroupId,
    required List<String> targetAccountIds,
    required int insertAt,
  }) {
    final orderedIds = [...targetAccountIds]..remove(accountId);
    orderedIds.insert(insertAt.clamp(0, orderedIds.length), accountId);
    return guardUiAction(
      _logger,
      'Move account in asset view',
      () => ref
          .read(assetViewAppServiceProvider)
          .moveAccountToGroup(viewId, accountId, targetGroupId, orderedIds),
    );
  }

  Future<UiActionOutcome<void>> reorderGroups(List<String> orderedIds) =>
      guardUiAction(
        _logger,
        'Reorder view account groups',
        () => ref
            .read(assetViewAppServiceProvider)
            .reorderGroups(viewId, orderedIds),
      );

  Future<UiActionOutcome<void>> renameGroup(String id, String name) =>
      guardUiAction(
        _logger,
        'Rename view account group',
        () =>
            ref.read(assetViewAppServiceProvider).renameGroup(viewId, id, name),
      );

  Future<UiActionOutcome<void>> deleteGroup(String id) => guardUiAction(
    _logger,
    'Delete view account group',
    () => ref.read(assetViewAppServiceProvider).deleteGroup(viewId, id),
  );

  Future<UiActionOutcome<void>> createGroup(String name) => guardUiAction(
    _logger,
    'Create view account group',
    () => ref.read(assetViewAppServiceProvider).createGroup(viewId, name),
  );
}
