import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/insurance/widget/insurance/insurance_coverage_overview_card.dart';

void main() {
  for (final mode in ThemeMode.values.where(
    (mode) => mode != ThemeMode.system,
  )) {
    testWidgets(
      'coverage card lists highlights and displays exclusions as text ($mode)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InsuranceCoverageOverviewCard(
                    title: '保障责任',
                    summary: '记录住院和门诊的保障范围以及具体赔付条件',
                    highlights: '  覆盖住院医疗  \r\n\r\n包含门诊医疗\n',
                    waitingPeriodDescription: '疾病30天；意外无等待期',
                    exclusionsDescription: '  既往症相关责任除外  \n\n特定疾病除外\r\n',
                    showResponsibilitiesLink: true,
                    onTap: () => opened = true,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('保障概要'), findsOneWidget);
        expect(find.text('保障总结'), findsNothing);
        expect(find.text('覆盖住院医疗'), findsOneWidget);
        expect(find.text('包含门诊医疗'), findsOneWidget);
        expect(find.text('既往症相关责任除外  \n\n特定疾病除外'), findsOneWidget);
        expect(find.text('既往症约定'), findsNothing);
        await tester.ensureVisible(find.text('查看全部'));
        await tester.tap(find.text('查看全部'));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
