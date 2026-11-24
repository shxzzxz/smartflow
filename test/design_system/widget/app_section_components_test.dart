import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/design_system/widget/app_list_divider.dart';
import 'package:smartflow/design_system/widget/app_list_section.dart';
import 'package:smartflow/design_system/widget/app_section_header.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';

void main() {
  group('AppFormSection', () {
    testWidgets('keeps a section action beside a wrapping title', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SizedBox(
                width: 320,
                child: AppFormSection(
                  title: '较长的分组标题与操作',
                  trailing: TextButton(
                    onPressed: () => tapped = true,
                    child: const Text('删除'),
                  ),
                  children: const [Text('字段')],
                ),
              ),
            ),
          ),
        ),
      );
      final title = tester.getCenter(find.text('较长的分组标题与操作'));
      final button = tester.getCenter(find.byType(TextButton));
      expect(button.dy, closeTo(title.dy, 1));
      expect(button.dx, greaterThan(title.dx));
      await tester.tap(find.byType(TextButton));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses compact spacing between form rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFormSection(
              children: [
                SizedBox(key: Key('first-row'), height: 10),
                SizedBox(key: Key('second-row'), height: 10),
              ],
            ),
          ),
        ),
      );

      final firstBottom = tester.getBottomLeft(
        find.byKey(const Key('first-row')),
      );
      final secondTop = tester.getTopLeft(find.byKey(const Key('second-row')));

      expect(secondTop.dy - firstBottom.dy, 4);
    });

    testWidgets('renders section hierarchy without row dividers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppFormSection(
              title: '基本信息',
              description: '用于日常展示和记账',
              children: [Text('账户名称'), Text('备注')],
            ),
          ),
        ),
      );

      expect(find.text('基本信息'), findsOneWidget);
      expect(find.text('用于日常展示和记账'), findsOneWidget);
      expect(find.text('账户名称'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('AppSectionHeader', () {
    testWidgets('renders title, subtitle, and trailing action', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppSectionHeader(
              title: '界面设置',
              subtitle: '控制应用的基础显示行为',
              trailing: TextButton(
                onPressed: () => tapped = true,
                child: const Text('重置'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('界面设置'), findsOneWidget);
      expect(find.text('控制应用的基础显示行为'), findsOneWidget);

      await tester.tap(find.text('重置'));
      expect(tapped, isTrue);
    });

    testWidgets('keeps an action beside a wrapping title at large text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: const SizedBox(
                width: 320,
                child: AppSectionHeader(
                  title: '较长的分组标题与操作',
                  trailing: Text('2 项'),
                ),
              ),
            ),
          ),
        ),
      );

      final title = tester.getCenter(find.text('较长的分组标题与操作'));
      final trailing = tester.getCenter(find.text('2 项'));
      expect(trailing.dy, closeTo(title.dy, 1));
      expect(trailing.dx, greaterThan(title.dx));
      expect(tester.takeException(), isNull);
    });
  });

  group('AppListSection', () {
    testWidgets('renders a header and dividers between rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppListSection(
              header: AppSectionHeader(title: '界面设置'),
              children: [Text('第一行'), Text('第二行'), Text('第三行')],
            ),
          ),
        ),
      );

      expect(find.text('界面设置'), findsOneWidget);
      expect(find.text('第一行'), findsOneWidget);
      expect(find.text('第二行'), findsOneWidget);
      expect(find.text('第三行'), findsOneWidget);
      expect(find.byType(AppListDivider), findsNWidgets(2));
    });

    testWidgets('does not add dividers for an empty list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppListSection(children: [])),
        ),
      );

      expect(find.byType(AppListDivider), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppListDivider', () {
    testWidgets('renders the inset list divider geometry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AppListDivider()),
        ),
      );

      final context = tester.element(find.byType(AppListDivider));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppListDivider),
          matching: find.byType(Container),
        ),
      );
      final colors = Theme.of(context).colorScheme;
      final decorationColor = container.color;

      expect(container.margin, const EdgeInsets.symmetric(horizontal: 16));
      expect(container.constraints?.maxHeight, 1);
      expect(decorationColor, colors.outlineVariant.withValues(alpha: 0.45));
      expect(tester.takeException(), isNull);
    });
  });

  group('AppSupportingItems', () {
    testWidgets('renders supporting labels with semantic tone colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppSupportingItems(
              items: [
                AppSupportingText('到期 07-25'),
                AppSupportingText('2 条逾期', tone: AppStatusTone.danger),
              ],
            ),
          ),
        ),
      );

      final context = tester.element(find.text('到期 07-25'));
      final colors = Theme.of(context).colorScheme;
      final extension = Theme.of(context).extension<AppThemeExtension>()!;
      final neutral = tester.widget<Text>(find.text('到期 07-25'));
      final danger = tester.widget<Text>(find.text('2 条逾期'));

      expect(neutral.style?.color, colors.onSurfaceVariant);
      expect(danger.style?.color, extension.danger);
      expect(danger.maxLines, 1);
      expect(danger.overflow, TextOverflow.ellipsis);
      expect(find.byType(Wrap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
