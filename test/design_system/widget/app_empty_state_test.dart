import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_empty_state.dart';

void main() {
  testWidgets('renders stacked content and forwards the action', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppEmptyState(
              icon: const Icon(RemixIcons.search_eye_line),
              title: '没有找到相关内容',
              message: '可以换一个关键词试试。',
              action: FilledButton(
                onPressed: () => tapped = true,
                child: const Text('重新搜索'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('没有找到相关内容'), findsOneWidget);
    expect(find.text('可以换一个关键词试试。'), findsOneWidget);
    expect(find.byIcon(RemixIcons.search_eye_line), findsOneWidget);

    await tester.tap(find.text('重新搜索'));
    expect(tapped, isTrue);
  });

  testWidgets('renders an inline title-only empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppEmptyState(
            layout: AppEmptyStateLayout.inline,
            title: '暂无账单',
          ),
        ),
      ),
    );

    expect(find.text('暂无账单'), findsOneWidget);
    expect(find.byType(Row), findsOneWidget);
  });

  testWidgets('fits narrow screens with large text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: SizedBox(
              width: 280,
              child: AppEmptyState(
                layout: AppEmptyStateLayout.inline,
                icon: Icon(RemixIcons.file_list_3_line),
                title: '没有符合当前筛选条件的交易记录',
                message: '可以调整筛选条件后重试。',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
