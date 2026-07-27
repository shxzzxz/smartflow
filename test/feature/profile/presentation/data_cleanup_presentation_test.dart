import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/feature/profile/presentation/data_cleanup_presentation.dart';

void main() {
  test('时间范围文案将排他端点转为含端日期', () {
    expect(cleanupTimeRangeLabel(null, null), '全部时间');
    expect(
      cleanupTimeRangeLabel(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      '2026.7.1 - 2026.7.31',
    );
  });

  test('选择条件文案区分不限与已选数量', () {
    expect(cleanupSelectionLabel(0, '全部分类'), '全部分类');
    expect(cleanupSelectionLabel(3, '全部分类'), '已选 3 项');
  });

  test('确认与结果文案携带跳过说明', () {
    expect(
      cleanupConfirmMessage(
        const TransactionCleanupPreview(matchedGroupCount: 5, ownedGroupCount: 0),
      ),
      '将删除 5 组交易及其账务记录，删除后无法恢复。',
    );
    expect(
      cleanupConfirmMessage(
        const TransactionCleanupPreview(matchedGroupCount: 5, ownedGroupCount: 2),
      ),
      '将删除 3 组交易及其账务记录，删除后无法恢复。\n另有 2 组信贷关联交易将被跳过。',
    );
    expect(
      cleanupResultMessage(
        const TransactionCleanupResult(
          deletedGroupCount: 3,
          skippedGroupCount: 0,
        ),
      ),
      '已清理 3 组交易',
    );
    expect(
      cleanupResultMessage(
        const TransactionCleanupResult(
          deletedGroupCount: 3,
          skippedGroupCount: 2,
        ),
      ),
      '已清理 3 组交易，跳过 2 组信贷关联交易',
    );
  });
}
