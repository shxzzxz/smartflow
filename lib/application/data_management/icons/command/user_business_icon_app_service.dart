import '../../../../core/error/app_error_code.dart';
import '../../../../core/error/app_exception.dart';
import '../port/user_business_icon_store.dart';
import '../query/port/user_business_icon_reference_query.dart';
import '../user_business_icon_models.dart';

enum _UserBusinessIconErrorCode implements AppErrorCode {
  iconInUse(
    code: 'application.data_management.icons.in_use',
    defaultMessage: '该图标正在被账户或分类使用，无法删除。',
  );

  const _UserBusinessIconErrorCode({
    required this.code,
    required this.defaultMessage,
  });

  @override
  final String code;

  @override
  final String defaultMessage;
}

class UserBusinessIconAppService {
  const UserBusinessIconAppService({
    required UserBusinessIconStore store,
    required UserBusinessIconReferenceQuery references,
  }) : _store = store,
       _references = references;

  final UserBusinessIconStore _store;
  final UserBusinessIconReferenceQuery _references;

  Future<UserBusinessIconRecord?> upload(UserBusinessIconType type) {
    return _store.pickAndStore(type);
  }

  Future<void> delete(UserBusinessIconRecord icon) async {
    final counts = await _references.countByRef();
    if ((counts[icon.refId] ?? 0) > 0) {
      throw BusinessException(_UserBusinessIconErrorCode.iconInUse);
    }
    await _store.delete(icon);
  }
}
