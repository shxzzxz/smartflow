/// Partial update 三态字段值：
/// - 字段类型为 `Patch<T>?` 时，`null` 表示"不修改该字段"。
/// - `Patch.set(value)` 表示"把该字段设为 value"。
/// - `Patch.clear()` 表示"把该字段置空"。
///
/// 仅用于业务上确实需要"清除"语义的可空字段（如分期合同的 note、利率），
/// 不要污染没有清除需求的字段——那些字段直接用 `T?`（null = 不改）即可。
sealed class Patch<T> {
  const Patch();

  const factory Patch.set(T value) = PatchSet<T>;

  const factory Patch.clear() = PatchClear<T>;
}

final class PatchSet<T> extends Patch<T> {
  const PatchSet(this.value);

  final T value;
}

final class PatchClear<T> extends Patch<T> {
  const PatchClear();
}

extension NullablePatchApply<T> on Patch<T>? {
  T? applyTo(T? current) {
    return switch (this) {
      null => current,
      PatchClear<T>() => null,
      PatchSet<T>(:final value) => value,
    };
  }

  R? applyMappedTo<R>(R? current, R? Function(T value) map) {
    return switch (this) {
      null => current,
      PatchClear<T>() => null,
      PatchSet<T>(:final value) => map(value),
    };
  }
}
