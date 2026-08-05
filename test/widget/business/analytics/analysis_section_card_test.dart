import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/analytics/analysis_section_card.dart';

void main() {
  testWidgets('renders analysis heading, action, and content', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AnalysisSectionCard(
            title: '预算趋势',
            subtitle: '本月',
            onTitleTap: () => tapped = true,
            titleActionIcon: Icons.chevron_right,
            trailing: const Text('设置'),
            child: const Text('图表'),
          ),
        ),
      ),
    );

    expect(find.text('预算趋势'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('图表'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('analysis-section-title-action')),
    );
    expect(tapped, isTrue);
  });
}
