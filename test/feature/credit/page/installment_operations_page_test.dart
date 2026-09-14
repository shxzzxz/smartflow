import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';
import 'package:smartflow/feature/credit/page/installment_operations_page.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import '../fixture/installment_operations_fixture.dart';

void main() {
  late RecordingRepricingService repricing;
  late RecordingInterestAdjustments adjustments;
  setUp(() {
    repricing = RecordingRepricingService();
    adjustments = RecordingInterestAdjustments();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool records = false,
    bool multipleStages = false,
    bool interestAdjustments = false,
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installmentContractProvider('loan').overrideWith(
            (ref) async => operationsContract(
              withRecords: records,
              multipleStages: multipleStages,
            ),
          ),
          installmentRepricingServiceProvider.overrideWithValue(repricing),
          installmentInterestAdjustmentServiceProvider.overrideWithValue(
            adjustments,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: interestAdjustments
              ? const InstallmentInterestAdjustmentsPage(contractId: 'loan')
              : const InstallmentRepricingPage(contractId: 'loan'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'manual repricing has independent inputs and works on a narrow screen',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('新增重定价'));
      await tester.pumpAndSettle();
      expect(find.text('利率类型'), findsOneWidget);
      expect(find.text('加减基点（BP）'), findsOneWidget);
      expect(find.text('重定价周期'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '-30');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repricing.created.single.bp, -30);
      expect(repricing.created.single.stageId, 'stage');
      expect(repricing.created.single.type, InterestRateType.lprFiveYearPlus);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configuration dialog remains usable with large text on a phone',
    (tester) async {
      await pump(tester, textScale: 1.4);
      await tester.tap(find.text('新增配置'));
      await tester.pumpAndSettle();
      expect(find.text('配置生效日'), findsOneWidget);
      expect(find.text('首次重定价日'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), '-15');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repricing.configurations.single.rule.spreadBp, -15);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed adjustment saves preserve edited input and block duplicate submissions',
    (tester) async {
      await pump(tester, records: true, interestAdjustments: true);
      await tester.ensureVisible(find.text('利息比例 50% · 点击修改'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('利息比例 50% · 点击修改'));
      await tester.pumpAndSettle();
      expect(find.text('50'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '75.25');
      final pending = Completer<void>();
      adjustments.onWrite = () => pending.future;
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(adjustments.saved, hasLength(1));
      pending.completeError(
        BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '区间不能重叠',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('区间不能重叠'), findsOneWidget);
      expect(find.text('75.25'), findsOneWidget);
      expect(adjustments.saved.single.id, 'adjustment');
      expect(adjustments.saved.single.adjustment.ratioPpm, 752500);
      adjustments.onWrite = null;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(adjustments.saved, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final sample in [
    (action: '新增重定价', value: '1.5', error: '请输入整数基点，可为负数'),
    (action: '新增利息调整', value: '-1', error: '请输入非负利息比例'),
    (action: '新增利息调整', value: '50.00001', error: '利息比例最多保留四位小数'),
  ]) {
    testWidgets(
      '${sample.action} validates ${sample.value} inline without failure logs',
      (tester) async {
        await pump(tester, interestAdjustments: sample.action == '新增利息调整');
        await tester.ensureVisible(find.text(sample.action));
        await tester.tap(find.text(sample.action));
        await tester.pumpAndSettle();
        final records = <LogRecord>[];
        final subscription = Logger.root.onRecord.listen(records.add);
        addTearDown(subscription.cancel);
        await tester.enterText(find.byType(TextFormField), sample.value);
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(
          tester
              .state<FormFieldState<String>>(find.byType(TextFormField))
              .errorText,
          sample.error,
        );
        expect(
          records.where((record) => record.level >= Level.WARNING),
          isEmpty,
        );
        expect(repricing.created, isEmpty);
        expect(adjustments.saved, isEmpty);
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );
  }

  testWidgets('deletion needs confirmation and forwards the selected record', (
    tester,
  ) async {
    await pump(tester, records: true);
    final remove = find.byTooltip('删除重定价');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repricing.deleted, isEmpty);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(repricing.deleted, [('loan', 'rate')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'configuration deletion keeps records and each page exposes its own operations',
    (tester) async {
      await pump(tester, records: true);
      expect(find.text('新增利息调整'), findsNothing);
      final remove = find.byTooltip('删除重定价配置');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.textContaining('已生成的重定价记录和还款计划会保留'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(repricing.deletedConfigurations, [('loan', 'configuration')]);
      expect(repricing.deleted, isEmpty);
      await pump(tester, interestAdjustments: true);
      expect(find.text('新增重定价'), findsNothing);
      expect(find.text('新增配置'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '新增利息调整'), findsOneWidget);
    },
  );

  for (final action in ['新增配置', '新增重定价']) {
    testWidgets('$action submits the stage selected by the user', (
      tester,
    ) async {
      await pump(tester, multipleStages: true);
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.tap(find.text('阶段 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('阶段 2').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '-20');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        action == '新增配置'
            ? repricing.configurations.single.stageId
            : repricing.created.single.stageId,
        'second',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
