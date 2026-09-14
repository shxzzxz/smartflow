import '../entity/installment_repricing.dart';
import '../entity/installment_repricing_configuration.dart';

abstract interface class InstallmentRepricingRepository {
  /// 自动生成配置或待应用记录所涉及的合同；记录不依赖配置继续存在。
  Future<List<String>> contractIdsForRepricing();
  Future<List<InstallmentRepricing>> list(String contractId);

  /// 保存合同重定价快照；重复取值不覆盖既有快照，不写入公共参考利率历史。
  Future<bool> insert(InstallmentRepricing record);

  /// 保存实体当前状态；目标记录不存在时拒绝保存。
  Future<void> update(InstallmentRepricing record);

  Future<void> insertConfiguration(
    InstallmentRepricingConfiguration configuration,
  );

  /// 仅删除自动生成约定，保留已独立保存的重定价事实。
  Future<void> deleteConfiguration(
    InstallmentRepricingConfiguration configuration,
  );

  /// 按重定价日单调推进配置进度；与候选处理在同一事务中提交。
  Future<void> advanceGeneration(String configurationId, DateTime resetDate);

  /// 删除事实，保留配置的生成进度；参与调用方事务。
  Future<void> delete(InstallmentRepricing record);
}
