import '../../../../core/error/app_exception.dart';
import '../../../../core/patch/patch.dart';
import '../../../../domain/analytics/entity/asset_view.dart';
import '../../../../domain/analytics/port/asset_view_account_port.dart';
import '../../../../domain/analytics/port/asset_view_repository.dart';
import '../../../../domain/analytics/valobj/analytics_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'asset_view_account_command.dart';

abstract interface class AssetViewAccountAppService {
  Future<String> createAccount(CreateAssetViewAccountCommand command);
  Future<void> editAccount(EditAssetViewAccountCommand command);
}

/// Coordinates account facts and the selected view in one transaction.
class AssetViewAccountAppServiceImpl implements AssetViewAccountAppService {
  const AssetViewAccountAppServiceImpl({
    required AssetViewRepository views,
    required AssetViewAccountPort accounts,
    required TransactionRunner transactionRunner,
  }) : _views = views,
       _accounts = accounts,
       _runner = transactionRunner;
  final AssetViewRepository _views;
  final AssetViewAccountPort _accounts;
  final TransactionRunner _runner;

  @override
  Future<String> createAccount(CreateAssetViewAccountCommand command) =>
      _runner.run(() async {
        final view = await _requireView(command.viewId);
        if (command.groupId != null &&
            !view.groups.any((group) => group.id == command.groupId)) {
          throw BusinessException(AnalyticsErrorCode.invalidGroup);
        }
        final id = await _accounts.createAccount(command.account);
        await _views.save(
          view.copyWith(
            accountIds: [...view.accountIds, id],
            accountGroupIds: {
              ...view.accountGroupIds,
              if (command.groupId != null) id: command.groupId!,
            },
          ),
        );
        return id;
      });

  @override
  Future<void> editAccount(EditAssetViewAccountCommand command) =>
      _runner.run(() async {
        final view = await _requireView(command.viewId);
        final updated =
            command.groupId != null &&
                view.includesAccount(command.account.accountId)
            ? view.moveAccount(
                command.account.accountId,
                command.groupId.applyTo(
                  view.groupIdFor(command.account.accountId),
                ),
              )
            : view;
        await _accounts.editAccount(command.account);
        if (!identical(updated, view)) await _views.save(updated);
      });

  Future<AssetView> _requireView(String id) async {
    final view = await _views.findView(id);
    if (view == null) throw BusinessException(AnalyticsErrorCode.viewNotFound);
    return view;
  }
}
