import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';

void main() {
  testWidgets('renders the detail status badge geometry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusBadge(
            presentation: AppStatusBadgePresentation(
              label: '进行中',
              tone: AppStatusTone.primary,
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.text('进行中'));
    final text = tester.widget<Text>(find.text('进行中'));
    final container = tester.widget<Container>(
      find.ancestor(of: find.text('进行中'), matching: find.byType(Container)),
    );

    final expectedStyle = context.appTextStyles.listSupporting;
    expect(text.style?.fontSize, expectedStyle.fontSize);
    expect(text.style?.fontWeight, expectedStyle.fontWeight);
    expect(
      text.style?.color,
      appStatusToneColor(context, AppStatusTone.primary),
    );
    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the compact status badge geometry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusBadge(
            presentation: AppStatusBadgePresentation(
              label: '待还',
              tone: AppStatusTone.warning,
            ),
            size: AppStatusBadgeSize.compact,
          ),
        ),
      ),
    );

    final context = tester.element(find.text('待还'));
    final text = tester.widget<Text>(find.text('待还'));
    final container = tester.widget<Container>(
      find.ancestor(of: find.text('待还'), matching: find.byType(Container)),
    );

    final expectedStyle = context.appTextStyles.badgeLabel;
    expect(text.style?.fontSize, expectedStyle.fontSize);
    expect(text.style?.fontWeight, expectedStyle.fontWeight);
    expect(
      text.style?.color,
      appStatusToneColor(context, AppStatusTone.warning),
    );
    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('maps semantic tones to theme colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final colors = Theme.of(context).colorScheme;
    final extension = Theme.of(context).extension<AppThemeExtension>()!;

    expect(
      appStatusToneColor(context, AppStatusTone.neutral),
      colors.onSurfaceVariant,
    );
    expect(appStatusToneColor(context, AppStatusTone.primary), colors.primary);
    expect(appStatusToneColor(context, AppStatusTone.info), extension.info);
    expect(
      appStatusToneColor(context, AppStatusTone.success),
      extension.success,
    );
    expect(
      appStatusToneColor(context, AppStatusTone.warning),
      extension.warning,
    );
    expect(appStatusToneColor(context, AppStatusTone.danger), extension.danger);
  });
}
