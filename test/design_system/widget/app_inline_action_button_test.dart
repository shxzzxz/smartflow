import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_inline_action_button.dart';

void main() {
  testWidgets(
    'renders a compact icon and label action with shared typography',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                child: AppInlineActionButton(
                  icon: RemixIcons.refresh_line,
                  label: '较长的操作文案',
                  onPressed: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.text('较长的操作文案'));
      final text = tester.widget<Text>(find.text('较长的操作文案'));
      final icon = tester.widget<Icon>(find.byIcon(RemixIcons.refresh_line));
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(AppInlineActionButton),
          matching: find.byType(Padding),
        ),
      );

      expect(text.style, context.appTextStyles.actionLabel);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(icon.size, 20);
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      );

      await tester.tap(find.byType(AppInlineActionButton));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
