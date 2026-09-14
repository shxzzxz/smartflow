import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/widget/installment_terms_editor.dart';

void main() {
  testWidgets(
    'one rate selector and advanced repricing preserve the chosen policy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var advanced = false;
      late StateSetter rebuild;
      var draft = InstallmentTermsDraft(
        stages: [
          InstallmentStageDraft(
            id: 'loan',
            rateType: InterestRateType.lprFiveYearPlus,
            inPeriodRepricingPolicy: InPeriodRepricingPolicy.dynamicPeriodRate,
            firstDate: DateTime(2026, 2, 1),
            inputs: const {
              StageInput.periods: '12',
              StageInput.interval: '1',
              StageInput.rate: '3.2',
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SingleChildScrollView(
                  child: Form(
                    child: InstallmentTermsEditor(
                      value: draft,
                      showAdvanced: advanced,
                      onChanged: (value) => setState(() => draft = value),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('利率类型'), findsOneWidget);
      expect(find.text('利率'), findsOneWidget);
      expect(find.text('利率规则'), findsNothing);
      expect(find.text('参考利率类型'), findsNothing);
      expect(find.text('期中重定价'), findsNothing);
      final types = tester.widget<AppPlainSelectMenuFormRow<InterestRateType>>(
        find.byType(AppPlainSelectMenuFormRow<InterestRateType>),
      );
      expect(
        types.options.map((option) => option.value),
        InterestRateType.values,
      );
      rebuild(() => advanced = true);
      await tester.pumpAndSettle();
      expect(find.text('期中重定价'), findsOneWidget);
      expect(find.text('尾差处理'), findsOneWidget);
      await tester.tap(
        find.byType(AppPlainSelectMenuFormRow<InPeriodRepricingPolicy>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留当期本金').last);
      await tester.pumpAndSettle();
      rebuild(() => advanced = false);
      await tester.pumpAndSettle();
      expect(find.text('期中重定价'), findsNothing);
      expect(
        draft.stages.single.inPeriodRepricingPolicy,
        InPeriodRepricingPolicy.preservePrincipal,
      );
      expect(draft.stages.single.rateType, InterestRateType.lprFiveYearPlus);
      expect(draft.stages.single.text(StageInput.rate), '3.2');
    },
  );

  testWidgets(
    'product editor offers benchmark rules without per-loan rate or BP',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var draft = InstallmentTermsDraft.initial();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Form(
                  child: InstallmentTermsEditor(
                    value: draft,
                    mode: InstallmentTermsEditorMode.product,
                    onChanged: (value) => setState(() => draft = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byType(AppPlainSelectMenuFormRow<InterestRateType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('LPR 五年期以上').last);
      await tester.pumpAndSettle();
      expect(find.text('重定价周期'), findsOneWidget);
      expect(find.text('期中重定价'), findsOneWidget);
      expect(find.text('利率'), findsNothing);
      expect(find.text('加减基点'), findsNothing);
      expect(find.text('首次重定价日'), findsNothing);
      final rule = draft.productRules().single;
      expect(rule.rateType, InterestRateType.lprFiveYearPlus);
      expect(rule.repricingCycleMonths, 12);
      expect(draft.stages.single.text(StageInput.rate), isEmpty);
      expect(draft.stages.single.text(StageInput.spreadBp), isEmpty);
    },
  );

  testWidgets(
    'floating loan exposes reset dates, signed BP and payment timing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var draft = InstallmentTermsDraft(
        stages: [
          InstallmentStageDraft(
            id: 'floating',
            rateType: InterestRateType.lprFiveYearPlus,
            firstDate: DateTime(2026, 1, 20),
            firstResetDate: DateTime(2025, 12, 20),
            firstEffectiveDate: DateTime(2026, 1, 1),
            inputs: const {
              StageInput.rate: '3.2',
              StageInput.spreadBp: '-30',
              StageInput.periods: '120',
              StageInput.interval: '1',
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => SingleChildScrollView(
                child: Form(
                  child: InstallmentTermsEditor(
                    value: draft,
                    onChanged: (next) => update(() => draft = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('首次重定价日'), findsOneWidget);
      expect(find.text('首次生效日'), findsOneWidget);
      await tester.tap(
        find.byType(AppPlainSelectMenuFormRow<InterestRateType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('中长期贷款基准利率').last);
      await tester.pumpAndSettle();
      expect(
        draft.contractTerms().repayments.single.floatingRate!.referenceRateType,
        InterestRateType.loanBenchmarkLongTerm,
      );
      final field = find.descendant(
        of: find.widgetWithText(AppPlainTextFormRow, '加减基点'),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '-45');
      await tester.pump();
      expect(draft.stages.single.text(StageInput.spreadBp), '-45');
      final timing = tester
          .widget<AppPlainSelectMenuFormRow<InPeriodRepricingPolicy>>(
            find.byType(AppPlainSelectMenuFormRow<InPeriodRepricingPolicy>),
          );
      expect(timing.value, InPeriodRepricingPolicy.preservePrincipal);
      expect(
        draft.contractTerms().repayments.single.floatingRate!.spreadBp,
        -45,
      );
    },
  );
  testWidgets(
    'cash installment configuration keeps dates and structure editable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: InstallmentTermsEditor(
                  value: InstallmentTermsDraft.loan(DateTime(2026, 1, 1)),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('首期还款日'), findsOneWidget);
      expect(find.text('添加还款阶段'), findsOneWidget);
      expect(find.byTooltip('删除阶段'), findsOneWidget);
      expect(
        tester
            .widget<AppPlainIntegerFormRow>(
              find.widgetWithText(AppPlainIntegerFormRow, '间隔月数'),
            )
            .enabled,
        isTrue,
      );
      expect(
        tester
            .widget<AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>>(
              find.byType(
                AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>,
              ),
            )
            .enabled,
        isTrue,
      );
    },
  );
  testWidgets(
    'locked rules allow loan values and preserve edited input on reorder',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var draft = InstallmentTermsDraft.loan(DateTime(2026, 1, 1));
      var locked = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SingleChildScrollView(
                  child: Form(
                    child: InstallmentTermsEditor(
                      value: draft,
                      rulesEditable: !locked,
                      borrowingDate: DateTime(2026, 1, 1),
                      onChanged: (value) => setState(() => draft = value),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('添加还款阶段'), findsNothing);
      final method = tester
          .widget<AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>>(
            find.byType(AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>),
          );
      expect(method.enabled, isFalse);
      final rate = find.descendant(
        of: find.byKey(const ValueKey('draft-1:rate')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(rate, '7.25');
      await tester.pump();
      expect(draft.stages.single.text(StageInput.rate), '7.25');
      rebuild(() {
        locked = false;
        draft = draft.add(false, borrowingDate: DateTime(2026, 1, 1));
      });
      await tester.pump();
      await tester.tap(find.byTooltip('下移阶段').first);
      await tester.pump();
      expect(draft.stages.last.id, 'draft-1');
      expect(draft.stages.last.text(StageInput.rate), '7.25');
      final input = tester.widget<TextFormField>(rate);
      expect(input.controller!.text, '7.25');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('product mode hides loan values and validates only rules', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: form,
              child: InstallmentTermsEditor(
                mode: InstallmentTermsEditorMode.product,
                value: InstallmentTermsDraft.initial(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('期数'), findsNothing);
    expect(find.text('首期还款日'), findsNothing);
    expect(find.text('手续费'), findsNothing);
    expect(form.currentState!.validate(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'folding, moving and adding stages preserves input and expansion',
    (tester) async {
      final date = DateTime(2026, 9, 7);
      var draft = InstallmentTermsDraft.loan(
        date,
      ).add(true, borrowingDate: date);
      await _openEditor(tester, draft, onChanged: (next) => draft = next);

      expect(find.byTooltip('收起阶段 1'), findsOneWidget);
      expect(find.byTooltip('展开阶段 2'), findsOneWidget);
      expect(find.text('免还至'), findsNothing);
      expect(find.text('2026-09-07 → 2027-09-07'), findsOneWidget);
      expect(find.text('2027-09-07 → 2028-09-07'), findsOneWidget);

      final rate = find.descendant(
        of: find.byKey(const ValueKey('draft-1:rate')),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(rate);
      await tester.enterText(rate, '3.85');
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byTooltip('收起阶段 1'));
      expect(find.text('利率'), findsNothing);
      expect(find.text('等额本息 · 年利率 3.85%'), findsOneWidget);

      // 头部操作独立于折叠入口；移动后的字段与展开状态仍属于原阶段。
      await _tapVisible(tester, find.byTooltip('下移阶段').first);
      expect(draft.stages.last.id, 'draft-1');
      expect(find.byTooltip('展开阶段 2'), findsOneWidget);
      await _tapVisible(tester, find.byTooltip('展开阶段 2'));
      expect(tester.widget<EditableText>(rate).controller.text, '3.85');
      expect(find.byTooltip('展开阶段 1'), findsOneWidget);
      await _tapVisible(tester, find.byTooltip('收起阶段 2'));

      await _tapVisible(tester, find.text('添加还款阶段'));
      expect(draft.stages.length, 3);
      expect(find.byTooltip('收起阶段 3').hitTestable(), findsOneWidget);
      expect(find.byTooltip('展开阶段 2'), findsOneWidget);
      await _tapVisible(tester, find.byTooltip('删除阶段').last);
      expect(draft.stages.length, 2);
      expect(draft.stages.last.text(StageInput.rate), '3.85');
      expect(find.byTooltip('展开阶段 2'), findsOneWidget);
      expect(find.text('添加还款阶段'), findsOneWidget);
      expect(find.text('添加免还期'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'parent validation opens an untouched collapsed stage and reveals its error',
    (tester) async {
      final form = GlobalKey<FormState>();
      final date = DateTime(2026, 9, 7);
      var draft = InstallmentTermsDraft.loan(
        date,
      ).add(false, borrowingDate: date);
      draft = draft.replace(
        draft.stages.last.setInput(StageInput.periods, '0'),
      );
      await _openEditor(tester, draft, form: form);
      await _tapVisible(tester, find.byTooltip('收起阶段 1'));
      expect(find.text('期数'), findsNothing);

      expect(form.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.byTooltip('展开阶段 1'), findsOneWidget);
      expect(find.byTooltip('收起阶段 2'), findsOneWidget);
      expect(find.text('必须为正整数').hitTestable(), findsOneWidget);
      expect(find.text('有 1 项配置需要检查'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('draft-2:periods')),
          matching: find.byType(EditableText),
        ),
        '6',
      );
      await tester.pumpAndSettle();
      expect(find.text('有 1 项配置需要检查'), findsNothing);
      await _tapVisible(tester, find.byTooltip('收起阶段 2'));
      expect(form.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byTooltip('展开阶段 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'product summaries show rules without implying dates or zero interest',
    (tester) async {
      final date = DateTime(2026, 9, 7);
      await _openEditor(
        tester,
        InstallmentTermsDraft.loan(date).add(true, borrowingDate: date),
        mode: InstallmentTermsEditorMode.product,
      );
      await _tapVisible(tester, find.byTooltip('收起阶段 1'));
      expect(find.text('等额本息 · 年利率（本笔填写）'), findsOneWidget);
      expect(find.text('时间范围在本笔贷款中填写'), findsNWidgets(2));
      expect(find.text('免息'), findsNothing);
      expect(find.textContaining('2026-'), findsNothing);
      expect(find.textContaining('12 期'), findsNothing);
      expect(find.text('不还款、不计息'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'summaries span borrowing and previous stage ends with the selected rate unit',
    (tester) async {
      await _openEditor(
        tester,
        InstallmentTermsDraft(
          stages: [
            InstallmentStageDraft(
              id: 'repayment',
              firstDate: DateTime(2026, 10, 7),
              lastDate: DateTime(2027, 10, 7),
              inputs: const {
                StageInput.periods: '12',
                StageInput.interval: '1',
                StageInput.rate: '3.85',
              },
            ),
            InstallmentStageDraft(
              id: 'deferment',
              deferment: true,
              untilDate: DateTime(2028, 10, 7),
            ),
            InstallmentStageDraft(
              id: 'repayment-after-deferment',
              method: InstallmentRepaymentMethod.equalPrincipal,
              ratePeriod: InterestRatePeriod.monthly,
              firstDate: DateTime(2028, 11, 7),
              inputs: const {
                StageInput.periods: '2',
                StageInput.interval: '1',
                StageInput.rate: '0.5',
              },
            ),
          ],
        ),
      );
      await _tapVisible(tester, find.byTooltip('收起阶段 1'));
      expect(find.textContaining('借款日期'), findsNothing);
      expect(find.text('等额本息 · 年利率 3.85%'), findsOneWidget);
      expect(find.text('2026-09-07 → 2027-10-07'), findsOneWidget);
      expect(find.text('不还款、不计息'), findsOneWidget);
      expect(find.text('2027-10-07 → 2028-10-07'), findsOneWidget);
      expect(find.text('等额本金 · 月利率 0.5%'), findsOneWidget);
      expect(find.text('2028-10-07 → 2028-12-07'), findsOneWidget);
      expect(find.textContaining('12 期'), findsNothing);
      expect(find.textContaining('每月还款'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled header actions do not toggle the only stage', (
    tester,
  ) async {
    await _openEditor(tester, InstallmentTermsDraft.loan(DateTime(2026, 9, 7)));
    for (final tooltip in ['上移阶段', '下移阶段', '删除阶段']) {
      final button = find.byTooltip(tooltip);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: button, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNull,
      );
      await _tapVisible(tester, button);
      expect(find.byTooltip('收起阶段 1'), findsOneWidget);
    }
  });
}

Future<void> _openEditor(
  WidgetTester tester,
  InstallmentTermsDraft initial, {
  GlobalKey<FormState>? form,
  ValueChanged<InstallmentTermsDraft>? onChanged,
  InstallmentTermsEditorMode mode = InstallmentTermsEditorMode.contract,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  var draft = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: form,
              child: InstallmentTermsEditor(
                value: draft,
                borrowingDate: DateTime(2026, 9, 7),
                mode: mode,
                onChanged: (next) {
                  setState(() => draft = next);
                  onChanged?.call(next);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
