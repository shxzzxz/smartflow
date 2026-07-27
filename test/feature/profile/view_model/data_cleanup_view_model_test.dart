import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_violation_reason.dart';
import 'package:smartflow/feature/profile/view_model/data_cleanup_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  test('时间范围存储为排他端点，并支持清除', () {
    final container = _container(_FakeCleanupService());
    final notifier = container.read(dataCleanupViewModelProvider.notifier);

    notifier.setTimeRange(
      from: DateTime(2026, 7, 1),
      untilInclusive: DateTime(2026, 7, 31),
    );
    var state = container.read(dataCleanupViewModelProvider);
    expect(state.occurredFrom, DateTime(2026, 7, 1));
    expect(state.occurredUntilExclusive, DateTime(2026, 8, 1));
    expect(state.hasTimeRange, isTrue);

    notifier.clearTimeRange();
    state = container.read(dataCleanupViewModelProvider);
    expect(state.occurredFrom, isNull);
    expect(state.occurredUntilExclusive, isNull);
    expect(state.hasTimeRange, isFalse);
  });

  test('cleanup 将空集合映射为不限并返回成功结果', () async {
    final service = _FakeCleanupService(
      result: const TransactionCleanupResult(
        deletedGroupCount: 2,
        skippedGroupCount: 1,
      ),
    );
    final container = _container(service);
    final notifier = container.read(dataCleanupViewModelProvider.notifier);
    notifier.setCategoryIds({'cat-1', 'cat-2'});
    notifier.setTimeRange(
      from: DateTime(2026, 7, 1),
      untilInclusive: DateTime(2026, 7, 31),
    );

    final outcome = await notifier.cleanup();

    expect(outcome, isA<UiActionSuccess<TransactionCleanupResult>>());
    final success = outcome as UiActionSuccess<TransactionCleanupResult>;
    expect(success.value.deletedGroupCount, 2);
    expect(service.lastCommand?.categoryIds, {'cat-1', 'cat-2'});
    expect(service.lastCommand?.accountIds, isNull);
    expect(service.lastCommand?.occurredFrom, DateTime(2026, 7, 1));
    expect(service.lastCommand?.occurredUntil, DateTime(2026, 8, 1));
    expect(container.read(dataCleanupViewModelProvider).submitting, isFalse);
  });

  test('cleanup 业务异常映射为 UiError', () async {
    final container = _container(_FakeCleanupService(failing: true));
    final notifier = container.read(dataCleanupViewModelProvider.notifier);

    final outcome = await notifier.cleanup();

    expect(outcome, isA<UiActionFailure<TransactionCleanupResult>>());
    final failure = outcome as UiActionFailure<TransactionCleanupResult>;
    expect(failure.error.message, isNotEmpty);
    expect(container.read(dataCleanupViewModelProvider).submitting, isFalse);
  });

  test('预览查询与条件联动，空集合传递为不限', () async {
    final queryService = _FakeTransactionQueryService();
    final container = _container(
      _FakeCleanupService(),
      queryService: queryService,
    );
    final notifier = container.read(dataCleanupViewModelProvider.notifier);
    notifier.setAccountIds({'acc-1'});

    final subscription = container.listen(dataCleanupPreviewProvider, (_, _) {});
    final preview = await container.read(dataCleanupPreviewProvider.future);
    subscription.close();

    expect(preview.matchedGroupCount, 3);
    expect(queryService.lastQuery?.accountIds, {'acc-1'});
    expect(queryService.lastQuery?.categoryIds, isNull);
    expect(queryService.lastQuery?.occurredFrom, isNull);
  });
}

ProviderContainer _container(
  _FakeCleanupService service, {
  _FakeTransactionQueryService? queryService,
}) {
  final container = ProviderContainer(
    overrides: [
      transactionCleanupAppServiceProvider.overrideWith((ref) => service),
      if (queryService != null)
        transactionQueryServiceProvider.overrideWith((ref) => queryService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeCleanupService implements TransactionCleanupAppService {
  _FakeCleanupService({
    this.result = const TransactionCleanupResult(
      deletedGroupCount: 0,
      skippedGroupCount: 0,
    ),
    this.failing = false,
  });

  final TransactionCleanupResult result;
  final bool failing;
  CleanupTransactionsCommand? lastCommand;

  @override
  Future<TransactionCleanupResult> cleanupTransactions(
    CleanupTransactionsCommand command,
  ) async {
    lastCommand = command;
    if (failing) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    return result;
  }
}

class _FakeTransactionQueryService implements TransactionQueryService {
  TransactionCleanupQuery? lastQuery;

  @override
  Stream<TransactionCleanupPreview> watchCleanupPreview(
    TransactionCleanupQuery query,
  ) {
    lastQuery = query;
    return Stream.value(
      const TransactionCleanupPreview(matchedGroupCount: 3, ownedGroupCount: 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
