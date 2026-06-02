import 'package:smartflow/core/error/app_exception.dart';

class UiError {
  const UiError({required this.code, required this.message});

  factory UiError.fromException(AppException exception) {
    return UiError(code: exception.code, message: exception.message);
  }

  final String code;
  final String message;
}

sealed class UiActionOutcome<T> {
  const UiActionOutcome();

  const factory UiActionOutcome.success(T value) = UiActionSuccess<T>;
  const factory UiActionOutcome.failure(UiError error) = UiActionFailure<T>;
}

final class UiActionSuccess<T> extends UiActionOutcome<T> {
  const UiActionSuccess(this.value);

  final T value;
}

final class UiActionFailure<T> extends UiActionOutcome<T> {
  const UiActionFailure(this.error);

  final UiError error;
}

sealed class SubmitOutcome {
  const SubmitOutcome();

  const factory SubmitOutcome.success() = SubmitSuccess;
  const factory SubmitOutcome.failure(UiError error) = SubmitFailure;
}

final class SubmitSuccess extends SubmitOutcome {
  const SubmitSuccess();
}

final class SubmitFailure extends SubmitOutcome {
  const SubmitFailure(this.error);

  final UiError error;
}
