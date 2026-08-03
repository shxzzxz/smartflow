import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'account_organization_view_model.g.dart';

final _logger = Logger('feature.account.organization');

/// 资产页的账户展示组织命令入口。
///
/// 分组和排序都是展示组织，不改变账户画像或账务余额。
@riverpod
class AccountOrganizationViewModel extends _$AccountOrganizationViewModel {
  @override
  void build() {}

  Future<UiActionOutcome<void>> moveAccount({
    required String accountId,
    required String? targetGroupId,
    required List<String> targetAccountIds,
    required int insertAt,
  }) {
    final orderedIds = [...targetAccountIds]..remove(accountId);
    final targetIndex = insertAt.clamp(0, orderedIds.length);
    orderedIds.insert(targetIndex, accountId);
    return guardUiAction(_logger, 'Move account to group', () {
      return ref
          .read(accountGroupAppServiceProvider)
          .moveAccountToGroup(
            MoveAccountToGroupCommand(
              accountId: accountId,
              groupId: targetGroupId,
              orderedAccountIds: orderedIds,
            ),
          );
    });
  }

  Future<UiActionOutcome<void>> reorderGroups(List<String> orderedIds) {
    return guardUiAction(_logger, 'Reorder account groups', () {
      return ref
          .read(accountGroupAppServiceProvider)
          .reorderGroups(ReorderAccountGroupsCommand(orderedIds: orderedIds));
    });
  }

  Future<UiActionOutcome<void>> renameGroup(String id, String name) {
    return guardUiAction(_logger, 'Rename account group', () {
      return ref
          .read(accountGroupAppServiceProvider)
          .renameGroup(RenameAccountGroupCommand(id: id, name: name));
    });
  }

  Future<UiActionOutcome<void>> deleteGroup(String id) {
    return guardUiAction(_logger, 'Delete account group', () {
      return ref
          .read(accountGroupAppServiceProvider)
          .deleteGroup(DeleteAccountGroupCommand(id: id));
    });
  }

  Future<UiActionOutcome<void>> createGroup(String name) {
    return guardUiAction(_logger, 'Create account group', () async {
      await ref
          .read(accountGroupAppServiceProvider)
          .createGroup(CreateAccountGroupCommand(name: name));
    });
  }

  Future<UiActionOutcome<void>> restoreAccount(String accountId) {
    return guardUiAction(_logger, 'Restore archived account', () {
      return ref
          .read(accountAppServiceProvider)
          .restoreAccount(RestoreAccountCommand(id: accountId));
    });
  }
}
