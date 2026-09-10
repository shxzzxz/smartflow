import '../entity/installment_repricing.dart';

abstract interface class InstallmentRepricingRepository {
  Future<List<String>> activeContractIds();
  Future<List<InstallmentRepricing>> list(String contractId);

  /// 报价和重定价结果一起保存；重复取值不覆盖既有快照。
  Future<void> insert(InstallmentRepricing record);
  Future<void> markApplied(String id);

  /// 修改尚未执行的规则时移除旧候选；已应用的结果保留。
  Future<void> discardPending(String contractId, Set<String> stageIds);
}
