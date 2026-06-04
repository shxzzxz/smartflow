import '../../../core/error/app_error_code.dart';

enum CreditErrorCode implements AppErrorCode {
  contractNotFound(code: 'credit.contract.not_found', defaultMessage: '合同不存在。'),
  contractNotActive(
    code: 'credit.contract.not_active',
    defaultMessage: '只有进行中的合同可以编辑。',
  ),
  contractInvalidCommand(
    code: 'credit.contract.invalid_command',
    defaultMessage: '合同参数不完整或不合法。',
  ),
  contractPersistenceConflict(
    code: 'credit.contract.persistence_conflict',
    defaultMessage: '合同数据已变化，请刷新后重试。',
  ),
  repaymentNotFound(
    code: 'credit.repayment.not_found',
    defaultMessage: '还款记录不存在。',
  ),
  repaymentInvalidCommand(
    code: 'credit.repayment.invalid_command',
    defaultMessage: '还款参数不完整或不合法。',
  ),
  repaymentNotEditable(
    code: 'credit.repayment.not_editable',
    defaultMessage: '还款记录当前不可编辑。',
  ),
  repaymentExceedsAvailable(
    code: 'credit.repayment.exceeds_available',
    defaultMessage: '还款本金超过可还额度。',
  ),
  scheduleNotFound(
    code: 'credit.schedule.not_found',
    defaultMessage: '还款计划不存在。',
  ),
  scheduleNotPending(
    code: 'credit.schedule.not_pending',
    defaultMessage: '该期次当前不可还款。',
  );

  const CreditErrorCode({required this.code, required this.defaultMessage});

  @override
  final String code;

  @override
  final String defaultMessage;
}
