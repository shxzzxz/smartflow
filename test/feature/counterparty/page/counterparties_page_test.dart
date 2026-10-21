import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/counterparty/page/counterparties_page.dart';
import 'package:smartflow/feature/shared/provider/counterparty_providers.dart';

import '../../../helper/fake_counterparty_repository.dart';
import '../../../helper/sequential_id_generator.dart';

void main() {
  testWidgets('searches counterparties and creates a new one', (tester) async {
    final repository = FakeCounterpartyRepository([
      const CounterpartyView(id: 'ziroom', name: '自如', usageCount: 2),
      const CounterpartyView(id: 'nongfu', name: '农夫山泉'),
    ]);
    final service = CounterpartyApplicationService(
      repository: repository,
      idGenerator: SequentialIdGenerator(prefix: 'cp'),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await _pumpPage(tester, repository: repository, service: service);

    await tester.enterText(find.byType(TextField), '自');
    await tester.pump();
    expect(find.text('自如'), findsOneWidget);
    expect(find.text('农夫山泉'), findsNothing);

    await tester.tap(find.byTooltip('新建对手方'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '链家');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(
      (await repository.listCounterparties()).map((item) => item.name),
      contains('链家'),
    );
  });

  testWidgets('deletes a counterparty after confirming reference cleanup', (
    tester,
  ) async {
    final repository = FakeCounterpartyRepository([
      const CounterpartyView(id: 'ziroom', name: '自如', usageCount: 2),
    ]);
    final service = CounterpartyApplicationService(
      repository: repository,
      idGenerator: SequentialIdGenerator(prefix: 'cp'),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await _pumpPage(tester, repository: repository, service: service);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('正在 2 笔交易上使用'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(await repository.listCounterparties(), isEmpty);
    expect(repository.clearedCounterpartyIds, {'ziroom'});
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakeCounterpartyRepository repository,
  required CounterpartyApplicationService service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        counterpartyListProvider.overrideWith(
          (ref) => repository.watchCounterparties(),
        ),
        counterpartyApplicationServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CounterpartiesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _DirectTransactionRunner implements TransactionRunner {
  const _DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
