import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/recognition_rules_provider.dart';
import 'package:smartflow/app/router.dart';
import 'package:smartflow/application/intake/intake_rules_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_status_banner.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_catalog.dart';
import 'package:smartflow/domain/intake/rules/port/recognition_rule_repository.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_configuration.dart';
import 'package:smartflow/feature/capture/view_model/capture_review_view_model.dart';
import 'package:smartflow/feature/shared/provider/counterparty_providers.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_form_page.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_presentation.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form/transaction_form_view_model.dart';
import 'package:smartflow/infrastructure/intake/rules/ledger_recognition_rule_target_query.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';

import '../helper/test_app_database.dart';

final _captureTime = DateTime(2026, 4, 5, 14, 30);
final _transferTime = DateTime(2026, 4, 5, 9, 12);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.shxzz.smartflow/capture_intake');
  final messenger = binding.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets(
    'native OCR category and wrapped counterparty prefill the real expense form and survive confirmation',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'recognizeShare');
        expect(call.arguments, {'id': 'synthetic-image'});
        return {
          'blocks': [
            _block('账单详情', 20),
            _block('显示名称', 90),
            _block('-18.00', 145, height: 60),
            _block('交易成功', 240),
            _block('收款方全称', 300),
            _block('示例交通集团有限责任公司', 300, left: 300),
            _block('服务技术中心', 335, left: 300),
            _block('订单号', 375),
            _block('1234567890', 375, left: 300),
            _block('商品说明 服务充值', 420),
            _block('账单分类', 480),
            _block('充值缴费>', 480, left: 300),
            _block('付款方式 日常付款', 540),
          ],
          'loadTimeMs': 10,
          'totalTimeMs': 20,
        };
      });
      final fund = _account('fund', '日常付款');
      final category = Account(
        id: 'telecom-category',
        name: '充值缴费',
        type: AccountType.expense,
        balance: Money.zero(),
      );
      final accounts = _AccountQuery([fund]);
      final categories = _CategoryQuery([CategoryNode(account: category)]);
      final catalog = RecognitionRuleCatalog(
        rules: [
          RecognitionRule(
            id: 'telecom-rule',
            kind: RecognitionRuleKind.category,
            keywords: const ['充值缴费'],
            priority: 1,
            targetAccountId: category.id,
            targetPath: [category.name],
            targetCategoryKind: ImportCategoryKind.expense,
          ),
        ],
      );
      final dependencies = _RuleDependencies();
      final posting = _RecordingPostingService();
      final container = ProviderContainer(
        overrides: [
          testAppDatabaseOverride(),
          builtinRecognitionRuleCatalogProvider.overrideWithValue(catalog),
          accountQueryServiceProvider.overrideWithValue(accounts),
          categoryQueryServiceProvider.overrideWithValue(categories),
          tagListProvider.overrideWith((ref) => Stream.value(const [])),
          counterpartyListProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          transactionPostingAppServiceProvider.overrideWithValue(posting),
          recognitionRulesAppServiceProvider.overrideWithValue(
            RecognitionRulesAppService(
              builtins: catalog,
              repository: dependencies,
              targets: LedgerRecognitionRuleTargetQuery(
                accounts: accounts,
                categories: categories,
              ),
              transactions: dependencies,
              ids: dependencies,
            ),
          ),
          captureReviewViewModelProvider.overrideWith2(
            (sessionKey) =>
                CaptureReviewViewModel(sessionKey, now: () => _captureTime),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/test-entry',
        routes: [
          GoRoute(
            path: '/test-entry',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/capture/synthetic-image'),
                child: const Text('识别虚构截图'),
              ),
            ),
          ),
          ...appRouter.configuration.routes,
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('识别虚构截图'));
      await tester.pumpAndSettle();

      final page = tester.widget<TransactionFormPage>(
        find.byType(TransactionFormPage),
      );
      expect(page.initialMode, TransactionFormInitialMode.expense);
      final state = container
          .read(
            transactionFormViewModelProvider(
              prefill: page.prefill,
              initialMode: TransactionFormMode.expense,
            ),
          )
          .requireValue!;
      expect(state.expenseCategoryId, category.id);
      expect(state.fromAccountId, fund.id);
      const note = '服务充值 · 示例交通集团有限责任公司服务技术中心';
      final input = tester.widget<TransactionAmountInput>(
        find.byType(TransactionAmountInput),
      );
      expect(input.noteController.text, note);
      expect(input.amountController.text, '18.00');
      expect(posting.expenseCommands, isEmpty);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(posting.expenseCommands, hasLength(1));
      final saved = posting.expenseCommands.single;
      expect(saved.categoryAllocations.single.accountId, category.id);
      expect(saved.settlementAllocations.single.accountId, fund.id);
      expect(saved.note, note);
      expect(saved.amount, Money.parse('18.00'));
      expect(find.text('识别虚构截图'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final completed in [true, false]) {
    testWidgets(
      'native OCR ${completed ? 'completed' : 'pending'} withdrawal opens the real transfer form and saves only on confirmation',
      (tester) async {
        var ocrCalls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'recognizeShare');
          expect(call.arguments, {'id': 'synthetic-image'});
          ocrCalls++;
          return {
            'blocks': completed ? _completedWithdrawal() : _pendingWithdrawal(),
            'loadTimeMs': 10,
            'totalTimeMs': 20,
          };
        });
        final source = _account('fund', '零钱通');
        final destination = _account('bank', '建设银行储蓄卡');
        final accounts = _AccountQuery([
          // The bank's credit account must not win a fund-account suggestion.
          _account('credit', '建设银行信用卡', profile: AccountProfileKind.credit),
          _account('change', '零钱'),
          source,
          destination,
        ]);
        final categories = _CategoryQuery();
        final dependencies = _RuleDependencies();
        final posting = _RecordingPostingService();
        final container = ProviderContainer(
          overrides: [
            testAppDatabaseOverride(),
            builtinRecognitionRuleCatalogProvider.overrideWithValue(
              RecognitionRuleCatalog(rules: const []),
            ),
            accountQueryServiceProvider.overrideWithValue(accounts),
            categoryQueryServiceProvider.overrideWithValue(categories),
            tagListProvider.overrideWith((ref) => Stream.value(const [])),
            counterpartyListProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            transactionPostingAppServiceProvider.overrideWithValue(posting),
            recognitionRulesAppServiceProvider.overrideWithValue(
              RecognitionRulesAppService(
                builtins: RecognitionRuleCatalog(rules: const []),
                repository: dependencies,
                targets: LedgerRecognitionRuleTargetQuery(
                  accounts: accounts,
                  categories: categories,
                ),
                transactions: dependencies,
                ids: dependencies,
              ),
            ),
            captureReviewViewModelProvider.overrideWith2(
              (sessionKey) =>
                  CaptureReviewViewModel(sessionKey, now: () => _captureTime),
            ),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/test-entry',
          routes: [
            GoRoute(
              path: '/test-entry',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/capture/synthetic-image'),
                  child: const Text('识别虚构截图'),
                ),
              ),
            ),
            ...appRouter.configuration.routes,
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('识别虚构截图'));
        await tester.pumpAndSettle();

        expect(ocrCalls, 1);
        expect(find.byType(TransactionFormPage), findsOneWidget);
        final page = tester.widget<TransactionFormPage>(
          find.byType(TransactionFormPage),
        );
        expect(page.initialMode, TransactionFormInitialMode.transfer);
        expect(page.prefill, isNotNull);
        final provider = transactionFormViewModelProvider(
          prefill: page.prefill,
          initialMode: TransactionFormMode.transfer,
        );
        final state = container.read(provider).requireValue!;
        expect(state.fromAccountId, completed ? source.id : null);
        expect(state.toAccountId, destination.id);
        expect(state.occurredAt, completed ? _transferTime : _captureTime);
        expect(
          find.textContaining(completed ? '09:12' : '14:30'),
          findsOneWidget,
        );
        expect(state.expenseCategoryId, isNull);
        expect(state.incomeCategoryId, isNull);
        expect(state.counterpartyId, isNull);
        expect(find.byType(AppStatusBanner), findsNothing);
        final input = tester.widget<TransactionAmountInput>(
          find.byType(TransactionAmountInput),
        );
        expect(input.amountController.text, completed ? '385.50' : '465.75');
        expect(find.text('建设银行储蓄卡'), findsOneWidget);
        expect(posting.commands, isEmpty);

        if (!completed) {
          expect(find.text('转出账户为空'), findsOneWidget);
          await tester.tap(find.text('完成'));
          await tester.pumpAndSettle();
          expect(find.text('请选择转出账户'), findsOneWidget);
          expect(posting.commands, isEmpty);
          await tester.tap(find.text('转出账户'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('零钱通'));
          await tester.pumpAndSettle();
        }
        input.amountController.text = '400.25';
        input.noteController.text = '虚构转账备注';
        await tester.pump();
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        expect(posting.commands, hasLength(1));
        final saved = posting.commands.single;
        expect(saved.amount, Money.parse('400.25'));
        expect(saved.occurredAt, completed ? _transferTime : _captureTime);
        expect(saved.note, '虚构转账备注');
        expect(saved.outgoingAllocations.single.accountId, source.id);
        expect(saved.incomingAllocations.single.accountId, destination.id);
        expect(find.text('识别虚构截图'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

// All content is invented; the layouts retain the native OCR's semantic regions.
List<Map<String, Object>> _completedWithdrawal() => [
  _block('09:21 □', 10, confidence: 0.85),
  _block('详情', 80),
  _block('◇', 160, height: 70, confidence: 0.4),
  _block('零钱通转出-到建设银行(7641)', 280),
  _block('-385.50', 340, height: 60),
  _block('当前状态', 500),
  _block('转出资金', 500, left: 300),
  _block('2026-04-05 09:12:00', 540, left: 300),
  _block('基金公司处理中', 600, left: 300),
  _block('资金到账', 660, left: 300),
  _block('2026-04-07 14:00:00', 700, left: 300),
  _block('零钱通余额 ￥1357.90', 760),
  _block('收款账号', 820),
  _block('建设银行', 820, left: 300),
];

List<Map<String, Object>> _pendingWithdrawal() => [
  _block('09:21 □', 10, confidence: 0.85),
  _block('88.0', 10, left: 400, height: 14),
  _block('◇', 220, height: 90, confidence: 0.4),
  _block('预计4月7日(2天后)14:00前到账', 370),
  _block('转出金额', 500),
  _block('￥465.75', 500, left: 400),
  _block('到账银行卡', 550),
  _block('建设银行(7641)', 550, left: 380),
  _block('完成', 1200),
];

Map<String, Object> _block(
  String text,
  double top, {
  double left = 20,
  double height = 30,
  double confidence = 0.99,
}) => {
  'text': text,
  'confidence': confidence,
  'left': left,
  'top': top,
  'right': left + 260,
  'bottom': top + height,
};

Account _account(
  String id,
  String name, {
  AccountProfileKind profile = AccountProfileKind.fund,
}) => Account(
  id: id,
  name: name,
  type: profile.accountType,
  subtype: profile.accountSubtype,
  profileKey: profile.key,
  balance: Money.zero(),
);

class _AccountQuery implements AccountQueryService {
  const _AccountQuery(this.accounts);
  final List<Account> accounts;
  @override
  Future<List<Account>> findAccounts(Set<AccountType> types) async => accounts;
  @override
  Stream<List<Account>> watchAccounts(Set<AccountType> types) =>
      Stream.value(accounts);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _CategoryQuery implements CategoryQueryService {
  _CategoryQuery([this.expenseTree = const []]);
  final List<CategoryNode> expenseTree;

  @override
  Future<List<CategoryNode>> findCategoryTree(AccountType type) async =>
      type == AccountType.expense ? expenseTree : const [];
  @override
  Stream<List<CategoryNode>> watchCategoryTree(AccountType type) =>
      Stream.value(type == AccountType.expense ? expenseTree : const []);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingPostingService implements TransactionPostingAppService {
  final commands = <CreateTransferCommand>[];
  final expenseCommands = <CreateExpenseCommand>[];

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
    expenseCommands.add(command);
    return const PostedTransactionResult(transactionId: 'expense');
  }

  @override
  Future<PostedTransactionResult> createTransfer(
    CreateTransferCommand command,
  ) async {
    commands.add(command);
    return const PostedTransactionResult(transactionId: 'transfer');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RuleDependencies
    implements RecognitionRuleRepository, TransactionRunner, IdGenerator {
  @override
  Future<RecognitionRuleConfiguration> loadConfiguration() async =>
      const RecognitionRuleConfiguration();
  @override
  Future<void> saveConfiguration(
    RecognitionRuleConfiguration configuration,
  ) async {}
  @override
  Future<T> run<T>(Future<T> Function() body) => body();
  @override
  String newId() => 'rule';
}
