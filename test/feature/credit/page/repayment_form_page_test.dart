// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/page/repayment_form_page.dart';
import 'package:smartflow/feature/credit/view_model/repayment_form_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  testWidgets('repayment requires confirmation before crossing zero', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = RepaymentFormState.loaded(
      liabilityAccounts: [
        Account(
          id: 'payable',
          name: '应付账户',
          type: AccountType.liability,
          subtype: AccountSubtype.payable,
          balance: Money.parse('100'),
        ),
      ],
      repaymentSourceAccounts: [
        Account(
          id: 'fund',
          name: '现金',
          type: AccountType.asset,
          subtype: AccountSubtype.fund,
          balance: Money.parse('1000'),
        ),
      ],
      principalText: '150.00',
      liabilityAccountId: 'payable',
      paidFromAccountId: 'fund',
      occurredAt: DateTime(2026, 8, 20),
    );
    final viewModel = _FixedRepaymentFormViewModel(state);
    const args = RepaymentFormArgs(liabilityAccountId: 'payable');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('账户详情')),
        ),
        GoRoute(
          path: '/repayment',
          builder:
              (context, state) =>
                  const RepaymentFormPage(liabilityAccountId: 'payable'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repaymentFormViewModelProvider(args).overrideWith(() => viewModel),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/repayment');
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('还款将超过当前欠款'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(viewModel.submitCount, 0);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '继续提交'));
    await tester.pumpAndSettle();

    expect(viewModel.submitCount, 1);
    expect(find.text('账户详情'), findsOneWidget);
  });
}

class _FixedRepaymentFormViewModel extends RepaymentFormViewModel {
  _FixedRepaymentFormViewModel(this.fixedState);

  final RepaymentFormState fixedState;
  int submitCount = 0;

  @override
  Future<RepaymentFormState> build(RepaymentFormArgs args) async => fixedState;

  @override
  Future<SubmitOutcome> submit({
    required String principalText,
    required String interestText,
    required String feeText,
    required String discountText,
    required String noteText,
  }) async {
    submitCount += 1;
    return const SubmitOutcome.success();
  }
}
