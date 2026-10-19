import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/feature/profile/widget/log_level_badge.dart';

void main() {
  testWidgets('keeps the log badge geometry and danger tone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: LogLevelBadge(level: Level.SEVERE)),
      ),
    );

    final context = tester.element(find.byType(LogLevelBadge));
    final danger = Theme.of(context).extension<AppThemeExtension>()!.danger;
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(LogLevelBadge),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    final text = tester.widget<Text>(find.text('错误'));

    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
    expect(
      decoration.color,
      danger.withValues(alpha: AppComponentTokens.statusBackgroundOpacity),
    );
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.radiusSm));
    expect(text.style?.color, danger);
  });
}
