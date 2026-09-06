import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/widget/installment_terms_editor.dart';

void main() {
  testWidgets(
    'credit cycle keeps date and structure controlled by the account',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: InstallmentTermsEditor(
                  value: InstallmentTermsDraft.loan(DateTime(2026, 1, 1)),
                  usesBillingCycle: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('按账户账期生成'), findsOneWidget);
      expect(find.text('首期还款日'), findsNothing);
      expect(find.text('添加还款阶段'), findsNothing);
      expect(find.byTooltip('删除阶段'), findsNothing);
      expect(
        tester
            .widget<AppPlainIntegerFormRow>(
              find.widgetWithText(AppPlainIntegerFormRow, '各期间隔'),
            )
            .enabled,
        isFalse,
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
}
