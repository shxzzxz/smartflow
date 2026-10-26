import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_grouped_choice_grid.dart';
import 'package:smartflow/feature/account/presentation/account_creation_presets.dart';
import 'package:smartflow/feature/account/widget/account_creation_sheet.dart';

void main() {
  testWidgets('shows grouped account creation choices and returns a preset', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AccountCreationPreset? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showAccountCreationSheet(context: context);
              },
              child: const Text('打开新建账户'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开新建账户'));
    await tester.pumpAndSettle();

    expect(
      find.byType(AppGroupedChoiceGrid<AccountCreationPreset>),
      findsOneWidget,
    );
    expect(find.text('新建账户'), findsNothing);
    for (final id in ['fund', 'credit', 'relations']) {
      expect(find.byKey(ValueKey('app-choice-grid-$id')), findsOneWidget);
    }
    expect(find.text('微信'), findsOneWidget);
    expect(find.text('花呗'), findsOneWidget);
    expect(find.text('押金'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('app-choice-grid-item-fund-boc')),
    );
    await tester.pumpAndSettle();

    expect(selected?.id, 'boc');
    expect(find.text('新建账户'), findsNothing);
  });
}
