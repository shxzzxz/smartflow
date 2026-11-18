import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/insurance/insurance_command_api.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/insurance/view_model/commercial_insurance_responsibilities_view_model.dart';
import 'package:smartflow/feature/insurance/widget/insurance_responsibility_editor.dart';

void main() {
  testWidgets('common responsibility names follow the selected type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    InsuranceResponsibilityDraft? saved;
    await _openEditor(tester, (context) async {
      saved = await showInsuranceResponsibilityEditor(
        context: context,
        existing: null,
        newResponsibilityId: () => 'new-responsibility',
      );
    });
    expect(find.text('一般医疗'), findsOneWidget);
    await _enterField(tester, 'responsibility-name', '我的责任');
    await tester.ensureVisible(find.text('疾病给付'));
    await tester.tap(find.text('疾病给付'));
    await tester.pumpAndSettle();
    expect(find.text('一般医疗'), findsNothing);
    expect(find.text('重大疾病'), findsOneWidget);
    expect(
      tester.widget<TextField>(_field('responsibility-name')).controller!.text,
      '我的责任',
    );
    await tester.ensureVisible(find.text('轻症'));
    await tester.tap(find.text('轻症'));
    await _enterField(
      tester,
      'responsibility-description',
      '  符合合同约定的轻症条件\n赔付金额以合同为准  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(saved!.kind, ResponsibilityKind.diseaseBenefit);
    expect(saved!.name, '轻症');
    expect(saved!.description, '符合合同约定的轻症条件\n赔付金额以合同为准');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'point suggestions omit used names and keep free input validation',
    (tester) async {
      InsurancePointDraft? saved;
      await _openEditor(tester, (context) async {
        saved = await showInsurancePointEditor(
          context: context,
          responsibilityKind: ResponsibilityKind.medical,
          existing: null,
          existingLabels: {'保障额度', ' 免赔额 '},
          newPointId: () => 'new-point',
        );
      });
      expect(find.text('保障额度'), findsNothing);
      expect(find.text('免赔额'), findsNothing);
      await _enterField(tester, 'responsibility-point-name', '免赔额');
      await _enterField(tester, 'responsibility-point-value', '二级及以上公立医院普通部');
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pumpAndSettle();
      expect(find.text('同一责任项内的要点名称不能重复'), findsOneWidget);
      await tester.ensureVisible(find.text('医院范围'));
      await tester.tap(find.text('医院范围'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pumpAndSettle();

      expect(saved!.label, '医院范围');
      expect(saved!.value, '二级及以上公立医院普通部');
    },
  );

  testWidgets(
    'medical suggestions remain usable on a phone with the keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      InsurancePointDraft? saved;
      await _openEditor(tester, (context) async {
        saved = await showInsurancePointEditor(
          context: context,
          responsibilityKind: ResponsibilityKind.medical,
          existing: null,
          existingLabels: {},
          newPointId: () => 'new-point',
        );
      });
      await tester.ensureVisible(find.text('临床急需进口药械'));
      await tester.tap(find.text('临床急需进口药械'));
      await _enterField(tester, 'responsibility-point-value', '合同约定范围');
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pumpAndSettle();

      expect(saved!.label, '临床急需进口药械');
      expect(saved!.value, '合同约定范围');
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

Future<void> _enterField(WidgetTester tester, String key, String text) async {
  final field = _field(key);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _openEditor(
  WidgetTester tester,
  Future<void> Function(BuildContext) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('打开编辑器'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开编辑器'));
  await tester.pumpAndSettle();
}
