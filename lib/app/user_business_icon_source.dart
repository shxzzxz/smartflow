import 'package:logging/logging.dart';

import '../application/data_management/icons/port/user_business_icon_store.dart';
import '../application/data_management/icons/user_business_icon_models.dart';
import '../widget/business/icon/business_icon_registry.dart';

final _logger = Logger('app.data_management.icons');

class AppUserBusinessIconSource implements BusinessIconSource {
  const AppUserBusinessIconSource(this._store);

  final UserBusinessIconStore _store;

  @override
  Future<List<BusinessIconGroup>> load() async {
    try {
      final records = await _store.load();
      if (records.isEmpty) return const [];
      return [
        for (final type in UserBusinessIconType.values)
          if (records.where((record) => record.type == type).isNotEmpty)
            _groupFor(type, records),
      ];
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'Failed to load user business icons; built-in icons remain available.',
        error,
        stackTrace,
      );
      return const [];
    }
  }

  BusinessIconGroup _groupFor(
    UserBusinessIconType type,
    List<UserBusinessIconRecord> records,
  ) {
    final iconType = type == UserBusinessIconType.account
        ? BusinessIconType.account
        : BusinessIconType.category;
    return BusinessIconGroup(
      origin: BusinessIconOrigin.user,
      type: iconType,
      id: userBusinessIconGroupId,
      name: '我的图标',
      kind: BusinessIconGroupKind.user,
      icons: {
        for (final record in records)
          if (record.type == type)
            record.key: BusinessIconSpec(
              ref: BusinessIconRef(
                origin: BusinessIconOrigin.user,
                type: iconType,
                groupId: userBusinessIconGroupId,
                key: record.key,
              ),
              label: record.label,
              assetPath: record.filePath,
              resourceKind: BusinessIconResourceKind.file,
              usage: type == UserBusinessIconType.account
                  ? BusinessIconUsage.account
                  : BusinessIconUsage.expenseCategory,
              color: BusinessIconColor.original,
              keywords: [record.label],
            ),
      },
    );
  }
}
