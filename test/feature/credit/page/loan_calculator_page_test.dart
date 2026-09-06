import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_detail_summary_card.dart';
import 'package:smartflow/feature/credit/page/loan_calculator_page.dart';

void main() {
  Future<void> openCalculator(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoanCalculatorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('生成还款计划'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('生成还款计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成还款计划'));
    await tester.pumpAndSettle();
  }

  testWidgets('generates a plan from the form on a phone-sized screen', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.enterText(find.byType(TextField).first, '12000');
    await generate(tester);

    await tester.scrollUntilVisible(
      find.text('总还款'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('还款计划'), findsOneWidget);
    expect(find.text('12000.00'), findsWidgets);
    expect(find.text('12 期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presets replace stage fields without losing the principal', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.enterText(find.byType(TextField).first, '12000');
    await tester.tap(find.byTooltip('产品预设'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('国家助学贷款'));
    await tester.pumpAndSettle();
    expect(find.text('阶段 1 · 免还期'), findsOneWidget);
    expect(find.text('只推进时间线，不产生期次，也不计息'), findsNothing);
    final titleCenter = tester.getCenter(find.text('阶段 1 · 免还期'));
    final deleteButton = find.widgetWithText(TextButton, '删除阶段').first;
    final deleteCenter = tester.getCenter(deleteButton);
    expect(deleteCenter.dy, closeTo(titleCenter.dy, 1));
    expect(deleteCenter.dx, greaterThan(titleCenter.dx));
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('阶段 1 · 免还期'), findsNothing);
    expect(find.text('阶段 1 · 还款阶段'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('产品预设'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一次性手续费'));
    await tester.pumpAndSettle();
    expect(find.text('阶段 1 · 免还期'), findsNothing);
    expect(find.text('手续费'), findsOneWidget);
    expect(find.text('期数'), findsNothing);
    expect(find.text('各期间隔'), findsNothing);
    expect(find.text('末期还款日'), findsNothing);
    expect(find.text('利率'), findsNothing);
    expect(find.text('计息方式'), findsNothing);
    expect(find.text('固定额算法'), findsNothing);
    await generate(tester);
    await tester.scrollUntilVisible(
      find.text('总手续费'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byType(AppDetailSummaryCard),
        matching: find.text('1056.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppDetailSummaryCard),
        matching: find.text('13056.00'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selects the fixed amount algorithm and switches repayment fields',
    (tester) async {
      await openCalculator(tester);
      expect(find.text('各期间隔'), findsOneWidget);
      expect(find.text('阶段手续费'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('固定额算法'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('固定名义期利率'));
      await tester.pumpAndSettle();
      expect(find.text('动态实际期利率'), findsOneWidget);
      await tester.tap(find.text('指定固定额'));
      await tester.pumpAndSettle();
      expect(find.text('固定还款额'), findsOneWidget);

      await tester.ensureVisible(find.text('还款方式'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('等额本息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('一次性手续费'));
      await tester.pumpAndSettle();
      expect(find.text('手续费'), findsOneWidget);
      expect(find.text('固定还款额'), findsNothing);
      expect(find.text('计息方式'), findsNothing);
      expect(find.text('各期间隔'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
