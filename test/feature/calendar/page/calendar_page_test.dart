import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/chart.dart';
import 'package:smartflow/feature/calendar/page/calendar_page.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

final _selectedDate = DateTime(2026, 1, 15);
final _visibleMonth = DateTime(2026, 1);

void main() {
  testWidgets('renders the selected day rows under the month grid', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      dayTransactions: [_item(_selectedDate.add(const Duration(hours: 9)))],
    );

    expect(find.text('1月15日'), findsOneWidget);
    expect(find.byType(TransactionRow), findsOneWidget);
    expect(find.text('当天暂无交易记录'), findsNothing);
  });

  testWidgets('shows the per-day empty message when the day has no rows', (
    tester,
  ) async {
    await _pumpCalendar(tester, dayTransactions: const []);

    expect(find.text('1月15日'), findsOneWidget);
    expect(find.byType(TransactionRow), findsNothing);
    expect(find.text('当天暂无交易记录'), findsOneWidget);
  });

  testWidgets('drops the net-income metric from the monthly summary', (
    tester,
  ) async {
    await _pumpCalendar(tester, dayTransactions: const []);

    expect(find.text('收入 '), findsOneWidget);
    expect(find.text('支出 '), findsOneWidget);
    expect(find.text('净收入 '), findsNothing);
  });

  testWidgets('tints day cells once the heatmap is enabled', (tester) async {
    final store = _InMemoryAppSettingsStore();
    await _pumpCalendar(
      tester,
      dayTransactions: const [],
      settingsStore: store,
    );

    expect(_dayCellColor(tester, '20'), Colors.transparent);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('热力图'));
    await tester.pumpAndSettle();

    // 维度选择只在热力图开启后出现，且开启不关闭菜单。
    expect(find.text('热力维度'), findsOneWidget);

    final financeColors = AppTheme.light().extension<AppThemeExtension>()!;
    expect(
      _dayCellColor(tester, '20'),
      financeColors.expense.withValues(alpha: AppHeatScale.maxAlpha),
    );
    // 选中日保留热力底色，选中态由描边表达。
    expect(
      _dayCellColor(tester, '15'),
      financeColors.expense.withValues(
        alpha: AppHeatScale.alphaForIntensity(5000 / 40000),
      ),
    );
    expect(
      _dayCellBorder(tester, '15')?.top,
      BorderSide(color: AppTheme.light().colorScheme.primary, width: 2),
    );
  });

  testWidgets('persists the heatmap switch and metric', (tester) async {
    final store = _InMemoryAppSettingsStore();
    await _pumpCalendar(
      tester,
      dayTransactions: const [],
      settingsStore: store,
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('热力图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('热力维度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('净收入'));
    await tester.pumpAndSettle();

    final saved = await store.read();
    expect(saved.calendarHeatmapEnabled, true);
    expect(saved.calendarHeatMetric, CalendarHeatMetric.net);
  });

  testWidgets('loads the next day page when scrolled to the end', (
    tester,
  ) async {
    final service = _FakeTransactionQueryService(
      nextPage: [
        _item(_selectedDate.add(const Duration(hours: 1)), id: 'older'),
      ],
    );
    await _pumpCalendar(
      tester,
      transactionService: service,
      dayTransactions: [
        for (var index = 0; index < calendarTransactionPageSize; index++)
          _item(_selectedDate.add(const Duration(hours: 9)), id: 'tx-$index'),
      ],
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -8000));
    await tester.pumpAndSettle();

    final paged = service.queries.where((query) => query.before != null);
    expect(paged, isNotEmpty);
    expect(paged.last.occurredFrom, _selectedDate);
    expect(paged.last.occurredUntil, DateTime(2026, 1, 16));
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required List<TransactionListReadModel> dayTransactions,
  _FakeTransactionQueryService? transactionService,
  AppSettingsStore? settingsStore,
}) async {
  tester.view.physicalSize = const Size(600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          settingsStore ?? _InMemoryAppSettingsStore(),
        ),
        currentDateTimeProvider.overrideWith(
          (ref) => _selectedDate.add(const Duration(hours: 9)),
        ),
        transactionQueryServiceProvider.overrideWithValue(
          transactionService ?? _FakeTransactionQueryService(),
        ),
        creditAccountQueryServiceProvider.overrideWithValue(
          const _FakeCreditAccountQueryService(),
        ),
        accountQueryServiceProvider.overrideWithValue(
          _FakeAccountQueryService(),
        ),
        calendarTransactionsProvider(
          _selectedDate,
        ).overrideWith((ref) => Stream.value(dayTransactions)),
        calendarCashflowComparisonProvider(
          _visibleMonth,
        ).overrideWith((ref) => Stream.value(_comparison())),
        calendarDailyCashflowSummariesProvider(_visibleMonth).overrideWith(
          (ref) => Stream.value([
            DailyCashflowSummary(
              date: _selectedDate,
              income: const Money(minorUnits: 10000),
              expense: const Money(minorUnits: 5000),
            ),
            DailyCashflowSummary(
              date: DateTime(2026, 1, 20),
              income: Money.zero(),
              expense: const Money(minorUnits: 40000),
            ),
          ]),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const CalendarPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _dayCellColor(WidgetTester tester, String dayLabel) {
  return _dayCellDecoration(tester, dayLabel)?.color;
}

BoxBorder? _dayCellBorder(WidgetTester tester, String dayLabel) {
  return _dayCellDecoration(tester, dayLabel)?.border;
}

BoxDecoration? _dayCellDecoration(WidgetTester tester, String dayLabel) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text(dayLabel),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return container.decoration as BoxDecoration?;
}

TransactionListReadModel _item(DateTime occurredAt, {String id = 'tx-1'}) {
  return TransactionListReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyIncome,
    occurredAt: occurredAt,
    primaryAmount: const Money(minorUnits: 10000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    primaryCategoryId: null,
    impactsByAccountId: const {},
    adjustments: const [],
  );
}

CashflowComparison _comparison() {
  return const CashflowComparison(
    current: CashflowSummary(
      income: Money(minorUnits: 10000),
      expense: Money(minorUnits: 0),
    ),
    previousSamePeriod: CashflowSummary(
      income: Money(minorUnits: 0),
      expense: Money(minorUnits: 0),
    ),
    previousFullPeriod: CashflowSummary(
      income: Money(minorUnits: 0),
      expense: Money(minorUnits: 0),
    ),
  );
}

class _InMemoryAppSettingsStore implements AppSettingsStore {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> read() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

class _FakeTransactionQueryService implements TransactionQueryService {
  _FakeTransactionQueryService({
    List<TransactionListReadModel> nextPage = const [],
  }) : _nextPage = nextPage;

  final List<TransactionListReadModel> _nextPage;
  final queries = <TransactionListQuery>[];

  @override
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return const Stream.empty();
  }

  @override
  Future<List<TransactionListReadModel>> findTransactions(
    TransactionListQuery query,
  ) async {
    queries.add(query);
    return _nextPage;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountQueryService implements AccountQueryService {
  @override
  Stream<Map<String, Account>> watchAccountsById() {
    return Stream.value(const {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCreditAccountQueryService implements CreditAccountQueryService {
  const _FakeCreditAccountQueryService();

  @override
  Future<List<CreditDueCalendarItemReadModel>> listDueCalendarItems(
    CreditDueCalendarQuery query,
  ) async {
    return const [];
  }

  @override
  Future<List<MonthlyBillSummaryReadModel>> listMonthlyBillSummaries(
    MonthlyBillSummaryQuery query,
  ) async {
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
