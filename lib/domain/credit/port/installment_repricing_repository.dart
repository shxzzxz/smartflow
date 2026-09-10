import '../entity/installment_repricing.dart';

abstract interface class InstallmentRepricingRepository {
  Future<List<String>> activeContractIds();
  Future<List<InstallmentRepricing>> list(String contractId);

  /// 保存合同重定价快照；重复取值不覆盖既有快照，不写入公共参考利率历史。
  Future<void> insert(InstallmentRepricing record);

  /// 保存实体当前状态；目标记录不存在时拒绝保存。
  Future<void> update(InstallmentRepricing record);

  /// 修改尚未执行的规则时移除旧候选；已应用的结果保留。
  Future<void> discardPending(String contractId, Set<String> stageIds);
}
