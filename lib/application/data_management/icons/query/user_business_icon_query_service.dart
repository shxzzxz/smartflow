import '../port/user_business_icon_store.dart';
import '../user_business_icon_models.dart';
import 'port/user_business_icon_reference_query.dart';

abstract interface class UserBusinessIconQueryService {
  Future<List<UserBusinessIconEntry>> list();
}

class UserBusinessIconQueryServiceImpl implements UserBusinessIconQueryService {
  const UserBusinessIconQueryServiceImpl({
    required UserBusinessIconStore store,
    required UserBusinessIconReferenceQuery references,
  }) : _store = store,
       _references = references;

  final UserBusinessIconStore _store;
  final UserBusinessIconReferenceQuery _references;

  @override
  Future<List<UserBusinessIconEntry>> list() async {
    final (icons, counts) = await (
      _store.load(),
      _references.countByRef(),
    ).wait;
    return [
      for (final icon in icons)
        UserBusinessIconEntry(icon: icon, usageCount: counts[icon.refId] ?? 0),
    ];
  }
}
