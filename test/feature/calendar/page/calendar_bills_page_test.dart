import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/feature/calendar/page/calendar_bills_page.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_bills_view_model.dart';

void main() {
  final date = DateTime(2026, 1, 15);
  final month = DateTime(2026, 1);
  const title = '2026年1月账单';
  for (final state in [
    const CalendarBillsPageState.loading(title: title),
    const CalendarBillsPageState.error(title: title, message: '账单加载失败'),
    const CalendarBillsPageState.loaded(
      title: title,
      emptyMessage: '暂无账单',
      rows: [],
    ),
  ]) {
    for (final monthly in [false, true]) {
      testWidgets(
        '${monthly ? 'month' : 'day'} bills retain a full header and back navigation in ${state.runtimeType}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                calendarDayBillsViewModelProvider(
                  date,
                ).overrideWith((ref) => state),
                calendarMonthBillsViewModelProvider(
                  month,
                ).overrideWith((ref) => state),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 24),
                    viewPadding: const EdgeInsets.only(top: 24),
                  ),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => monthly
                              ? CalendarMonthBillsPage(month: month)
                              : CalendarDayBillsPage(date: date),
                        ),
                      ),
                      child: const Text('查看账单'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('查看账单'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          final header = tester.getRect(find.byType(AppPageHeader));
          expect(header.left, 0);
          expect(header.width, 320);
          expect(header.top, 24);
          expect(find.text(title), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byTooltip('返回'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('查看账单'), findsOneWidget);
        },
      );
    }
  }
}
