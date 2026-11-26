import '../../../../domain/analytics/port/asset_view_account_port.dart';
import '../../../../core/patch/patch.dart';

export '../../../../domain/analytics/port/asset_view_account_port.dart'
    show AssetViewAccountDraft, AssetViewAccountEdit;

class CreateAssetViewAccountCommand {
  const CreateAssetViewAccountCommand({
    required this.viewId,
    required this.groupId,
    required this.account,
  });
  final String viewId;
  final String? groupId;
  final AssetViewAccountDraft account;
}

class EditAssetViewAccountCommand {
  const EditAssetViewAccountCommand({
    required this.viewId,
    required this.groupId,
    required this.account,
  });
  final String viewId;
  final Patch<String>? groupId;
  final AssetViewAccountEdit account;
}
