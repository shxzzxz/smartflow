import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';

part 'counterparty_providers.g.dart';

/// 对手方词表（按名称排序）。录入交易时与标签词表并行使用。
@riverpod
Stream<List<CounterpartyView>> counterpartyList(Ref ref) {
  return ref
      .watch(counterpartyApplicationServiceProvider)
      .watchCounterparties();
}
