import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/showcase/installment_component_previews.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';

void main() {
  final examples = <String, Widget>{
    'basic information': const LoanBasicInfoPreview(),
    'terms': const InstallmentTermsPreview(),
    'schedule': const InstallmentSchedulePreview(),
    'schedule editor': const InstallmentScheduleEditorPreview(),
    'summary': const InstallmentSummaryPreview(),
  };
  for (final entry in examples.entries) {
    testWidgets('${entry.key} fits a narrow dark screen with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: entry.value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
