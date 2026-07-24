import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_segmented_control.dart';

void main() {
  testWidgets('keeps segmented controls at least 48dp tall', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppSegmentedControl<int>(
            size: AppSegmentedControlSize.small,
            segments: const [
              AppSegment(value: 0, label: '本月'),
              AppSegment(value: 1, label: '年度'),
            ],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SegmentedButton<int>)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
