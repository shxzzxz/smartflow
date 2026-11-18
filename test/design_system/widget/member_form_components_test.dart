import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_choice_chip_group.dart';
import 'package:smartflow/design_system/widget/app_plain_form_row.dart';
import 'package:smartflow/design_system/widget/app_plain_text_area_form_row.dart';

void main() {
  testWidgets('choice chip form row updates the selected value', (
    tester,
  ) async {
    var selected = _Choice.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppPlainChoiceChipFormRow<_Choice>(
              label: '关系',
              value: selected,
              options: const [
                AppChoiceChipOption(value: _Choice.first, label: '本人'),
                AppChoiceChipOption(value: _Choice.second, label: '配偶'),
              ],
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('配偶'));
    await tester.pump();

    expect(selected, _Choice.second);
  });

  testWidgets('compact choice rows keep one and two row heights equal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _choiceForm(
        options: const [AppChoiceChipOption(value: _Choice.first, label: '本人')],
      ),
    );
    final oneRowHeight = tester.getSize(find.byType(AppPlainFormRow)).height;
    final labelStyle = tester.widget<Text>(find.text('本人')).style;

    await tester.pumpWidget(
      _choiceForm(
        options: const [
          AppChoiceChipOption(value: _Choice.first, label: '一次性'),
          AppChoiceChipOption(value: _Choice.second, label: '月缴'),
          AppChoiceChipOption(value: _Choice.third, label: '季缴'),
          AppChoiceChipOption(value: _Choice.fourth, label: '半年缴'),
          AppChoiceChipOption(value: _Choice.fifth, label: '年缴'),
          AppChoiceChipOption(value: _Choice.sixth, label: '其他'),
        ],
      ),
    );
    final twoRowHeight = tester.getSize(find.byType(AppPlainFormRow)).height;
    final twoRowLabelStyle = tester.widget<Text>(find.text('月缴')).style;

    expect(twoRowHeight, oneRowHeight);
    expect(oneRowHeight, greaterThan(48));
    expect(labelStyle?.fontSize, 12);
    expect(twoRowLabelStyle?.fontSize, labelStyle?.fontSize);
  });

  testWidgets('text area row counts and limits characters', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppPlainTextAreaFormRow(
            label: '备注',
            controller: controller,
            maxLength: 5,
          ),
        ),
      ),
    );

    expect(find.text('0/5'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'abcdef');
    await tester.pump();

    expect(controller.text, 'abcde');
    expect(find.text('5/5'), findsOneWidget);
  });

  testWidgets('vertical text area keeps paragraphs and validation full width', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: AppPlainTextAreaFormRow(
                label: '说明',
                controller: controller,
                layout: AppPlainFormRowLayout.vertical,
                requiredIndicator: true,
                supportingText: '支持输入多行说明',
                validator: (value) =>
                    value == null || value.isEmpty ? '请填写说明' : null,
              ),
            ),
          ),
        ),
      ),
    );

    final input = find.byType(TextField);
    expect(
      tester.getBottomLeft(find.text('说明')).dy,
      lessThan(tester.getTopLeft(input).dy),
    );
    expect(tester.getSize(input).width, 360);
    final paragraph = '住院医疗保障\n${List.filled(100, '合同约定').join()}';
    await tester.enterText(input, paragraph);
    await tester.pump();

    expect(controller.text, paragraph);
    expect(formKey.currentState!.validate(), isTrue);
    controller.clear();
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('请填写说明'), findsOneWidget);
    expect(find.text('支持输入多行说明'), findsNothing);
    expect(
      tester.getTopLeft(find.text('请填写说明')).dx,
      tester.getTopLeft(input).dx,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _choiceForm({required List<AppChoiceChipOption<_Choice>> options}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: AppPlainChoiceChipFormRow<_Choice>(
            label: '选项',
            value: _Choice.first,
            options: options,
            size: AppChoiceChipSize.compact,
            reservedRows: 2,
          ),
        ),
      ),
    ),
  );
}

enum _Choice { first, second, third, fourth, fifth, sixth }
