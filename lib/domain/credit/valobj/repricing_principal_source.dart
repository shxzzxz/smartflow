import '../../../core/money/money.dart';
import 'reference_rate.dart';

/// 跨调息当期采用「下一期重算」时的本金来源，仅用于本次计算，不属于合同条款。
sealed class RepricingPrincipalSource {
  const RepricingPrincipalSource();

  /// 初始生成、提前还款和按参数重算：采用本次按原利率投影的本金。
  const factory RepricingPrincipalSource.projection() = _ProjectedPrincipal;

  /// 应用重定价：采用应用前计划的本金快照；快照缺值时回退到本次投影。
  factory RepricingPrincipalSource.scheduleSnapshot(
    Map<DateTime, Money> principals,
  ) = _SchedulePrincipalSnapshot;

  Money principalFor({required DateTime date, required Money projected});
}

final class _ProjectedPrincipal extends RepricingPrincipalSource {
  const _ProjectedPrincipal();

  @override
  Money principalFor({required DateTime date, required Money projected}) =>
      projected;
}

final class _SchedulePrincipalSnapshot extends RepricingPrincipalSource {
  _SchedulePrincipalSnapshot(Map<DateTime, Money> principals)
    : _principals = Map.unmodifiable({
        for (final entry in principals.entries)
          referenceDate(entry.key): entry.value,
      });

  final Map<DateTime, Money> _principals;

  @override
  Money principalFor({required DateTime date, required Money projected}) =>
      _principals[referenceDate(date)] ?? projected;
}
