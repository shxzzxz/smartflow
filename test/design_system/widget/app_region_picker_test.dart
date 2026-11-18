import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_region_picker.dart';
import 'package:smartflow/feature/shared/presentation/china_region_data.dart';

const _regions = [
  AppRegionNode(
    code: 'p1',
    name: '省甲',
    children: [
      AppRegionNode(
        code: 'c1',
        name: '市甲',
        children: [AppRegionNode(code: 'd1', name: '区甲')],
      ),
    ],
  ),
  AppRegionNode(
    code: 'p2',
    name: '省乙',
    children: [
      AppRegionNode(
        code: 'c2',
        name: '市乙',
        children: [AppRegionNode(code: 'd2', name: '区乙')],
      ),
    ],
  ),
];

void main() {
  testWidgets('municipality city selection returns the province and city', (
    tester,
  ) async {
    final regions = (await tester.runAsync(() => loadChinaRegions()))!;
    AppRegionSelection? result;
    await _pump(
      tester,
      regions: regions,
      level: AppRegionLevel.city,
      onSelected: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('region-option-110000')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region-option-110100')), findsOneWidget);
    expect(find.text('东城区'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('region-option-110100')));
    await tester.pumpAndSettle();

    expect(result!.codes, ['110000', '110100']);
    expect(result!.label, '北京市 / 北京市');
  });

  testWidgets('municipality district selection keeps the city in its path', (
    tester,
  ) async {
    final regions = (await tester.runAsync(() => loadChinaRegions()))!;
    AppRegionSelection? result;
    await _pump(
      tester,
      regions: regions,
      onSelected: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('region-option-110000')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('region-option-110100')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.byKey(const ValueKey('region-option-110101')));
    await tester.pumpAndSettle();

    expect(result!.codes, ['110000', '110100', '110101']);
    expect(result!.label, '北京市 / 北京市 / 东城区');
  });

  testWidgets('city selection requires province and city and hides districts', (
    tester,
  ) async {
    AppRegionSelection? result;
    await _pump(
      tester,
      level: AppRegionLevel.city,
      onSelected: (value) => result = value,
    );
    await tester.tap(find.byKey(const ValueKey('region-option-p1')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('区甲'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('region-option-c1')));
    await tester.pumpAndSettle();
    expect(result!.codes, ['p1', 'c1']);
    expect(result!.label, '省甲 / 市甲');
  });

  testWidgets('district selection only completes at the third level', (
    tester,
  ) async {
    AppRegionSelection? result;
    await _pump(tester, onSelected: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('region-option-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('region-option-c1')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.byKey(const ValueKey('region-option-d1')));
    await tester.pumpAndSettle();
    expect(result!.codes, ['p1', 'c1', 'd1']);
  });

  testWidgets('changing a parent discards the previous lower-level selection', (
    tester,
  ) async {
    AppRegionSelection? result;
    await _pump(
      tester,
      selectedCodes: ['p1', 'c1', 'd1'],
      onSelected: (value) => result = value,
    );
    expect(find.byKey(const ValueKey('region-option-d1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('region-level-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('region-option-p2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region-option-c1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('region-option-c2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region-option-d1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('region-option-d2')));
    await tester.pumpAndSettle();
    expect(result!.codes, ['p2', 'c2', 'd2']);
  });

  testWidgets('empty data can be dismissed without selecting a parent', (
    tester,
  ) async {
    AppRegionSelection? result;
    await _pump(
      tester,
      regions: const [],
      onSelected: (value) => result = value,
    );
    expect(find.text('暂无可选地区'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭地区选择'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(AppRegionPickerSheet), findsNothing);
  });

  testWidgets('fits a narrow screen with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      selectedCodes: ['p1', 'c1', 'd1'],
      textScale: 1.8,
      onSelected: (_) {},
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('region-level-0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required ValueChanged<AppRegionSelection?> onSelected,
  AppRegionLevel level = AppRegionLevel.district,
  List<AppRegionNode> regions = _regions,
  List<String> selectedCodes = const [],
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onSelected(
              await showAppRegionPickerSheet(
                context: context,
                regions: regions,
                level: level,
                selectedCodes: selectedCodes,
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}
