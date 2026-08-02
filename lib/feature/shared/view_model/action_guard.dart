import 'package:logging/logging.dart';

import '../../../core/error/app_exception.dart';
import 'ui_action_outcome.dart';

/// 统一的 ViewModel 动作守卫：业务异常映射为 UiError，
/// 未预期异常记 severe 日志后返回 unknown，避免各处样板遗漏日志。
Future<UiActionOutcome<T>> guardUiAction<T>(
  Logger logger,
  String operation,
  Future<T> Function() action,
) async {
  try {
    return UiActionOutcome.success(await action());
  } on AppException catch (exception) {
    return UiActionOutcome.failure(UiError.fromException(exception));
  } on Exception catch (exception, stackTrace) {
    logger.severe('$operation failed unexpectedly.', exception, stackTrace);
    return const UiActionOutcome.failure(UiError.unknown());
  }
}

Future<SubmitOutcome> guardSubmit(
  Logger logger,
  String operation,
  Future<void> Function() action,
) async {
  try {
    await action();
    return const SubmitOutcome.success();
  } on AppException catch (exception) {
    return SubmitOutcome.failure(UiError.fromException(exception));
  } on Exception catch (exception, stackTrace) {
    logger.severe('$operation failed unexpectedly.', exception, stackTrace);
    return const SubmitOutcome.failure(UiError.unknown());
  }
}
