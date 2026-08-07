import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/design_system/widget/app_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_select.dart';

void main() {
  testWidgets('text row participates in Form validation', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppPlainTextFormRow(
              label: '账户名称',
              requiredIndicator: true,
              controller: controller,
              hintText: '填写名称',
              validator:
                  (value) => value == null || value.isEmpty ? '请输入账户名称' : null,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('请输入账户名称'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '工资卡');
    expect(formKey.currentState!.validate(), true);
  });

  testWidgets('programmatic controller changes participate in validation', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppPlainTextFormRow(
              label: '账户名称',
              controller: controller,
              validator:
                  (value) => value == null || value.isEmpty ? '请输入账户名称' : null,
            ),
          ),
        ),
      ),
    );

    controller.text = '工资卡';
    expect(formKey.currentState!.validate(), true);
  });

  testWidgets('controller clear participates in validation', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: '工资卡');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppPlainTextFormRow(
              label: '账户名称',
              controller: controller,
              validator:
                  (value) => value == null || value.isEmpty ? '请输入账户名称' : null,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), true);

    controller.clear();

    expect(formKey.currentState!.validate(), false);
  });

  testWidgets('replacing controller detaches the old listener', (tester) async {
    final formKey = GlobalKey<FormState>();
    final oldController = TextEditingController(text: '旧值');
    final newController = TextEditingController();
    addTearDown(oldController.dispose);
    addTearDown(newController.dispose);
    late StateSetter rebuild;
    var controller = oldController;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Form(
                key: formKey,
                child: AppPlainTextFormRow(
                  label: '账户名称',
                  controller: controller,
                  validator:
                      (value) =>
                          value == null || value.isEmpty ? '请输入账户名称' : null,
                ),
              );
            },
          ),
        ),
      ),
    );

    rebuild(() => controller = newController);
    await tester.pump();

    oldController.text = '旧 controller 后续修改';
    expect(formKey.currentState!.validate(), false);

    newController.text = '新 controller';
    expect(formKey.currentState!.validate(), true);
  });

  testWidgets('controller normalization does not recursively call onChanged', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppPlainTextFormRow(
              label: '账户名称',
              controller: controller,
              onChanged: (value) {
                changes++;
                if (value == 'a') controller.text = '标准值';
              },
              validator: (value) => value == '标准值' ? null : '值未同步',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a');

    expect(changes, 1);
    expect(controller.text, '标准值');
    expect(formKey.currentState!.validate(), true);
  });

  testWidgets('form reset restores controller text', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: '初始值');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppPlainTextFormRow(label: '账户名称', controller: controller),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '修改后');
    formKey.currentState!.reset();

    expect(controller.text, '初始值');
  });

  testWidgets('select row validates and invokes whole-row tap', (tester) async {
    final formKey = GlobalKey<FormState>();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppPlainSelectFormRow<String>(
              label: '账户',
              value: null,
              placeholder: '请选择账户',
              onTap: (_) => taps++,
              validator: (value) => value == null ? '请选择账户' : null,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('请选择账户'));
    expect(taps, 1);

    expect(formKey.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('请选择账户'), findsNWidgets(2));
  });

  testWidgets('select row starts values at the editable value anchor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPlainSelectFormRow<String>(
            label: '账户',
            value: 'cash',
            valueText: '现金',
            placeholder: '请选择账户',
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(tester.widget<Text>(find.text('现金')).textAlign, TextAlign.left);
  });

  testWidgets('integer row keeps digits only', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPlainIntegerFormRow(
            label: '期数',
            controller: controller,
            hintText: '总期数',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '12a');
    expect(controller.text, '12');
  });

  testWidgets('select rows can share the same selected value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppPlainSelectFormRow<String>(
                label: '转出账户',
                value: 'cash',
                valueText: '现金',
                placeholder: '请选择账户',
                onTap: (_) {},
              ),
              AppPlainSelectFormRow<String>(
                label: '转入账户',
                value: 'cash',
                valueText: '现金',
                placeholder: '请选择账户',
                onTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('select row keeps value, field state, and page state in sync', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    late StateSetter rebuild;
    String? selectedId = 'cash';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Form(
                key: formKey,
                child: AppPlainSelectFormRow<String>(
                  label: '账户',
                  value: selectedId,
                  valueText: selectedId,
                  placeholder: '请选择账户',
                  onTap: (onSelected) => onSelected('bank'),
                  onChanged: (value) => rebuild(() => selectedId = value),
                  validator: (value) => value == 'bank' ? null : '请选择银行卡',
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), false);

    await tester.tap(find.text('cash'));
    await tester.pump();

    expect(selectedId, 'bank');
    expect(find.text('请选择银行卡'), findsNothing);
    expect(formKey.currentState!.validate(), true);

    formKey.currentState!.reset();
    await tester.pump();

    expect(selectedId, 'cash');
    expect(find.text('cash'), findsOneWidget);
  });

  testWidgets('menu select row updates and resets through Form state', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var selected = _TestChoice.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: AppPlainSelectMenuFormRow<_TestChoice>(
                  label: '分期方式',
                  value: selected,
                  options: const [
                    AppSelectOption(value: _TestChoice.first, label: '等额本息'),
                    AppSelectOption(value: _TestChoice.second, label: '等额本金'),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('选择分期方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('等额本金'));
    await tester.pumpAndSettle();
    expect(selected, _TestChoice.second);

    formKey.currentState!.reset();
    await tester.pump();
    expect(selected, _TestChoice.first);
  });

  testWidgets('menu select row exposes validation and disabled states', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var selected = _TestChoice.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: Column(
                  children: [
                    AppPlainSelectMenuFormRow<_TestChoice>(
                      label: '菜单选择',
                      value: selected,
                      options: const [
                        AppSelectOption(value: _TestChoice.first, label: '第一项'),
                        AppSelectOption(
                          value: _TestChoice.second,
                          label: '第二项',
                        ),
                      ],
                      validator:
                          (value) =>
                              value == _TestChoice.second ? null : '请选择第二项',
                      autovalidateMode: AutovalidateMode.always,
                      onChanged: (value) => setState(() => selected = value),
                    ),
                    const AppPlainSelectMenuFormRow<_TestChoice>(
                      label: '禁用菜单',
                      value: _TestChoice.first,
                      options: [
                        AppSelectOption(value: _TestChoice.first, label: '第一项'),
                        AppSelectOption(
                          value: _TestChoice.second,
                          label: '第二项',
                        ),
                      ],
                      enabled: false,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('请选择第二项'), findsOneWidget);
    expect(find.byType(Opacity), findsOneWidget);
    expect(formKey.currentState!.validate(), false);
  });

  testWidgets('segmented row updates and resets through Form state', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var selected = _TestChoice.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: AppPlainSegmentedFormRow<_TestChoice>(
                  label: '计息方式',
                  value: selected,
                  segments: const [
                    AppSegment(value: _TestChoice.first, label: '按日'),
                    AppSegment(value: _TestChoice.second, label: '按月'),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('按月'));
    await tester.pump();
    expect(selected, _TestChoice.second);
    final segmentedButton = tester.widget<SegmentedButton<_TestChoice>>(
      find.byType(SegmentedButton<_TestChoice>),
    );
    expect(
      segmentedButton.style?.textStyle?.resolve({
        WidgetState.selected,
      })?.fontSize,
      15,
    );

    formKey.currentState!.reset();
    await tester.pump();
    expect(selected, _TestChoice.first);
  });

  testWidgets('segmented row supports a disabled display state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPlainSegmentedFormRow<_TestChoice>(
            label: '计息方式',
            value: _TestChoice.first,
            segments: [
              AppSegment(value: _TestChoice.first, label: '按日'),
              AppSegment(value: _TestChoice.second, label: '按月'),
            ],
            onChanged: null,
          ),
        ),
      ),
    );

    expect(find.byType(Opacity), findsOneWidget);
    await tester.tap(find.text('按月'), warnIfMissed: false);
    expect(tester.takeException(), isNull);
  });
}

enum _TestChoice { first, second }
