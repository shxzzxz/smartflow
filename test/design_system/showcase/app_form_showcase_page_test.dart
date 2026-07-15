import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/showcase/app_form_showcase_page.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';

void main() {
  for (final entry
      in <String, ThemeData>{
        'light': AppTheme.light(),
        'dark': AppTheme.dark(),
      }.entries) {
    testWidgets('renders form states in ${entry.key} theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: AppFormShowcasePage(),
          ),
        ),
      );

      expect(find.text('表单组件'), findsOneWidget);
      expect(find.text('文本输入'), findsOneWidget);
      expect(find.text('选择与状态'), findsOneWidget);
      expect(find.text('请选择账户'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .any((editable) => editable.focusNode.hasFocus),
        true,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      expect(find.text('提交状态'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
