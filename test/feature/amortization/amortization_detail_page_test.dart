// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_termination.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/amortization/page/amortization_detail_page.dart';
import 'package:smartflow/feature/amortization/provider/amortization_providers.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  testWidgets('terminated plan offers undo and immediately refreshes', (
    tester,
  ) async {
    final created = _plan();
    final posted = created.withPeriods([
      created.periods.single.posted('entry'),
    ]);
    final terminated = posted.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: posted.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: const [],
        settlementAllocations: const [],
        recognitionTransactionId: 'termination-entry',
      ),
      periods: posted.periods,
    );
    final service = _FakeAmortizationPlanAppService();

    await tester.pumpWidget(_app(plan: terminated, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('撤销终止'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认撤销'));
    await tester.pumpAndSettle();

    expect(service.undoCommands, hasLength(1));
    expect(find.text('终止已撤销并补齐到期期次'), findsOneWidget);
  });

  testWidgets('refund record opens a prefilled edit sheet', (tester) async {
    final created = _plan(totalMinor: 30000, recognitionCount: 3);
    final plan = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: singleAllocation(
          accountId: 'rent',
          amount: const Money(minorUnits: 5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: const Money(minorUnits: 5000),
        ),
        transferTransactionId: 'refund-transfer',
      ),
    );

    await tester.pumpWidget(
      _app(plan: plan, service: _FakeAmortizationPlanAppService()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('修改退款'));
    await tester.pumpAndSettle();

    expect(find.text('修改摊销退款'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
    final amountField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('allocation-amount-rent')),
        matching: find.byType(TextField),
      ),
    );
    expect(amountField.controller?.text, '50');
  });

  testWidgets('plan detail confirms destructive deletion', (tester) async {
    final plan = _plan();
    final service = _FakeAmortizationPlanAppService();

    await tester.pumpWidget(_app(plan: plan, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除摊销计划'));
    await tester.pumpAndSettle();
    expect(find.text('将删除该计划及全部关联账务交易，且无法恢复。'), findsOneWidget);
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(service.deleteCommands, hasLength(1));
  });
}

Widget _app({
  required AmortizationPlan plan,
  required AmortizationPlanAppService service,
}) {
  final accounts = [
    _account(
      id: 'prepaid',
      name: '预付房租',
      type: AccountType.asset,
      subtype: AccountSubtype.prepaidExpense,
    ),
    _account(
      id: 'cash',
      name: '现金',
      type: AccountType.asset,
      subtype: AccountSubtype.fund,
    ),
    _account(id: 'rent', name: '房租支出', type: AccountType.expense),
  ];
  return ProviderScope(
    overrides: [
      amortizationPlanProvider(
        plan.id,
      ).overrideWith((ref) => Stream.value(plan)),
      accountListProvider.overrideWith((ref) => Stream.value(accounts)),
      accountsByIdProvider.overrideWith(
        (ref) =>
            Stream.value({for (final account in accounts) account.id: account}),
      ),
      categoryTreeProvider(AccountType.expense).overrideWith(
        (ref) => Stream.value([
          CategoryNode(account: accounts.last, children: const []),
        ]),
      ),
      amortizationPlanAppServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: AmortizationDetailPage(planId: plan.id),
    ),
  );
}

AmortizationPlan _plan({int totalMinor = 10000, int recognitionCount = 1}) {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    fundingAllocations: singleAllocation(
      accountId: 'cash',
      amount: Money(minorUnits: totalMinor),
    ),
    categoryAllocations: singleAllocation(
      accountId: 'rent',
      amount: Money(minorUnits: totalMinor),
    ),
    originalAmount: Money(minorUnits: totalMinor),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: recognitionCount,
    initialTransactionId: 'initial',
  );
}

Account _account({
  required String id,
  required String name,
  required AccountType type,
  AccountSubtype? subtype,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    subtype: subtype,
    balance: Money.zero(),
  );
}

class _FakeAmortizationPlanAppService implements AmortizationPlanAppService {
  final undoCommands = <UndoAmortizationTerminationCommand>[];
  final deleteCommands = <DeleteAmortizationPlanCommand>[];

  @override
  Future<AmortizationGenerationResult> undoTermination(
    UndoAmortizationTerminationCommand command,
  ) async {
    undoCommands.add(command);
    return const AmortizationGenerationResult(generatedCount: 1);
  }

  @override
  Future<void> deletePlan(DeleteAmortizationPlanCommand command) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
