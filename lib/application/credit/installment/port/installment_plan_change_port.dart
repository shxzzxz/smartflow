import '../../../../domain/credit/valobj/installment_plan_change.dart';

/// 自动触发的计划变更能力端口。
///
/// 还款、重定价、利息调整等用例只需要"按操作事实重算计划"这一能力，
/// 不依赖具体的计划 application service。实现由 infrastructure adapter
/// 桥接到计划用例，使 application 用例之间保持能力级依赖。
abstract interface class InstallmentPlanChangePort {
  Future<void> applyAutomaticChange(
    String contractId,
    InstallmentPlanChangeRequest request,
  );
}
