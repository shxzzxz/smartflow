import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/component.dart';
import 'package:smartflow/design_system/token/motion.dart';
import 'package:smartflow/feature/home/widget/home_batch_action_bar.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required int selectedCount,
    bool enabled = true,
    bool processing = false,
    VoidCallback? onDelete,
    VoidCallback? onManageTags,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: HomeBatchActionBar(
            selectedCount: selectedCount,
            enabled: enabled,
            processing: processing,
            onDelete: onDelete ?? () {},
            onManageTags: onManageTags ?? () {},
          ),
        ),
      ),
    );
    // 处理中的进度条一直动画，只推进入场动效。
    await tester.pump(AppMotion.durationFast);
    await tester.pump(AppMotion.durationFast);
  }

  InkWell actionOf(WidgetTester tester, String label) {
    return tester.widget<InkWell>(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
    );
  }

  testWidgets('批量操作栏支持标签和删除操作', (tester) async {
    var deleteCalls = 0;
    var tagCalls = 0;

    await pumpBar(
      tester,
      selectedCount: 1,
      onDelete: () => deleteCalls++,
      onManageTags: () => tagCalls++,
    );

    await tester.tap(find.text('标签'));
    await tester.tap(find.text('删除'));

    expect(deleteCalls, 1);
    expect(tagCalls, 1);
  });

  testWidgets('批量操作栏动作等分铺满并与导航栏同高', (tester) async {
    await pumpBar(tester, selectedCount: 1);

    final barWidth = tester.getSize(find.byType(HomeBatchActionBar)).width;
    final tagWidth = tester.getSize(find.byWidget(actionOf(tester, '标签'))).width;
    final deleteWidth =
        tester.getSize(find.byWidget(actionOf(tester, '删除'))).width;

    expect(tagWidth, deleteWidth);
    expect(tagWidth + deleteWidth, barWidth);
    expect(
      tester.getSize(find.byType(HomeBatchActionBar)).height,
      greaterThanOrEqualTo(AppComponentTokens.navigationBarHeight),
    );
  });

  testWidgets('未选中交易时动作不可用', (tester) async {
    await pumpBar(tester, selectedCount: 0);

    expect(actionOf(tester, '标签').onTap, isNull);
    expect(actionOf(tester, '删除').onTap, isNull);
  });

  testWidgets('批量操作进行中显示进度并禁用动作', (tester) async {
    await pumpBar(tester, selectedCount: 2, enabled: false, processing: true);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(actionOf(tester, '标签').onTap, isNull);
    expect(actionOf(tester, '删除').onTap, isNull);
  });

  testWidgets('批量操作栏在窄屏上保持单行布局', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpBar(tester, selectedCount: 1);

    expect(tester.takeException(), isNull);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });
}
