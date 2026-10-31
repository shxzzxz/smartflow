import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/amortization/view_model/amortization_form_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  test('defaults to the first matching deferral account', () async {
    final container = ProviderContainer(
      overrides: [
        accountListProvider.overrideWith(
          (ref) => Stream.value([
            _account(
              'fund',
              AccountType.asset,
              AccountSubtype.fund,
              'ledger.fund',
            ),
            _account(
              'prepaid',
              AccountType.asset,
              AccountSubtype.prepaidExpense,
              'ledger.prepaidExpense',
            ),
            _account(
              'deferred',
              AccountType.liability,
              AccountSubtype.deferredIncome,
              'ledger.deferredIncome',
            ),
          ]),
        ),
        categoryTreeProvider(AccountType.expense).overrideWith(
          (ref) => Stream.value([
            CategoryNode(
              account: _account('rent', AccountType.expense, null, null),
              children: const [],
            ),
          ]),
        ),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
      ],
    );
    addTearDown(container.dispose);
    final provider = amortizationFormViewModelProvider(
      AmortizationKind.prepaidExpense.name,
      null,
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await pumpEventQueue();

    expect(container.read(provider).requireValue.deferralAccountId, 'prepaid');

    container.read(provider.notifier).setKind(AmortizationKind.deferredIncome);

    expect(container.read(provider).requireValue.deferralAccountId, 'deferred');
  });

  test('assembles a prepaid plan command from the form state', () async {
    final service = _FakeAmortizationService();
    final container = ProviderContainer(
      overrides: [
        accountListProvider.overrideWith(
          (ref) => Stream.value([
            _account(
              'fund',
              AccountType.asset,
              AccountSubtype.fund,
              'ledger.fund',
            ),
            _account(
              'prepaid',
              AccountType.asset,
              AccountSubtype.prepaidExpense,
              'ledger.prepaidExpense',
            ),
          ]),
        ),
        categoryTreeProvider(AccountType.expense).overrideWith(
          (ref) => Stream.value([
            CategoryNode(
              account: _account('rent', AccountType.expense, null, null),
              children: const [],
            ),
          ]),
        ),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        amortizationPlanAppServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final provider = amortizationFormViewModelProvider(
      AmortizationKind.prepaidExpense.name,
      'prepaid',
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await pumpEventQueue();
    final state = container.read(provider).requireValue;
    expect(state.fundingAccountId, 'fund');
    expect(state.deferralAccountId, 'prepaid');
    expect(state.categoryAccountId, 'rent');

    final outcome = await container
        .read(provider.notifier)
        .submit(
          amountText: '3000',
          intervalText: '1',
          countText: '3',
          feeText: '',
          noteText: '季度房租',
        );

    expect(outcome, isA<UiActionSuccess<String>>());
    final command = service.created.single;
    expect(command.total, const Money(minorUnits: 300000));
    expect(command.kind, AmortizationKind.prepaidExpense);
    expect(command.cadenceUnit, AmortizationCadenceUnit.monthly);
    expect(command.recognitionCount, 3);
    expect(command.note, '季度房租');
  });
}

class _FakeAmortizationService implements AmortizationPlanAppService {
  final created = <CreateAmortizationPlanCommand>[];

  @override
  Future<String> createPlan(CreateAmortizationPlanCommand command) async {
    created.add(command);
    return 'plan';
  }

  @override
  Future<AmortizationGenerationResult> generateDue(DateTime now) async {
    return const AmortizationGenerationResult(generatedCount: 0);
  }

  @override
  Future<AmortizationTerminationResult> terminate(
    TerminateAmortizationPlanCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateReportingDefaults(
    UpdateAmortizationReportingDefaultsCommand command,
  ) async {}

  @override
  Future<void> updateTransactionReporting(
    UpdateAmortizationTransactionReportingCommand command,
  ) async {}
}

Account _account(
  String id,
  AccountType type,
  AccountSubtype? subtype,
  String? profileKey,
) {
  return Account(
    id: id,
    name: id,
    type: type,
    subtype: subtype,
    profileKey: profileKey,
    balance: Money.zero(),
  );
}
