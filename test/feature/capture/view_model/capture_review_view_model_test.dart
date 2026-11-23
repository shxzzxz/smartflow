import 'dart:async';

import 'package:smartflow/app/recognition_rules_provider.dart';
import 'package:smartflow/application/intake/intake_rules_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/intake/rules/port/recognition_rule_repository.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_catalog.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_configuration.dart';
import 'package:smartflow/infrastructure/intake/rules/ledger_recognition_rule_target_query.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/capture_intake_provider.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/intake/recognition/recognition_error_code.dart';
import 'package:smartflow/feature/capture/view_model/capture_review_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

final _captureProvider = captureReviewViewModelProvider('test-capture');
final _captureTime = DateTime(2026, 4, 5, 14, 30);

void main() {
  for (final direction in RecognizedPaymentDirection.values) {
    test(
      'partial $direction prefill retains time and note without an amount',
      () async {
        final container = _container(
          _Recognizer(
            () async => RecognizedPayment(
              direction: direction,
              occurredAt: _captureTime,
              counterparty: '示例书店',
              product: '图书',
            ),
          ),
        );
        final outcome = await container
            .read(_captureProvider.notifier)
            .recognize('share');
        final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
        expect(result.prefill, isNotNull);
        expect(result.prefill!.amount, isNull);
        expect(result.prefill!.occurredAt, _captureTime);
        expect(result.prefill!.note, '图书 · 示例书店');
        expect(result.manualAction, isNull);
      },
    );
  }

  test(
    'unknown scenes preserve extracted values and use expense rule targets',
    () async {
      final container = _container(
        _Recognizer(
          () async => RecognizedPayment(
            scene: PaymentScreenshotScene.unknown,
            amount: Money.parse('12.35'),
            occurredAt: _captureTime,
            paymentMethod: '日常银行卡',
            product: '图书',
            counterparty: '示例书店',
            categoryMatchingText: '图书',
          ),
        ),
        accounts: [_account('card', '日常银行卡')],
        categories: [
          CategoryNode(
            account: _account('books', '书籍', type: AccountType.expense),
          ),
        ],
        rules: [
          RecognitionRule(
            id: 'books',
            kind: RecognitionRuleKind.category,
            keywords: ['图书'],
            priority: 1,
            targetAccountId: 'books',
            targetCategoryKind: ImportCategoryKind.expense,
          ),
        ],
      );
      final outcome = await container
          .read(_captureProvider.notifier)
          .recognize('share');
      final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
      expect(result.payment.scene, PaymentScreenshotScene.unknown);
      expect(result.prefill, isNotNull);
      expect(result.prefill!.amount, Money.parse('12.35'));
      expect(result.prefill!.occurredAt, _captureTime);
      expect(result.prefill!.settlementAccountId, 'card');
      expect(result.prefill!.categoryId, 'books');
      expect(result.prefill!.note, '图书 · 示例书店');
      expect(result.manualAction, isNull);
    },
  );

  test(
    'transfer details can prefill with neither amount nor account clues',
    () async {
      final container = _container(
        _Recognizer(
          () async => RecognizedPayment(
            scene: PaymentScreenshotScene.transfer,
            occurredAt: _captureTime,
            product: '内部资金调拨',
          ),
        ),
      );
      final outcome = await container
          .read(_captureProvider.notifier)
          .recognize('share');
      final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
      expect(result.prefill, isNotNull);
      expect(result.prefill!.amount, isNull);
      expect(result.prefill!.occurredAt, _captureTime);
      expect(result.prefill!.note, '内部资金调拨');
      expect(result.prefill!.fromAccountId, isNull);
      expect(result.prefill!.toAccountId, isNull);
      expect(result.manualAction, isNull);
    },
  );

  for (final occurredAt in [null, _captureTime]) {
    test(
      'ordinary payments have no review notices with timestamp $occurredAt',
      () async {
        final container = _container(
          _Recognizer(
            () async => RecognizedPayment(
              direction: RecognizedPaymentDirection.income,
              amount: Money.parse('12.35'),
              occurredAt: occurredAt,
              needsReview: true,
            ),
          ),
        );
        final outcome = await container
            .read(_captureProvider.notifier)
            .recognize('share');
        final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
        expect(result.prefill, isNotNull);
        expect(result.prefill!.settlementAccountId, isNull);
        expect(result.prefill!.categoryId, isNull);
        expect(result.prefill!.occurredAt, _captureTime);
        expect(result.prefill!.reviewMessage, isEmpty);
        expect(result.reviewMessage, isEmpty);
      },
    );
  }

  test(
    'transfer prefill keeps unmatched sides empty and uses the current time',
    () async {
      final container = _container(
        _Recognizer(
          () async => RecognizedPayment(
            scene: PaymentScreenshotScene.transfer,
            amount: Money.parse('465.75'),
            transferToAccount: '虚构银行(7641)',
            needsReview: true,
          ),
        ),
        accounts: [_account('wallet', '日常付款')],
      );
      final outcome = await container
          .read(_captureProvider.notifier)
          .recognize('share');
      final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
      expect(result.prefill!.amount, Money.parse('465.75'));
      expect(result.prefill!.occurredAt, _captureTime);
      expect(result.prefill!.fromAccountId, isNull);
      expect(result.prefill!.toAccountId, isNull);
      expect(result.prefill!.settlementAccountId, isNull);
      expect(result.prefill!.categoryId, isNull);
      expect(result.prefill!.reviewMessage, isEmpty);
      expect(result.manualAction, isNull);
    },
  );

  test(
    'empty recognition and excluded scenes require explicit manual handling',
    () async {
      final cases = [
        (PaymentScreenshotScene.unknown, CaptureManualAction.chooseScene, null),
        (
          PaymentScreenshotScene.unpaid,
          CaptureManualAction.chooseScene,
          Money.parse('12.35'),
        ),
        (
          PaymentScreenshotScene.refund,
          CaptureManualAction.transactions,
          Money.parse('12.35'),
        ),
        (
          PaymentScreenshotScene.repayment,
          CaptureManualAction.accounts,
          Money.parse('12.35'),
        ),
      ];
      for (final entry in cases) {
        final container = _container(
          _Recognizer(
            () async => RecognizedPayment(
              scene: entry.$1,
              direction: entry.$1 == PaymentScreenshotScene.unknown
                  ? null
                  : RecognizedPaymentDirection.expense,
              amount: entry.$3,
            ),
          ),
        );
        final outcome = await container
            .read(_captureProvider.notifier)
            .recognize('share');
        final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
        expect(result.prefill, isNull, reason: entry.$1.name);
        expect(result.payment.scene, entry.$1);
        expect(result.manualAction, entry.$2);
        expect(result.reviewMessage, isNotEmpty);
        expect(container.read(_captureProvider).review, same(result));
      }
    },
  );

  test(
    'uses configured target identities despite different account and category names',
    () async {
      final recognized = RecognizedPayment(
        direction: RecognizedPaymentDirection.expense,
        amount: Money.parse('8.50'),
        occurredAt: DateTime(2026, 4, 5),
        paymentMethod: '零钱',
        accountMatchingText: '零钱',
        categoryMatchingText: '咖啡',
        accountRule: const RecognitionRuleMatch(
          path: ['微信'],
          ruleId: 'wallet-rule',
          targetAccountId: 'wallet',
          isFallback: false,
        ),
        categoryRule: const RecognitionRuleMatch(
          path: ['食品餐饮', '茶饮'],
          ruleId: 'coffee',
          targetAccountId: 'drinks',
          isFallback: false,
        ),
      );
      final container = _container(
        _Recognizer(() async => recognized),
        rules: [
          RecognitionRule(
            id: 'wallet-rule',
            kind: RecognitionRuleKind.account,
            keywords: const ['零钱'],
            priority: 2,
            targetAccountId: 'wallet',
          ),
          RecognitionRule(
            id: 'coffee',
            kind: RecognitionRuleKind.category,
            keywords: const ['咖啡'],
            priority: 1,
            targetAccountId: 'drinks',
            targetCategoryKind: ImportCategoryKind.expense,
          ),
        ],
        accounts: [_account('wallet', '生活账户')],
        categories: [
          CategoryNode(
            account: _account('food', '我的支出', type: AccountType.expense),
            children: [_account('drinks', '自定义饮料', type: AccountType.expense)],
          ),
        ],
      );
      final result = await container
          .read(_captureProvider.notifier)
          .recognize('share');
      final prefill =
          (result as UiActionSuccess<CaptureReviewResult>).value.prefill!;
      expect(prefill.settlementAccountId, 'wallet');
      expect(prefill.categoryId, 'drinks');
    },
  );

  test(
    'unmatched accounts remain empty and alias matches take the first account',
    () async {
      final categories = [
        CategoryNode(
          account: _account('food', '食品餐饮', type: AccountType.expense),
        ),
      ];
      final fallback = _container(
        _Recognizer(
          () async => RecognizedPayment(
            direction: RecognizedPaymentDirection.expense,
            amount: Money.parse('12.35'),
            categoryName: '食品餐饮',
            paymentMethod: '未知付款方式',
          ),
        ),
        accounts: [_account('wallet', '日常付款')],
        categories: categories,
        previousAccounts: {'food': 'wallet'},
      );
      final fallbackResult = await fallback
          .read(_captureProvider.notifier)
          .recognize('share');
      expect(
        (fallbackResult as UiActionSuccess<CaptureReviewResult>)
            .value
            .prefill!
            .settlementAccountId,
        isNull,
      );
      final alias = _container(
        _Recognizer(
          () async => RecognizedPayment(
            direction: RecognizedPaymentDirection.expense,
            amount: Money.parse('12.35'),
            categoryName: '食品餐饮',
            paymentMethod: '邮储银行储蓄卡（6620）',
          ),
        ),
        accounts: [_account('first', '邮储620'), _account('second', '中国邮政储蓄银行')],
        categories: categories,
      );
      final aliasResult = await alias
          .read(_captureProvider.notifier)
          .recognize('share');
      expect(
        (aliasResult as UiActionSuccess<CaptureReviewResult>)
            .value
            .prefill!
            .settlementAccountId,
        'first',
      );
    },
  );

  final time = DateTime(2026, 3, 4, 12, 5);
  RecognizedPayment payment() => RecognizedPayment(
    direction: RecognizedPaymentDirection.expense,
    amount: Money.parse('12.35'),
    occurredAt: time,
    counterparty: '示例书店',
    product: '图书',
    paymentMethod: '示例銀行储蓄卡(1234)',
    accountMatchingText: '示例銀行储蓄卡(1234)',
    categoryName: '学习 / 书籍',
    categoryMatchingText: '图书',
  );

  test(
    'prepares existing account, category, counterparty and duplicate suggestions',
    () async {
      final categories = [
        CategoryNode(
          account: _account('learning', '学习', type: AccountType.expense),
          children: [_account('books', '书籍', type: AccountType.expense)],
        ),
      ];
      final existing = TransactionReadModel(
        id: 'existing',
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: time,
        primaryAmount: Money.parse('12.35'),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      );
      final container = _container(
        _Recognizer(() async => payment()),
        rules: [
          RecognitionRule(
            id: 'books',
            kind: RecognitionRuleKind.category,
            keywords: ['图书'],
            priority: 1,
            targetAccountId: 'books',
            targetCategoryKind: ImportCategoryKind.expense,
          ),
        ],
        accounts: [_account('card', '示例銀行储蓄卡（1234）')],
        categories: categories,
        counterparties: const [CounterpartyView(id: 'shop', name: '示例书店')],
        transactions: [existing],
      );
      final outcome = await container
          .read(_captureProvider.notifier)
          .recognize('share');
      final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
      expect(result.prefill!.settlementAccountId, 'card');
      expect(result.prefill!.categoryId, 'books');
      expect(result.prefill!.counterpartyId, 'shop');
      expect(result.prefill!.amount, Money.parse('12.35'));
      expect(result.prefill!.note, '图书');
      expect(result.prefill!.reviewMessage, contains('可能重复'));
      expect(result.prefill!.reviewMessage.split('\n'), hasLength(1));
      expect(container.read(_captureProvider).recognizing, isFalse);
    },
  );

  test('partial account names do not match by card number suffix', () async {
    final container = _container(
      _Recognizer(() async => payment()),
      accounts: [_account('a', '卡 1234'), _account('b', '另一张卡 1234')],
    );
    final outcome = await container
        .read(_captureProvider.notifier)
        .recognize('share');
    final result = (outcome as UiActionSuccess<CaptureReviewResult>).value;
    expect(result.prefill!.settlementAccountId, isNull);
    expect(result.prefill!.categoryId, isNull);
    expect(result.prefill!.counterpartyId, isNull);
    expect(result.prefill!.note, '图书 · 示例书店');
  });

  test(
    'failed recognition exposes an error and permits a later retry',
    () async {
      var calls = 0;
      final container = _container(
        _Recognizer(() async {
          if (calls++ == 0) {
            throw InfrastructureException(RecognitionErrorCode.ocrFailed);
          }
          return payment();
        }),
      );
      final viewModel = container.read(_captureProvider.notifier);
      expect(
        await viewModel.recognize('share'),
        isA<UiActionFailure<CaptureReviewResult>>(),
      );
      expect(
        container.read(_captureProvider).error!.code,
        'capture.ocr_failed',
      );
      expect(
        await viewModel.recognize('share'),
        isA<UiActionSuccess<CaptureReviewResult>>(),
      );
      expect(container.read(_captureProvider).error, isNull);
    },
  );

  test(
    'leaving the recognition page does not update a disposed provider',
    () async {
      final pending = Completer<RecognizedPayment>();
      final container = _container(_Recognizer(() => pending.future));
      final viewModel = container.read(_captureProvider.notifier);
      final outcome = viewModel.recognize('share');
      container.invalidate(_captureProvider);
      pending.complete(payment());
      expect(await outcome, isA<UiActionSuccess<CaptureReviewResult>>());
    },
  );
}

ProviderContainer _container(
  _Recognizer recognizer, {
  List<Account> accounts = const [],
  List<CategoryNode> categories = const [],
  List<CounterpartyView> counterparties = const [],
  List<TransactionReadModel> transactions = const [],
  List<RecognitionRule> rules = const [],
  Map<String, String> previousAccounts = const {},
}) {
  final dependencies = _RuleDependencies(rules);
  final transactionQuery = _TransactionQuery(transactions, previousAccounts);
  final container = ProviderContainer(
    overrides: [
      _captureProvider.overrideWith(
        () => CaptureReviewViewModel('test-capture', now: () => _captureTime),
      ),
      recognitionRulesAppServiceProvider.overrideWithValue(
        RecognitionRulesAppService(
          builtins: RecognitionRuleCatalog(rules: const []),
          repository: dependencies,
          transactions: dependencies,
          ids: dependencies,
          targets: LedgerRecognitionRuleTargetQuery(
            accounts: _AccountQuery(accounts),
            categories: _CategoryQuery(categories),
          ),
        ),
      ),

      recognizePaymentScreenshotProvider.overrideWithValue(recognizer),
      accountQueryServiceProvider.overrideWithValue(_AccountQuery(accounts)),
      categoryQueryServiceProvider.overrideWithValue(
        _CategoryQuery(categories),
      ),
      counterpartyApplicationServiceProvider.overrideWithValue(
        _CounterpartyQuery(counterparties),
      ),
      transactionQueryServiceProvider.overrideWithValue(transactionQuery),
    ],
  );
  final subscription = container.listen(_captureProvider, (_, _) {});
  addTearDown(subscription.close);
  addTearDown(container.dispose);
  return container;
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
}) => Account(
  id: id,
  name: name,
  type: type,
  subtype: type == AccountType.asset ? AccountSubtype.fund : null,
  balance: Money.zero(),
);

class _Recognizer implements RecognizePaymentScreenshot {
  const _Recognizer(this.action);
  final Future<RecognizedPayment> Function() action;
  @override
  Future<RecognizedPayment> call(String shareId) => action();
}

class _AccountQuery implements AccountQueryService {
  const _AccountQuery(this.accounts);
  final List<Account> accounts;
  @override
  Future<List<Account>> findAccounts(Set<AccountType> types) async => accounts;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _CategoryQuery implements CategoryQueryService {
  const _CategoryQuery(this.categories);
  final List<CategoryNode> categories;
  @override
  Future<List<CategoryNode>> findCategoryTree(AccountType type) async =>
      categories.where((node) => node.account.type == type).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _CounterpartyQuery implements CounterpartyApplicationService {
  const _CounterpartyQuery(this.counterparties);
  final List<CounterpartyView> counterparties;
  @override
  Future<List<CounterpartyView>> listCounterparties() async => counterparties;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _TransactionQuery implements TransactionQueryService {
  const _TransactionQuery(this.transactions, this.previousAccounts);
  final List<TransactionReadModel> transactions;
  final Map<String, String> previousAccounts;
  @override
  Future<String?> findLastUsedSettlementAccountId(String categoryId) async =>
      previousAccounts[categoryId];
  @override
  Future<List<TransactionReadModel>> findTransactions(
    TransactionListQuery query,
  ) async => transactions;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RuleDependencies
    implements RecognitionRuleRepository, TransactionRunner, IdGenerator {
  _RuleDependencies(List<RecognitionRule> rules)
    : configuration = RecognitionRuleConfiguration(overrides: rules);
  RecognitionRuleConfiguration configuration;
  int nextId = 0;
  @override
  Future<RecognitionRuleConfiguration> loadConfiguration() async =>
      configuration;
  @override
  Future<void> saveConfiguration(RecognitionRuleConfiguration value) async {
    configuration = value;
  }

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
  @override
  String newId() => 'capture-rule-${++nextId}';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
