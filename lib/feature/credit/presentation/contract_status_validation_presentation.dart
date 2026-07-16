import '../../../application/credit/credit_command_api.dart';

String contractStatusValidationMessage(ContractStatusValidationResult result) {
  String message;
  if (!result.hasChanges) {
    message = result.issues.isEmpty ? '状态校验完成，当前状态正常' : '校验完成，未修改状态';
  } else if (result.repairedScheduleCount > 0) {
    message = '校验完成，已修复 ${result.repairedScheduleCount} 个还款计划';
    if (result.contractStatusChanged) message += '及合同状态';
  } else {
    message = '校验完成，已修复合同状态';
  }
  if (result.issues.isNotEmpty) {
    message += '，另有 ${result.issues.length} 项数据冲突未处理';
  }
  return message;
}
