import '../valobj/installment_plan_change.dart';

/// 计划变更用例需要的最小领域端口。
///
/// 具体的事实加载、计划落库和状态修复由 application 层实现；其它
/// application 用例只依赖这个端口，避免相互依赖具体 application service。
abstract interface class InstallmentPlanChangePort {
  Future<void> applyAutomaticChange(
    String contractId,
    InstallmentPlanChangeRequest request,
  );
}
