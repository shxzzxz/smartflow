import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/budget/view_model/budget_view_model.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  test(
    'copies the previous month when opening an empty current month',
    () async {
      final month = DateTime(2026, 8);
      final service = _RecordingBudgetAppService();
      final container = ProviderContainer(
        overrides: [
          budgetAppServiceProvider.overrideWithValue(service),
          budgetQueryServiceProvider.overrideWithValue(
            _StaticBudgetQueryService(_emptyReport(month)),
          ),
          appSettingsStoreProvider.overrideWithValue(
            _MemorySettingsStore(
              const AppSettings(copyPreviousMonthBudgetsOnOpen: true),
            ),
          ),
          currentDateTimeProvider.overrideWithValue(DateTime(2026, 8, 6)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        budgetViewModelProvider(month),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container
          .read(budgetViewModelProvider(month).notifier)
          .copyPreviousMonthBudgetsOnOpen();

      expect(service.commands, hasLength(1));
      expect(service.commands.single.month, MonthKey(year: 2026, month: 8));
    },
  );

  test('does not copy a future month when opening an empty month', () async {
    final month = DateTime(2026, 9);
    final service = _RecordingBudgetAppService();
    final container = ProviderContainer(
      overrides: [
        budgetAppServiceProvider.overrideWithValue(service),
        budgetQueryServiceProvider.overrideWithValue(
          _StaticBudgetQueryService(_emptyReport(month)),
        ),
        appSettingsStoreProvider.overrideWithValue(
          _MemorySettingsStore(
            const AppSettings(copyPreviousMonthBudgetsOnOpen: true),
          ),
        ),
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 8, 6)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      budgetViewModelProvider(month),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container
        .read(budgetViewModelProvider(month).notifier)
        .copyPreviousMonthBudgetsOnOpen();

    expect(service.commands, isEmpty);
  });

  test('does not copy when the setting is disabled', () async {
    final month = DateTime(2026, 8);
    final service = _RecordingBudgetAppService();
    final container = ProviderContainer(
      overrides: [
        budgetAppServiceProvider.overrideWithValue(service),
        budgetQueryServiceProvider.overrideWithValue(
          _StaticBudgetQueryService(_emptyReport(month)),
        ),
        appSettingsStoreProvider.overrideWithValue(
          _MemorySettingsStore(const AppSettings()),
        ),
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 8, 6)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      budgetViewModelProvider(month),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final outcome =
        await container
            .read(budgetViewModelProvider(month).notifier)
            .copyPreviousMonthBudgetsOnOpen();

    expect(outcome, isA<UiActionSuccess<bool>>());
    expect((outcome as UiActionSuccess<bool>).value, isFalse);
    expect(service.commands, isEmpty);
  });

  test('does not copy when the current month already has budgets', () async {
    final month = DateTime(2026, 8);
    final service = _RecordingBudgetAppService();
    final container = ProviderContainer(
      overrides: [
        budgetAppServiceProvider.overrideWithValue(service),
        budgetQueryServiceProvider.overrideWithValue(
          _StaticBudgetQueryService(_orderReport(month)),
        ),
        appSettingsStoreProvider.overrideWithValue(
          _MemorySettingsStore(
            const AppSettings(copyPreviousMonthBudgetsOnOpen: true),
          ),
        ),
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 8, 6)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      budgetViewModelProvider(month),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container
        .read(budgetViewModelProvider(month).notifier)
        .copyPreviousMonthBudgetsOnOpen();

    expect(service.commands, isEmpty);
  });

  test('maps auto-copy query and command failures to UI failures', () async {
    final month = DateTime(2026, 8);
    Future<UiActionOutcome<bool>> run({
      required BudgetQueryService queryService,
      required _RecordingBudgetAppService service,
    }) async {
      final container = ProviderContainer(
        overrides: [
          budgetAppServiceProvider.overrideWithValue(service),
          budgetQueryServiceProvider.overrideWithValue(queryService),
          appSettingsStoreProvider.overrideWithValue(
            _MemorySettingsStore(
              const AppSettings(copyPreviousMonthBudgetsOnOpen: true),
            ),
          ),
          currentDateTimeProvider.overrideWithValue(DateTime(2026, 8, 6)),
        ],
      );
      final subscription = container.listen(
        budgetViewModelProvider(month),
        (_, _) {},
      );
      final outcome =
          await container
              .read(budgetViewModelProvider(month).notifier)
              .copyPreviousMonthBudgetsOnOpen();
      subscription.close();
      container.dispose();
      return outcome;
    }

    final queryFailure = await run(
      queryService: _FailingBudgetQueryService(),
      service: _RecordingBudgetAppService(),
    );
    final commandFailure = await run(
      queryService: _StaticBudgetQueryService(_emptyReport(month)),
      service: _RecordingBudgetAppService(
        copyError: BusinessException(LedgerErrorCode.budgetInvalidCommand),
      ),
    );

    expect(queryFailure, isA<UiActionFailure<bool>>());
    expect(commandFailure, isA<UiActionFailure<bool>>());
  });

  test(
    'reorders children and groups and assembles persisted budget ids',
    () async {
      final month = DateTime(2026, 8);
      final report = _orderReport(month);
      final service = _RecordingBudgetAppService();
      final container = ProviderContainer(
        overrides: [
          budgetAppServiceProvider.overrideWithValue(service),
          budgetQueryServiceProvider.overrideWithValue(
            _StaticBudgetQueryService(report),
          ),
          currentDateTimeProvider.overrideWithValue(DateTime(2026, 8, 6)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        budgetViewModelProvider(month),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(monthlyBudgetReportProvider(month).future);
      await container.pump();

      await container
          .read(budgetViewModelProvider(month).notifier)
          .reorderBudgetsWithinGroup(0, 0, 1);
      await container
          .read(budgetViewModelProvider(month).notifier)
          .reorderBudgetGroups(0, 1);

      expect(service.reorderCommands, hasLength(2));
      expect(service.reorderCommands[0].orderedBudgetIds, [
        'food-budget',
        'dinner-budget',
        'lunch-budget',
        'transport-budget',
      ]);
      expect(service.reorderCommands[1].orderedBudgetIds, [
        'transport-budget',
        'food-budget',
        'dinner-budget',
        'lunch-budget',
      ]);
    },
  );

  test('restores the previous budget order when persistence fails', () async {
    final month = DateTime(2026, 8);
    final report = _orderReport(month);
    final service = _RecordingBudgetAppService(
      reorderError: BusinessException(LedgerErrorCode.budgetInvalidCommand),
    );
    final container = ProviderContainer(
      overrides: [
        budgetAppServiceProvider.overrideWithValue(service),
        budgetQueryServiceProvider.overrideWithValue(
          _StaticBudgetQueryService(report),
        ),
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 8, 6)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      budgetViewModelProvider(month),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(monthlyBudgetReportProvider(month).future);
    await container.pump();

    final outcome = await container
        .read(budgetViewModelProvider(month).notifier)
        .reorderBudgetGroups(0, 1);

    expect(outcome, isA<UiActionFailure<void>>());
    expect(
      container
          .read(budgetViewModelProvider(month))
          .categoryGroups
          .map((group) => group.id),
      ['food', 'transport'],
    );
  });

  test(
    'root budget transactions include child categories in budget scope',
    () async {
      final month = DateTime(2026, 8);
      final root = Account(
        id: 'food',
        name: '餐饮',
        type: AccountType.expense,
        balance: Money.zero(),
      );
      final child = Account(
        id: 'lunch',
        name: '午餐',
        type: AccountType.expense,
        balance: Money.zero(),
        parentId: root.id,
      );
      final progress = BudgetProgress(
        id: 'food-budget',
        categoryId: root.id,
        name: root.name,
        budget: const Money(minorUnits: 100000),
        spent: const Money(minorUnits: 20000),
        sortOrder: 0,
        trend: const [],
      );
      final report = MonthlyBudgetReport(
        month: MonthKey.fromDate(month),
        categoryGroups: [
          BudgetCategoryGroup(
            id: root.id,
            name: root.name,
            sortOrder: 0,
            rootBudget: progress,
            childBudgets: const [],
          ),
        ],
      );
      final service = _RecordingTransactionQueryService();
      final container = ProviderContainer(
        overrides: [
          transactionQueryServiceProvider.overrideWithValue(service),
          monthlyBudgetReportProvider(
            month,
          ).overrideWith((ref) => Stream.value(report)),
          accountLookupProvider.overrideWith(
            (ref) =>
                Stream.value(AccountLookup({root.id: root, child.id: child})),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        budgetDetailPageProvider(progress.id, month),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container.read(monthlyBudgetReportProvider(month).future);
      await container.read(accountLookupProvider.future);
      await container.pump();
      await _flush();

      expect(service.queries, isNotEmpty);
      final query = service.queries.last;
      expect(query.categoryAccountIds, {root.id, child.id});
      expect(query.scope, TransactionScopeFilter.budget);
      expect(
        container.read(budgetDetailPageProvider(progress.id, month)),
        isA<BudgetDetailPageLoaded>(),
      );
    },
  );
}

class _RecordingBudgetAppService implements BudgetAppService {
  _RecordingBudgetAppService({this.copyError, this.reorderError});

  final commands = <CopyPreviousMonthBudgetsCommand>[];
  final reorderCommands = <ReorderCategoryBudgetsCommand>[];
  final Object? copyError;
  final Object? reorderError;

  @override
  Future<bool> copyPreviousMonthBudgets(
    CopyPreviousMonthBudgetsCommand command,
  ) async {
    commands.add(command);
    if (copyError case final error?) throw error;
    return true;
  }

  @override
  Future<void> reorderCategoryBudgets(
    ReorderCategoryBudgetsCommand command,
  ) async {
    reorderCommands.add(command);
    if (reorderError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticBudgetQueryService implements BudgetQueryService {
  _StaticBudgetQueryService(this.report);

  final MonthlyBudgetReport report;

  @override
  Stream<MonthlyBudgetReport> watchMonthlyReport(MonthKey month) {
    return Stream.value(report);
  }
}

class _FailingBudgetQueryService implements BudgetQueryService {
  @override
  Stream<MonthlyBudgetReport> watchMonthlyReport(MonthKey month) {
    return Stream.error(
      BusinessException(LedgerErrorCode.budgetInvalidCommand),
    );
  }
}

MonthlyBudgetReport _emptyReport(DateTime month) {
  return MonthlyBudgetReport(
    month: MonthKey.fromDate(month),
    categoryGroups: const [],
  );
}

MonthlyBudgetReport _orderReport(DateTime month) {
  BudgetProgress progress(String id, String categoryId) {
    return BudgetProgress(
      id: id,
      categoryId: categoryId,
      name: categoryId,
      budget: const Money(minorUnits: 10000),
      spent: Money.zero(),
      sortOrder: 0,
      trend: const [],
    );
  }

  return MonthlyBudgetReport(
    month: MonthKey.fromDate(month),
    categoryGroups: [
      BudgetCategoryGroup(
        id: 'food',
        name: '餐饮',
        sortOrder: 0,
        rootBudget: progress('food-budget', 'food'),
        childBudgets: [
          progress('lunch-budget', 'lunch'),
          progress('dinner-budget', 'dinner'),
        ],
      ),
      BudgetCategoryGroup(
        id: 'transport',
        name: '交通',
        sortOrder: 3,
        rootBudget: progress('transport-budget', 'transport'),
        childBudgets: const [],
      ),
    ],
  );
}

class _MemorySettingsStore implements AppSettingsStore {
  _MemorySettingsStore(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _RecordingTransactionQueryService implements TransactionQueryService {
  final queries = <TransactionListQuery>[];

  @override
  Stream<List<TransactionReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
