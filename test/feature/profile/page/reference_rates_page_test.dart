import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/reference_rate/reference_rate_app_service.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/profile/page/reference_rates_page.dart';
import 'package:smartflow/feature/profile/presentation/reference_rates_presentation.dart';
import 'package:smartflow/feature/shared/presentation/reference_rate_presentation.dart';

class _Service extends Mock implements ReferenceRateAppService {}

void main() {
  testWidgets(
    'group tabs control current quotes and date-pivoted history; year only filters history',
    (tester) async {
      final service = _service();
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      expect(find.text('今日参考利率'), findsOneWidget);
      expect(find.byTooltip('刷新参考利率'), findsNothing);
      expect(find.text('数据源'), findsNothing);
      expect(_table(tester).rows, hasLength(3));
      expect(_table(tester).columns, hasLength(3));
      expect(_metric(InterestRateType.lprOneYear, '3.00%'), findsOneWidget);
      expect(
        _metric(InterestRateType.lprFiveYearPlus, '3.50%'),
        findsOneWidget,
      );
      expect(
        _table(tester).rows.last.cells.last.child,
        isA<Text>().having((text) => text.data, 'missing date value', '—'),
      );

      await _selectYear(tester, '2025 年');
      expect(_table(tester).rows, hasLength(1));
      expect(_metric(InterestRateType.lprOneYear, '3.00%'), findsOneWidget);
      await _switchGroup(tester, '贷款基准利率');
      expect(_table(tester).rows, hasLength(2));
      expect(
        _metric(InterestRateType.loanBenchmarkShortTerm, '4.35%'),
        findsOneWidget,
      );
      expect(
        _metric(InterestRateType.loanBenchmarkLongTerm, '4.90%'),
        findsOneWidget,
      );
      expect(find.text('全部年份'), findsOneWidget);
      await _selectYear(tester, '2015 年');
      await _switchGroup(tester, 'LPR');
      expect(find.text('2025 年'), findsOneWidget);
      expect(_table(tester).rows, hasLength(1));
      await _switchGroup(tester, '贷款基准利率');
      expect(find.text('2015 年'), findsOneWidget);
      verify(() => service.history(ReferenceRateGroup.lpr.types)).called(1);
      verify(
        () => service.history(ReferenceRateGroup.loanBenchmark.types),
      ).called(1);
    },
  );

  testWidgets(
    'cached content remains visible during updates and retry after a partial failure',
    (tester) async {
      final service = _service();
      final updates = StreamController<ReferenceRateHistory>();
      when(
        () => service.history(ReferenceRateGroup.lpr.types),
      ).thenAnswer((_) => updates.stream);
      await tester.pumpWidget(_app(service));
      await tester.pump();
      updates.add(_history(ReferenceRateGroup.lpr, updating: true));
      await tester.pump();
      expect(_table(tester).rows, hasLength(3));
      expect(_metric(InterestRateType.lprOneYear, '3.00%'), findsOneWidget);
      updates.add(
        _history(
          ReferenceRateGroup.lpr,
          failures: {
            InterestRateType.lprFiveYearPlus:
                ReferenceRateMissingReason.sourceUnavailable,
          },
        ),
      );
      await updates.close();
      await tester.pumpAndSettle();
      expect(find.text('五年期以上暂未更新'), findsOneWidget);
      expect(_table(tester).rows, hasLength(3));
      when(
        () => service.history(ReferenceRateGroup.lpr.types),
      ).thenAnswer((_) => Stream.value(_history(ReferenceRateGroup.lpr)));
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('五年期以上暂未更新'), findsNothing);
      expect(
        _metric(InterestRateType.lprFiveYearPlus, '3.50%'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a late result updates only its group and survives leaving the page',
    (tester) async {
      final service = _service();
      final lpr = StreamController<ReferenceRateHistory>();
      when(
        () => service.history(ReferenceRateGroup.lpr.types),
      ).thenAnswer((_) => lpr.stream);
      await tester.pumpWidget(_app(service));
      await tester.pump();
      await tester.tap(find.text('贷款基准利率'));
      await tester.pumpAndSettle();
      lpr.add(_history(ReferenceRateGroup.lpr));
      await tester.pumpAndSettle();
      expect(
        _metric(InterestRateType.loanBenchmarkLongTerm, '4.90%'),
        findsOneWidget,
      );
      await _switchGroup(tester, 'LPR');
      expect(_metric(InterestRateType.lprOneYear, '3.00%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      lpr.add(_history(ReferenceRateGroup.lpr));
      await lpr.close();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty and failed first loads provide distinct feedback and retry',
    (tester) async {
      final service = _service();
      when(() => service.history(ReferenceRateGroup.lpr.types)).thenAnswer(
        (_) => Stream.value(
          ReferenceRateHistory(asOf: DateTime.utc(2026, 9, 10), rates: []),
        ),
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      expect(find.text('暂无参考利率记录'), findsOneWidget);
      when(
        () => service.history(ReferenceRateGroup.loanBenchmark.types),
      ).thenAnswer(
        (_) => Stream.value(
          ReferenceRateHistory(
            asOf: DateTime.utc(2026, 9, 10),
            rates: [],
            failures: {
              for (final type in ReferenceRateGroup.loanBenchmark.types)
                type: ReferenceRateMissingReason.sourceUnavailable,
            },
          ),
        ),
      );
      await _switchGroup(tester, '贷款基准利率');
      expect(find.text('暂时无法获取参考利率，请重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('暂无参考利率记录'), findsNothing);
    },
  );

  testWidgets('pinned tabs retain each group scroll position', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _service();
    final rows = <ReferenceRate>[
      for (var month = 1; month <= 8; month++)
        for (final type in ReferenceRateGroup.lpr.types)
          ReferenceRate(
            type: type,
            date: DateTime.utc(2026, month, 20),
            ratePpm: 30000,
            source: 'eastmoney',
          ),
    ];
    when(() => service.history(ReferenceRateGroup.lpr.types)).thenAnswer(
      (_) => Stream.value(
        ReferenceRateHistory(asOf: DateTime.utc(2026, 9, 10), rates: rows),
      ),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final tabsY = tester.getTopLeft(find.byType(TabBar)).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    final offset = tester
        .widget<ListView>(find.byType(ListView))
        .controller!
        .offset;
    expect(offset, greaterThan(0));
    expect(tester.getTopLeft(find.byType(TabBar)).dy, tabsY);
    await _switchGroup(tester, '贷款基准利率');
    expect(
      tester.widget<ListView>(find.byType(ListView)).controller!.offset,
      0,
    );
    await _switchGroup(tester, 'LPR');
    expect(
      tester.widget<ListView>(find.byType(ListView)).controller!.offset,
      closeTo(offset, 1),
    );
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('fits $size dark=$dark with enlarged text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const scale = 1.5;
        await tester.pumpWidget(_app(_service(), dark: dark, scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _switchGroup(tester, '贷款基准利率');
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byType(DataTable),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(_table(tester).columns, hasLength(3));
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('formats integer ppm without losing significant digits', () {
    expect(referenceRatePercent(30501), '3.0501%');
    expect(referenceRatePercent(30000), '3.00%');
    expect(referenceRatePercent(0), '0.00%');
  });
}

_Service _service() {
  final service = _Service();
  for (final group in ReferenceRateGroup.values) {
    when(
      () => service.history(group.types),
    ).thenAnswer((_) => Stream.value(_history(group)));
  }
  return service;
}

ReferenceRateHistory _history(
  ReferenceRateGroup group, {
  bool updating = false,
  Map<InterestRateType, ReferenceRateMissingReason> failures = const {},
}) => ReferenceRateHistory(
  asOf: DateTime.utc(2026, 9, 10),
  updating: updating,
  failures: failures,
  rates: group == ReferenceRateGroup.lpr
      ? [
          ReferenceRate(
            type: InterestRateType.lprOneYear,
            date: DateTime.utc(2025, 12, 22),
            ratePpm: 31000,
            source: 'eastmoney',
          ),
          for (final month in [7, 8]) ...[
            ReferenceRate(
              type: InterestRateType.lprOneYear,
              date: DateTime.utc(2026, month, 20),
              ratePpm: 30000,
              source: 'eastmoney',
            ),
            ReferenceRate(
              type: InterestRateType.lprFiveYearPlus,
              date: DateTime.utc(2026, month, 20),
              ratePpm: 35000,
              source: 'chinamoney',
            ),
          ],
        ]
      : [
          ReferenceRate(
            type: InterestRateType.loanBenchmarkShortTerm,
            date: DateTime.utc(2015, 8, 26),
            ratePpm: 46000,
            source: 'eastmoney',
          ),
          ReferenceRate(
            type: InterestRateType.loanBenchmarkLongTerm,
            date: DateTime.utc(2015, 8, 26),
            ratePpm: 51500,
            source: 'eastmoney',
          ),
          ReferenceRate(
            type: InterestRateType.loanBenchmarkShortTerm,
            date: DateTime.utc(2015, 10, 24),
            ratePpm: 43500,
            source: 'eastmoney',
          ),
          ReferenceRate(
            type: InterestRateType.loanBenchmarkLongTerm,
            date: DateTime.utc(2015, 10, 24),
            ratePpm: 49000,
            source: 'eastmoney',
          ),
        ],
);

Widget _app(_Service service, {bool dark = false, double scale = 1}) {
  final base = dark ? AppTheme.dark() : AppTheme.light();
  return ProviderScope(
    overrides: [referenceRateAppServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      theme: base,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const ReferenceRatesPage(),
    ),
  );
}

Finder _metric(InterestRateType type, String text) => find.descendant(
  of: find.byKey(ValueKey('current-${type.name}')),
  matching: find.text(text),
);
DataTable _table(WidgetTester tester) =>
    tester.widget<DataTable>(find.byType(DataTable));
Future<void> _switchGroup(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _selectYear(WidgetTester tester, String option) async {
  await tester.ensureVisible(find.byTooltip('筛选历史年份'));
  await tester.tap(find.byTooltip('筛选历史年份'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}
