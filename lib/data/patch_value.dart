import 'package:drift/drift.dart';

import '../core/patch/patch.dart';

extension PatchValue<T> on Patch<T>? {
  Value<T?> toValue() => switch (this) {
    null => Value<T?>.absent(),
    PatchSet<T>(:final value) => Value<T?>(value),
    PatchClear<T>() => Value<T?>(null),
  };
}
