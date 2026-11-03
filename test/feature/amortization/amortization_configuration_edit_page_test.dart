// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/amortization/page/amortization_configuration_edit_page.dart';
import 'package:smartflow/feature/amortization/provider/amortization_providers.dart';

void main() {
  testWidgets('configuration editor only submits schedule configuration', (
    tester,
  ) async {
    final plan = _plan();
    final service = _FakeAmortizationPlanAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          amortizationPlanProvider(
            plan.id,
          ).overrideWith((ref) => Stream.value(plan)),
          amortizationPlanAppServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AmortizationConfigurationEditPage(planId: plan.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('配置编辑'), findsOneWidget);
    expect(find.text('摊销类型'), findsNothing);
    expect(find.text('摊销期数'), findsOneWidget);
    expect(find.text('首期日期'), findsOneWidget);
    expect(find.text('间隔方式'), findsOneWidget);
    expect(find.text('间隔数'), findsOneWidget);
    expect(find.text('原摊销额'), findsNothing);
    expect(find.text('退款分类'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '2');
    await tester.enterText(find.byType(TextField).at(1), '4');
    await tester.tap(find.text('保存并重算'));
    await tester.pumpAndSettle();

    final command = service.commands.single;
    expect(command.planId, 'plan');
    expect(command.recognitionCount, 4);
    expect(command.cadenceUnit, AmortizationCadenceUnit.monthly);
    expect(command.cadenceInterval, 2);
  });
}

AmortizationPlan _plan() {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    fundingAllocations: singleAllocation(
      accountId: 'cash',
      amount: const Money(minorUnits: 30000),
    ),
    categoryAllocations: singleAllocation(
      accountId: 'rent',
      amount: const Money(minorUnits: 30000),
    ),
    originalAmount: const Money(minorUnits: 30000),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: 3,
    initialTransactionId: 'initial',
  );
}

class _FakeAmortizationPlanAppService implements AmortizationPlanAppService {
  final commands = <UpdateAmortizationConfigurationCommand>[];

  @override
  Future<void> updateConfiguration(
    UpdateAmortizationConfigurationCommand command,
  ) async {
    commands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
