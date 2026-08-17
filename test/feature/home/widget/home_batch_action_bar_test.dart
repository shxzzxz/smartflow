import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/home/widget/home_batch_action_bar.dart';

void main() {
  testWidgets('批量操作栏支持全选和取消全选', (tester) async {
    var selectAllCalls = 0;
    var clearAllCalls = 0;
    var deleteCalls = 0;
    var tagCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: HomeBatchActionBar(
            selectedCount: 1,
            totalCount: 2,
            enabled: true,
            onSelectAll: () => selectAllCalls++,
            onClearAll: () => clearAllCalls++,
            onDelete: () => deleteCalls++,
            onManageTags: () => tagCalls++,
          ),
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
    await tester.tap(find.text('全选'));
    await tester.tap(find.text('取消全选'));
    await tester.tap(find.text('删除'));
    await tester.tap(find.text('标签管理'));

    expect(selectAllCalls, 1);
    expect(clearAllCalls, 1);
    expect(deleteCalls, 1);
    expect(tagCalls, 1);
  });

  testWidgets('批量操作栏在窄屏上保持单行布局', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SizedBox(
          width: 320,
          height: 120,
          child: Scaffold(
            bottomNavigationBar: HomeBatchActionBar(
              selectedCount: 1,
              totalCount: 12,
              enabled: true,
              onSelectAll: () {},
              onClearAll: () {},
              onDelete: () {},
              onManageTags: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Row), findsWidgets);
  });
}
