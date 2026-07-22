import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';

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
              onTap: () => taps++,
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
                onTap: () {},
              ),
              AppPlainSelectFormRow<String>(
                label: '转入账户',
                value: 'cash',
                valueText: '现金',
                placeholder: '请选择账户',
                onTap: () {},
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
                  onTap: () => rebuild(() => selectedId = 'bank'),
                  onChanged: (value) => rebuild(() => selectedId = value),
                  validator: (value) => value == 'bank' ? null : '请选择银行卡',
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
    expect(formKey.currentState!.validate(), true);

    formKey.currentState!.reset();
    await tester.pump();

    expect(selectedId, 'cash');
    expect(find.text('cash'), findsOneWidget);
  });
}
