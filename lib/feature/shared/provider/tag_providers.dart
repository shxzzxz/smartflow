import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';

part 'tag_providers.g.dart';

/// 标签词表（按词表排序）。录入、筛选与统计展示共享同一份词表快照。
@riverpod
Stream<List<TagView>> tagList(Ref ref) {
  return ref.watch(tagApplicationServiceProvider).watchTags();
}

/// 某笔交易当前携带的标签 ID。子交易返回所属顶层交易的标签。
@riverpod
Stream<Set<String>> transactionTagIds(Ref ref, String transactionId) {
  return ref
      .watch(tagApplicationServiceProvider)
      .watchTransactionTagIds(transactionId);
}
