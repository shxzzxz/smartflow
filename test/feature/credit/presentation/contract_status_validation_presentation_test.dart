import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/feature/credit/presentation/contract_status_validation_presentation.dart';

void main() {
  test('builds normal, repaired, and conflicted validation messages', () {
    expect(
      contractStatusValidationMessage(
        const ContractStatusValidationResult(
          repairedScheduleCount: 0,
          contractStatusChanged: false,
        ),
      ),
      '状态校验完成，当前状态正常',
    );
    expect(
      contractStatusValidationMessage(
        const ContractStatusValidationResult(
          repairedScheduleCount: 2,
          contractStatusChanged: true,
          issues: [
            ContractStatusValidationIssue(
              type:
                  ContractStatusValidationIssueType
                      .skippedScheduleHasAllocation,
              message: '已跳过的还款计划存在还款分摊。',
            ),
          ],
        ),
      ),
      '校验完成，已修复 2 个还款计划及合同状态，另有 1 项数据冲突未处理',
    );
  });
}
