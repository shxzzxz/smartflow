import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';

void main() {
  group('syncTextControllerText', () {
    test('does not touch selection when text is unchanged', () {
      final controller = TextEditingController(text: '12.34');
      controller.selection = const TextSelection.collapsed(offset: 2);

      syncTextControllerText(controller, '12.34');

      expect(controller.text, '12.34');
      expect(controller.selection.baseOffset, 2);
    });

    test('updates text and moves cursor to the end', () {
      final controller = TextEditingController(text: '1');
      controller.selection = const TextSelection.collapsed(offset: 0);

      syncTextControllerText(controller, '123');

      expect(controller.text, '123');
      expect(controller.selection.baseOffset, 3);
    });
  });

  group('AppDropdownFormField', () {
    testWidgets('routes user changes through field state and resets value', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final changes = <String?>[];
      var value = 'a';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Form(
                  key: formKey,
                  child: AppDropdownFormField<String>(
                    value: value,
                    items: const [
                      DropdownMenuItem(value: 'a', child: Text('Alpha')),
                      DropdownMenuItem(value: 'b', child: Text('Beta')),
                    ],
                    onChanged: (next) {
                      changes.add(next);
                      setState(() => value = next ?? '');
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();

      expect(value, 'b');
      expect(changes, ['b']);

      formKey.currentState!.reset();
      await tester.pump();

      expect(value, 'a');
      expect(changes, ['b', 'a']);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        'a',
      );
    });

    testWidgets('uses programmatic value updates for validation', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      late StateSetter updateHost;
      String? validatedValue;
      var value = 'a';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Scaffold(
                body: Form(
                  key: formKey,
                  child: AppDropdownFormField<String>(
                    value: value,
                    items: const [
                      DropdownMenuItem(value: 'a', child: Text('Alpha')),
                      DropdownMenuItem(value: 'b', child: Text('Beta')),
                    ],
                    onChanged: (_) {},
                    validator: (candidate) {
                      validatedValue = candidate;
                      return candidate == 'b' ? null : '请选择 Beta';
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      updateHost(() => value = 'b');
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      expect(validatedValue, 'b');
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        'b',
      );
    });

    testWidgets('is non-interactive without an external change handler', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdownFormField<String>(
              value: 'a',
              items: const [
                DropdownMenuItem(value: 'a', child: Text('Alpha')),
                DropdownMenuItem(value: 'b', child: Text('Beta')),
              ],
              onChanged: null,
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .onChanged,
        isNull,
      );
    });
  });

  testWidgets('AppPlainTextFormField saves the latest focused text', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: 'old');
    addTearDown(controller.dispose);
    String? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppPlainTextFormField(
              controller: controller,
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'latest');
    formKey.currentState!.save();

    expect(saved, 'latest');
  });
}
