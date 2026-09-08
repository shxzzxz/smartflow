import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/credit/product/installment_product_service.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_detail_summary_card.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/feature/credit/page/loan_calculator_page.dart';
import 'package:smartflow/feature/credit/page/loan_configuration_page.dart';
import 'package:smartflow/feature/credit/page/loan_plan_page.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';
import 'package:smartflow/feature/credit/view_model/loan_prepayment_view_model.dart';
import 'package:smartflow/feature/credit/widget/installment_stage_card.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

class _Products extends Mock implements InstallmentProductService {}

void main() {
  late ProviderContainer scope;
  late _Products products;
  setUp(() {
    products = _Products();
    when(() => products.list()).thenAnswer((_) async => [_student, _fixed]);
    scope = ProviderContainer(
      overrides: [
        installmentProductServiceProvider.overrideWithValue(products),
      ],
    );
  });
  tearDown(() => scope.dispose());

  Future<void> openCalculator(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoanCalculatorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label).first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(label).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hub opens configuration and a separate result; back retains inputs',
    (tester) async {
      await openCalculator(tester);
      expect(find.text('贷款试算'), findsOneWidget);
      expect(find.text('贷款比较'), findsOneWidget);
      expect(find.text('提前还款试算'), findsOneWidget);
      await tap(tester, '贷款试算');
      expect(find.text('计算约定'), findsNothing);
      expect(find.text('固定额算法'), findsNothing);
      await tester.enterText(find.byType(TextField).first, '12000');
      await tap(tester, '生成还款计划');
      expect(find.byType(LoanPlanPage), findsOneWidget);
      expect(find.byType(LoanConfigurationPage), findsNothing);
      expect(find.text('总还款'), findsOneWidget);
      expect(find.textContaining('实际年化（XIRR）'), findsOneWidget);
      expect(find.text('月 IRR'), findsNothing);
      expect(find.textContaining('固定额'), findsNothing);
      expect(find.text('12 期'), findsOneWidget);
      Navigator.of(tester.element(find.byType(LoanPlanPage))).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '12000',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('product loads only rules and retains stage header controls', (
    tester,
  ) async {
    await openCalculator(tester);
    await tap(tester, '贷款试算');
    await tester.enterText(find.byType(TextField).first, '12000');
    await tap(tester, '产品模板');
    expect(find.text('管理分期产品'), findsNothing);
    await tap(tester, '国家助学贷款');
    expect(find.text('免还期'), findsOneWidget);
    expect(find.text('免还至'), findsOneWidget);
    final titleCenter = tester.getCenter(find.text('免还期'));
    final deleteButton = find.byTooltip('删除阶段').first;
    final deleteCenter = tester.getCenter(deleteButton);
    expect(deleteCenter.dy, closeTo(titleCenter.dy, 1));
    expect(deleteCenter.dx, greaterThan(titleCenter.dx));
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('免还期'), findsNothing);
    expect(
      tester
          .widget<InstallmentStageCard>(find.byType(InstallmentStageCard).first)
          .title,
      '还款阶段',
    );
    final state = scope.read(loanConfigurationViewModelProvider());
    for (final stage in state.terms.stages) {
      expect(stage.text(StageInput.rate), isEmpty);
      expect(stage.text(StageInput.periods), isEmpty);
      expect(stage.firstDate, isNull);
    }
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '12000',
    );
    verify(() => products.list()).called(1);
    verifyNoMoreInteractions(products);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'regular mode still shows required fixed amount and switching preserves rules',
    (tester) async {
      await openCalculator(tester);
      await tap(tester, '贷款试算');
      await tap(tester, '产品模板');
      await tap(tester, '指定固定额产品');
      expect(find.text('固定额算法'), findsNothing);
      expect(find.text('固定还款额'), findsOneWidget);
      await tap(tester, '高级配置');
      expect(find.text('计算约定'), findsOneWidget);
      expect(find.text('固定额算法'), findsOneWidget);
      await tap(tester, '高级配置');
      expect(find.text('计算约定'), findsNothing);
      expect(find.text('固定还款额'), findsOneWidget);
      expect(
        scope
            .read(loanConfigurationViewModelProvider())
            .terms
            .stages
            .single
            .algorithm,
        InstallmentAmountAlgorithm.fixed,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comparison copies first configuration and cancelling edits preserves both',
    (tester) async {
      await openCalculator(tester);
      await tap(tester, '贷款比较');
      await tap(tester, '配置一');
      await tester.enterText(find.byType(TextField).first, '12000');
      await tap(tester, '使用此配置');
      await tap(tester, '复制配置一到配置二');
      expect(find.text('已配置'), findsNWidgets(2));
      final table = find.byType(Table);
      expect(
        find.descendant(of: table, matching: find.text('差值')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: table, matching: find.text('12000.00')),
        findsNWidgets(4),
      );
      await tap(tester, '配置二');
      await tester.enterText(find.byType(TextField).first, '24000');
      Navigator.of(tester.element(find.byType(LoanConfigurationPage))).pop();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: table, matching: find.text('24000.00')),
        findsNothing,
      );
      await tap(tester, '配置二');
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '12000.00',
      );
      await tester.enterText(find.byType(TextField).first, '24000');
      await tap(tester, '使用此配置');
      expect(
        find.descendant(of: table, matching: find.text('24000.00')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: table, matching: find.text('-12000.00')),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prepayment accepts multi-stage loan and puts savings before the schedule',
    (tester) async {
      final editorProvider = loanConfigurationViewModelProvider();
      final subscription = scope.listen(editorProvider, (_, _) {});
      final editor = scope.read(editorProvider.notifier);
      editor.setBorrowingDate(DateTime(2026, 1, 1));
      editor.setTerms(
        InstallmentTermsDraft(
          stages: [
            InstallmentStageDraft(
              id: 'defer',
              deferment: true,
              untilDate: DateTime(2026, 2, 1),
            ),
            InstallmentStageDraft(
              id: 'first',
              method: InstallmentRepaymentMethod.interestFirst,
              firstDate: DateTime(2026, 3, 1),
              inputs: const {
                StageInput.periods: '2',
                StageInput.interval: '1',
                StageInput.rate: '12',
              },
            ),
            InstallmentStageDraft(
              id: 'second',
              method: InstallmentRepaymentMethod.equalPrincipal,
              firstDate: DateTime(2026, 5, 1),
              inputs: const {
                StageInput.periods: '2',
                StageInput.interval: '1',
                StageInput.rate: '12',
                StageInput.fee: '40',
              },
            ),
          ],
        ),
      );
      final configuration =
          (await editor.submit('1200') as UiActionSuccess<LoanConfiguration>)
              .value;
      subscription.close();
      final prepaymentSubscription = scope.listen(
        loanPrepaymentViewModelProvider,
        (_, _) {},
      );
      addTearDown(prepaymentSubscription.close);
      final prepayment = scope.read(loanPrepaymentViewModelProvider.notifier);
      prepayment.setConfiguration(configuration);
      prepayment.setDate(DateTime(2026, 4, 2));
      await openCalculator(tester);
      await tap(tester, '提前还款试算');
      expect(find.byType(InstallmentStageCard), findsNothing);
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.enterText(find.byType(TextField).last, '300');
      await tap(tester, '试算');
      expect(find.text('提前还款结果'), findsOneWidget);
      expect(find.text('试算前息费'), findsOneWidget);
      expect(find.text('试算后息费'), findsOneWidget);
      expect(find.text('息费变化'), findsOneWidget);
      expect(find.text('阶段 2'), findsOneWidget);
      expect(find.text('阶段 3'), findsOneWidget);
      expect(find.textContaining('手续费 20.00'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.byType(AppDetailSummaryCard)).dy,
        lessThan(tester.getTopLeft(find.text('试算后还款计划')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

const _student = InstallmentProductReadModel(
  id: 'student',
  name: '国家助学贷款',
  archived: false,
  stages: [
    InstallmentStageRule.deferment(id: 'student-1'),
    InstallmentStageRule.repayment(
      id: 'student-2',
      method: InstallmentRepaymentMethod.interestFirst,
      intervalMonths: 12,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.annual,
    ),
    InstallmentStageRule.repayment(
      id: 'student-3',
      method: InstallmentRepaymentMethod.equalPrincipal,
      intervalMonths: 12,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.annual,
    ),
  ],
  dayCount: DayCountConvention.thirty360,
  rounding: RoundingMode.halfUp,
);
const _fixed = InstallmentProductReadModel(
  id: 'fixed',
  name: '指定固定额产品',
  archived: false,
  stages: [
    InstallmentStageRule.repayment(
      id: 'fixed-1',
      method: InstallmentRepaymentMethod.equalInstallment,
      intervalMonths: 1,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.monthly,
      amountAlgorithm: InstallmentAmountAlgorithm.fixed,
    ),
  ],
  dayCount: DayCountConvention.thirty365,
  rounding: RoundingMode.halfEven,
);
