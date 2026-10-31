import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/amortization/page/amortization_plans_page.dart';
import 'package:smartflow/feature/amortization/provider/amortization_providers.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';

void main() {
  testWidgets('renders plans with balances and opens plan detail', (
    tester,
  ) async {
    final plan = AmortizationPlan.create(
      id: 'plan',
      kind: AmortizationKind.prepaidExpense,
      deferralAccountId: 'prepaid',
      categoryAccountId: 'rent',
      total: const Money(minorUnits: 300000),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      firstRecognitionAt: DateTime(2026, 1, 31),
      recognitionCount: 3,
      defaultIsExcludedFromStats: false,
      defaultIsExcludedFromBudget: false,
      initialTransactionId: 'initial',
    );
    final router = GoRouter(
      initialLocation: '/amortizations',
      routes: [
        GoRoute(
          path: '/amortizations',
          builder: (context, state) => const AmortizationPlansPage(),
        ),
        GoRoute(
          path: '/amortizations/:id',
          builder: (context, state) =>
              Scaffold(body: Text('计划详情 ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/amortizations/new',
          builder: (context, state) => const Scaffold(body: Text('新建')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          amortizationPlansProvider(
            deferralAccountId: null,
          ).overrideWith((ref) => Stream.value([plan])),
          accountsByIdProvider.overrideWith(
            (ref) => Stream.value({
              'prepaid': _account(
                'prepaid',
                '预付房租',
                AccountSubtype.prepaidExpense,
                AccountType.asset,
              ),
              'rent': _account('rent', '房租支出', null, AccountType.expense),
            }),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('房租支出'), findsOneWidget);
    expect(find.textContaining('预付房租'), findsOneWidget);
    expect(find.byType(MoneyText), findsNWidgets(2));

    await tester.tap(find.text('房租支出'));
    await tester.pumpAndSettle();
    expect(find.text('计划详情 plan'), findsOneWidget);
  });
}

Account _account(
  String id,
  String name,
  AccountSubtype? subtype,
  AccountType type,
) {
  return Account(
    id: id,
    name: name,
    type: type,
    subtype: subtype,
    balance: Money.zero(),
  );
}
