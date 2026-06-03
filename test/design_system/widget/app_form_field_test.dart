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
}
