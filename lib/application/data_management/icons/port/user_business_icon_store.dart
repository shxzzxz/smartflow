import '../../backup/backup_models.dart';
import '../user_business_icon_models.dart';

abstract interface class UserBusinessIconStore implements BackupAssetStore {
  Future<List<UserBusinessIconRecord>> load();

  Future<UserBusinessIconRecord?> pickAndStore(UserBusinessIconType type);

  Future<void> delete(UserBusinessIconRecord icon);
}
