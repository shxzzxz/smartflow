import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/feature/counterparty/view_model/counterparty_management_view_model.dart';

import '../../../helper/fake_counterparty_repository.dart';
import '../../../helper/sequential_id_generator.dart';

void main() {
  test('maps duplicate renames to a user-facing command outcome', () async {
    final repository = FakeCounterpartyRepository([
      const CounterpartyView(id: 'ziroom', name: '自如'),
      const CounterpartyView(id: 'nongfu', name: '农夫山泉'),
    ]);
    final container = ProviderContainer(
      overrides: [
        counterpartyApplicationServiceProvider.overrideWithValue(
          CounterpartyApplicationService(
            repository: repository,
            idGenerator: SequentialIdGenerator(prefix: 'cp'),
            transactionRunner: const _DirectTransactionRunner(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(counterpartyManagementViewModelProvider.notifier)
        .rename(id: 'nongfu', name: '自如');

    expect(outcome, CounterpartyCommandOutcome.duplicateName);
  });
}

class _DirectTransactionRunner implements TransactionRunner {
  const _DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
