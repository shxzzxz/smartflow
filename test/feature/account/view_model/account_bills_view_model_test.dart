// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/view_model/account_bills_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('allows historical generation for an active credit account', () async {
    final container = _container(_account(isArchived: false));
    final sub = container.listen(
      accountBillsViewModelProvider('card'),
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(billSummariesByAccountProvider('card').future);
    await container.pump();
    await _flush();

    final state = container.read(accountBillsViewModelProvider('card'));
    expect(state, isA<AccountBillsPageLoaded>());
    expect((state as AccountBillsPageLoaded).canGenerateHistoricalBill, isTrue);
  });

  test(
    'disallows historical generation for an archived credit account',
    () async {
      final container = _container(_account(isArchived: true));
      final sub = container.listen(
        accountBillsViewModelProvider('card'),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(billSummariesByAccountProvider('card').future);
      await container.pump();
      await _flush();

      final state = container.read(accountBillsViewModelProvider('card'));
      expect(state, isA<AccountBillsPageLoaded>());
      expect(
        (state as AccountBillsPageLoaded).canGenerateHistoricalBill,
        isFalse,
      );
    },
  );

  test(
    'completes historical generation after the page stops listening',
    () async {
      final generation = _DelayedBillGenerationService();
      final container = _container(
        _account(isArchived: false),
        generation: generation,
      );
      final sub = container.listen(
        accountBillsViewModelProvider('card'),
        (_, _) {},
      );
      await container.read(billSummariesByAccountProvider('card').future);
      await container.pump();
      await _flush();

      final outcomeFuture = container
          .read(accountBillsViewModelProvider('card').notifier)
          .generateHistoricalBill(DateTime(2025, 11, 20));
      await generation.started.future;
      sub.close();
      await container.pump();
      generation.complete();

      final outcome = await outcomeFuture;
      expect(outcome, isA<UiActionSuccess<void>>());
      expect(generation.accountId, 'card');
      expect(generation.period, BillPeriod(year: 2025, month: 11));
    },
  );

  test('refreshes bill state after historical generation succeeds', () async {
    final summaries = _RefreshingBillSummaries();
    final container = _container(
      _account(isArchived: false),
      generation: _SuccessfulBillGenerationService(),
      loadBills: summaries.load,
    );
    final sub = container.listen(
      accountBillsViewModelProvider('card'),
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(billSummariesByAccountProvider('card').future);
    await container.pump();
    await _flush();

    final outcome = await container
        .read(accountBillsViewModelProvider('card').notifier)
        .generateHistoricalBill(DateTime(2025, 11));
    await container.read(billSummariesByAccountProvider('card').future);
    await container.pump();
    await _flush();

    final state = container.read(accountBillsViewModelProvider('card'));
    expect(outcome, isA<UiActionSuccess<void>>());
    expect(state, isA<AccountBillsPageLoaded>());
    expect((state as AccountBillsPageLoaded).bills, hasLength(1));
    expect(state.bills.single.period, BillPeriod(year: 2025, month: 11));
  });

  test('maps bill generation business failure to UI error', () async {
    final container = _container(
      _account(isArchived: false),
      generation: _FailingBillGenerationService(
        BusinessException(
          CreditErrorCode.billInvalidCommand,
          message: '无法生成该账期。',
        ),
      ),
    );

    final outcome = await container
        .read(accountBillsViewModelProvider('card').notifier)
        .generateHistoricalBill(DateTime(2025, 11));

    expect(outcome, isA<UiActionFailure<void>>());
    final error = (outcome as UiActionFailure<void>).error;
    expect(error.code, CreditErrorCode.billInvalidCommand.code);
    expect(error.message, '无法生成该账期。');
  });

  test('maps unexpected bill generation failure to unknown UI error', () async {
    final container = _container(
      _account(isArchived: false),
      generation: _FailingBillGenerationService(Exception('database error')),
    );

    final outcome = await container
        .read(accountBillsViewModelProvider('card').notifier)
        .generateHistoricalBill(DateTime(2025, 11));

    expect(outcome, isA<UiActionFailure<void>>());
    final error = (outcome as UiActionFailure<void>).error;
    expect(error.code, 'unknown');
    expect(error.message, '未知错误，请稍后重试。');
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ProviderContainer _container(
  AccountView account, {
  CreditBillGenerationAppService? generation,
  Future<List<BillSummaryReadModel>> Function()? loadBills,
}) {
  final container = ProviderContainer(
    overrides: [
      accountViewProvider(
        'card',
      ).overrideWith((ref) => AsyncValue.data(account)),
      billSummariesByAccountProvider(
        'card',
      ).overrideWith((ref) => loadBills?.call() ?? Future.value(const [])),
      if (generation != null)
        creditBillGenerationAppServiceProvider.overrideWithValue(generation),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AccountView _account({required bool isArchived}) {
  return AccountView(
    id: 'card',
    name: '信用卡',
    kind: AccountProfileKind.credit,
    balance: Money.zero(),
    iconKey: 'card',
    isArchived: isArchived,
  );
}

class _DelayedBillGenerationService implements CreditBillGenerationAppService {
  final started = Completer<void>();
  final _completion = Completer<void>();
  String? accountId;
  BillPeriod? period;

  void complete() => _completion.complete();

  @override
  Future<void> generateBillForPeriod({
    required String accountId,
    required BillPeriod period,
    required DateTime now,
  }) async {
    this.accountId = accountId;
    this.period = period;
    started.complete();
    await _completion.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SuccessfulBillGenerationService
    implements CreditBillGenerationAppService {
  @override
  Future<void> generateBillForPeriod({
    required String accountId,
    required BillPeriod period,
    required DateTime now,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingBillGenerationService implements CreditBillGenerationAppService {
  _FailingBillGenerationService(this.error);

  final Object error;

  @override
  Future<void> generateBillForPeriod({
    required String accountId,
    required BillPeriod period,
    required DateTime now,
  }) async {
    throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RefreshingBillSummaries {
  var _loadCount = 0;

  Future<List<BillSummaryReadModel>> load() async {
    _loadCount++;
    if (_loadCount == 1) return const [];
    return [_billSummary(year: 2025, month: 11)];
  }
}

BillSummaryReadModel _billSummary({required int year, required int month}) {
  return BillSummaryReadModel(
    id: 'bill-$year-$month',
    accountId: 'card',
    period: BillPeriod(year: year, month: month),
    status: BillStatus.billed,
    expectedPrincipal: Money.zero(),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: Money.zero(),
    itemCount: 0,
    overdueItemCount: 0,
  );
}
