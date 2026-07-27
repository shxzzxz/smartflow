import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';

/// 时间范围条件文案；[untilExclusive] 为排他端点，展示时转为含端日期。
String cleanupTimeRangeLabel(DateTime? from, DateTime? untilExclusive) {
  if (from == null || untilExclusive == null) return '全部时间';
  final untilInclusive = untilExclusive.subtract(const Duration(days: 1));
  return '${from.year}.${from.month}.${from.day} - '
      '${untilInclusive.year}.${untilInclusive.month}.${untilInclusive.day}';
}

String cleanupSelectionLabel(int selectedCount, String allLabel) {
  return selectedCount == 0 ? allLabel : '已选 $selectedCount 项';
}

/// 清理确认弹窗正文。
String cleanupConfirmMessage(TransactionCleanupPreview preview) {
  final buffer = StringBuffer(
    '将删除 ${preview.deletableGroupCount} 组交易及其账务记录，删除后无法恢复。',
  );
  if (preview.ownedGroupCount > 0) {
    buffer.write('\n另有 ${preview.ownedGroupCount} 组信贷关联交易将被跳过。');
  }
  return buffer.toString();
}

/// 清理完成提示。
String cleanupResultMessage(TransactionCleanupResult result) {
  final buffer = StringBuffer('已清理 ${result.deletedGroupCount} 组交易');
  if (result.skippedGroupCount > 0) {
    buffer.write('，跳过 ${result.skippedGroupCount} 组信贷关联交易');
  }
  return buffer.toString();
}
