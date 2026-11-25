import 'dart:async';
import 'package:smartflow/feature/transaction/presentation/transaction_form_prefill.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form/transaction_form_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/intake/import/import_workflow_models.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/intake/import/import_models.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_catalog.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/database/drift_app_settings_store.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/feature/shared/provider/book_providers.dart';

import '../../../helper/test_app_database.dart';

void main() {
  late _Fixture fixture;
  setUp(() async => fixture = await _Fixture.create());

  test(
    'a new form snapshots the current book and submits its own selection',
    () async {
      final current = fixture.container.read(
        bookSelectionViewModelProvider.notifier,
      );
      await fixture.container
          .read(bookSelectionViewModelProvider.notifier)
          .snapshot();
      await current.selectBook(fixture.b.id);
      await fixture.container.pump();
      final prefill = TransactionFormPrefill(
        occurredAt: DateTime(2026, 1, 10),
        note: '',
        reviewMessage: '',
        amount: const Money(minorUnits: 10000),
        settlementAccountId: fixture.cash.id,
        categoryId: fixture.category.id,
      );
      final form = transactionFormViewModelProvider(prefill: prefill);
      final ready = Completer<TransactionFormState>();
      final subscription = fixture.container.listen(form, (_, next) {
        if (ready.isCompleted) return;
        if (next.hasError) {
          ready.completeError(next.error!, next.stackTrace);
        } else if (next.hasValue && next.value != null) {
          ready.complete(next.requireValue!);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      final initial = await ready.future.timeout(const Duration(seconds: 10));
      expect(initial.bookId, fixture.b.id);
      expect(
        initial.bookOptions.map((book) => book.id),
        containsAll([Book.dailyId, fixture.a.id, fixture.b.id, fixture.c.id]),
      );
      fixture.container.read(form.notifier).selectBook(fixture.c.id);
      await current.selectBook(fixture.a.id);
      await fixture.container.pump();
      expect(fixture.container.read(form).requireValue!.bookId, fixture.c.id);
      final outcome = await fixture.container
          .read(form.notifier)
          .submit(amountText: '100', noteText: 'book');
      expect(outcome, isA<SubmitSuccess>());
      expect(
        (await fixture.db.select(fixture.db.transactions).get()).single.bookId,
        fixture.c.id,
      );
      expect(
        (await DriftAppSettingsStore(fixture.db).read()).currentBookId,
        fixture.a.id,
      );
    },
  );

  test(
    'null defaults to daily; an invalid book rolls back the posting',
    () async {
      final id = await fixture.expense();
      expect((await fixture.transaction(id))!.bookId, Book.dailyId);
      final before = (await fixture.account())!.balance;
      await expectLater(
        fixture.expense(bookId: 'missing'),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            LedgerErrorCode.bookNotFound.code,
          ),
        ),
      );
      expect((await fixture.account())!.balance, before);
      expect(
        await fixture.db.select(fixture.db.transactions).get(),
        hasLength(1),
      );
    },
  );

  test('all books persists its scope and new transactions use daily', () async {
    final selection = fixture.container.read(
      bookSelectionViewModelProvider.notifier,
    );
    await selection.snapshot();
    await selection.selectBook(fixture.b.id);
    await selection.selectBook(null);
    await fixture.container.pump();

    final settings = await DriftAppSettingsStore(fixture.db).read();
    expect(settings.currentBookId, Book.dailyId);
    expect(settings.showAllBooks, isTrue);
    final selected = await selection.snapshot();
    expect(selected.currentBook.id, Book.dailyId);
    expect(selected.queryBookId, isNull);
    expect(selected.books.map((book) => book.id), [
      Book.dailyId,
      fixture.a.id,
      fixture.b.id,
      fixture.c.id,
    ]);

    final prefill = TransactionFormPrefill(
      occurredAt: DateTime(2026, 1, 10),
      note: '',
      reviewMessage: '',
      amount: const Money(minorUnits: 10000),
      settlementAccountId: fixture.cash.id,
      categoryId: fixture.category.id,
    );
    final form = transactionFormViewModelProvider(prefill: prefill);
    final ready = Completer<TransactionFormState>();
    final subscription = fixture.container.listen(form, (_, next) {
      if (ready.isCompleted) return;
      if (next.hasError) {
        ready.completeError(next.error!, next.stackTrace);
      } else if (next.value case final value?) {
        if (value.expenseSettlementAccounts.any(
          (account) => account.id == fixture.cash.id,
        )) {
          ready.complete(value);
        }
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    final initial = await ready.future.timeout(const Duration(seconds: 10));
    expect(initial.bookId, Book.dailyId);
    final outcome = await fixture.container
        .read(form.notifier)
        .submit(amountText: '100', noteText: 'all books');
    expect(
      outcome,
      isA<SubmitSuccess>(),
      reason: outcome is SubmitFailure ? outcome.error.message : null,
    );
    final dailyTransaction =
        (await fixture.db.select(fixture.db.transactions).get()).single;
    expect(dailyTransaction.bookId, Book.dailyId);
    final otherTransactionId = await fixture.expense(bookId: fixture.a.id);
    final month = MonthKey(year: 2026, month: 1);
    final allActivities = await fixture.container
        .read(businessActivityQueryServiceProvider)
        .findPage(
          BusinessActivityPageQuery(
            bookId: selected.queryBookId,
            occurredFrom: month.start,
            occurredUntil: month.nextMonthStart,
          ),
        );
    expect(
      allActivities.items.map((activity) => activity.displayTransactionId),
      unorderedEquals([dailyTransaction.id, otherTransactionId]),
    );
    final metrics = fixture.container.read(financialMetricsServiceProvider);
    final total = await metrics
        .watchCashflowComparison(
          CashflowComparisonQuery(month: month, bookId: selected.queryBookId),
        )
        .first;
    final daily = await metrics
        .watchDailyCashflowSummaries(
          DailyCashflowSummaryQuery(month: month, bookId: selected.queryBookId),
        )
        .first;
    expect(total.current.expense, const Money(minorUnits: 20000));
    expect(daily.single.expense, const Money(minorUnits: 20000));

    await selection.selectBook(fixture.a.id);
    await fixture.container.pump();
    final specific = await selection.snapshot();
    expect(specific.currentBook.id, fixture.a.id);
    expect(specific.queryBookId, fixture.a.id);
    final restored = await DriftAppSettingsStore(fixture.db).read();
    expect(restored.currentBookId, fixture.a.id);
    expect(restored.showAllBooks, isFalse);
  });

  test('an interest-only import retains the selected book', () async {
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      sourceEntities: const [
        ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.account,
          sourceEntityKey: 'book-import-wallet',
          displayName: '现金测试',
        ),
      ],
      groups: [
        ImportTransactionGroupDraft(
          topLevel: ImportInterestExpenseDraft(
            amount: const Money(minorUnits: 200),
            paidFrom: const ImportAccountReference.source(
              sourceEntityKey: 'book-import-wallet',
              displayName: '现金测试',
            ),
            occurredAt: DateTime(2026, 1, 10),
          ),
          sourceOperationFingerprint: 'book-interest-only',
          fingerprintVersion: 1,
        ),
      ],
    );
    final result = await fixture.container
        .read(importWorkflowAppServiceProvider)
        .commit(
          ImportCommitCommand(
            bookId: fixture.b.id,
            plan: plan,
            mappings: {
              const ImportMappingKey(
                source: ImportSource.yimu,
                entityKind: ImportEntityKind.account,
                sourceEntityKey: 'book-import-wallet',
              ): fixture.cash.id,
            },
            selectedGroupIndexes: const {0},
          ),
        );
    expect(result.batch, isNotNull);
    final transaction = await fixture.db
        .select(fixture.db.transactions)
        .getSingle();
    expect(transaction.primaryAmountMinor, 200);
    expect(transaction.bookId, fixture.b.id);
  });

  test(
    'cross-book refund keeps the activity in the origin book and splits cashflow',
    () async {
      final expenseId = await fixture.expense(bookId: fixture.a.id);
      final refundId = await fixture.refund(expenseId, bookId: fixture.b.id);
      final activities = fixture.container.read(
        businessActivityQueryServiceProvider,
      );
      final month = MonthKey(year: 2026, month: 1);
      final inA = await activities.findPage(
        BusinessActivityPageQuery(
          occurredFrom: month.start,
          occurredUntil: month.nextMonthStart,
          bookId: fixture.a.id,
        ),
      );
      final inB = await activities.findPage(
        BusinessActivityPageQuery(
          occurredFrom: month.start,
          occurredUntil: month.nextMonthStart,
          bookId: fixture.b.id,
        ),
      );
      expect(inA.items.map((activity) => activity.displayTransactionId), [
        expenseId,
      ]);
      expect(inB.items, isEmpty);
      expect((await fixture.transaction(refundId))!.bookId, fixture.b.id);

      final metrics = fixture.container.read(financialMetricsServiceProvider);
      final summaryA = await metrics
          .watchCashflowComparison(
            CashflowComparisonQuery(month: month, bookId: fixture.a.id),
          )
          .first;
      final summaryB = await metrics
          .watchCashflowComparison(
            CashflowComparisonQuery(month: month, bookId: fixture.b.id),
          )
          .first;
      final total = await metrics
          .watchCashflowComparison(CashflowComparisonQuery(month: month))
          .first;
      expect(summaryA.current.expense, const Money(minorUnits: 10000));
      expect(summaryB.current.expense, const Money(minorUnits: -2000));
      expect(total.current.expense, const Money(minorUnits: 8000));
      final dailyB = await metrics
          .watchDailyCashflowSummaries(
            DailyCashflowSummaryQuery(month: month, bookId: fixture.b.id),
          )
          .first;
      expect(dailyB.single.expense, const Money(minorUnits: -2000));
    },
  );

  test(
    'changing and rewriting a parent preserves the child book and accounting facts',
    () async {
      final expenseId = await fixture.expense(bookId: fixture.a.id);
      final refundId = await fixture.refund(expenseId, bookId: fixture.b.id);
      final lines = await fixture.db.select(fixture.db.transactionLines).get();
      final entries = await fixture.db.select(fixture.db.entries).get();
      final before = (await fixture.account())!.balance;
      await fixture.books.changeTransactionBook(
        ChangeTransactionBookCommand(
          transactionId: expenseId,
          bookId: fixture.c.id,
        ),
      );
      expect((await fixture.transaction(refundId))!.bookId, fixture.b.id);
      expect((await fixture.account())!.balance, before);
      expect(await fixture.db.select(fixture.db.transactionLines).get(), lines);
      expect(await fixture.db.select(fixture.db.entries).get(), entries);

      await fixture.container
          .read(transactionEditAppServiceProvider)
          .editExpense(
            EditExpenseCommand(
              transactionId: expenseId,
              amount: const Money(minorUnits: 12000),
            ),
          );
      expect((await fixture.transaction(expenseId))!.bookId, fixture.c.id);
      expect((await fixture.transaction(refundId))!.bookId, fixture.b.id);
      expect(
        (await fixture.transaction(refundId))!.parentTransactionId,
        expenseId,
      );
    },
  );

  test(
    'books are managed by stable ID; daily and referenced books cannot be deleted',
    () async {
      await fixture.books.renameBook(
        RenameBookCommand(id: fixture.a.id, name: '  旅行  '),
      );
      expect(
        (await fixture.container
                .read(bookQueryServiceProvider)
                .findBook(fixture.a.id))!
            .name,
        '旅行',
      );
      await expectLater(
        fixture.books.deleteBook(const DeleteBookCommand(id: Book.dailyId)),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            LedgerErrorCode.bookBuiltin.code,
          ),
        ),
      );
      await fixture.expense(bookId: fixture.a.id);
      await expectLater(
        fixture.books.deleteBook(DeleteBookCommand(id: fixture.a.id)),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            LedgerErrorCode.bookInUse.code,
          ),
        ),
      );
      await expectLater(
        fixture.books.createBook(const CreateBookCommand(name: '旅行')),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            LedgerErrorCode.bookNameExists.code,
          ),
        ),
      );

      final selection = fixture.container.read(
        bookSelectionViewModelProvider.notifier,
      );
      await fixture.container
          .read(bookSelectionViewModelProvider.notifier)
          .snapshot();
      await selection.selectBook(fixture.c.id);
      expect(
        (await DriftAppSettingsStore(fixture.db).read()).currentBookId,
        fixture.c.id,
      );
      await selection.deleteBook(fixture.c);
      expect(
        (await DriftAppSettingsStore(fixture.db).read()).currentBookId,
        Book.dailyId,
      );
    },
  );

  test(
    'scheduled amortization uses the current origin book and retains posted periods',
    () async {
      final deferral = await fixture.container
          .read(accountAppServiceProvider)
          .createAccount(
            const CreateAccountCommand(
              name: '预付',
              type: AccountType.asset,
              subtype: AccountSubtype.prepaidExpense,
              profileKey: 'ledger.prepaidExpense',
            ),
          );
      final service = fixture.container.read(
        amortizationPlanAppServiceProvider,
      );
      final planId = await service.createPlan(
        CreateAmortizationPlanCommand(
          bookId: fixture.a.id,
          kind: AmortizationKind.prepaidExpense,
          total: const Money(minorUnits: 20000),
          fundingAllocations: [
            AccountAmountAllocation(
              accountId: fixture.cash.id,
              amount: const Money(minorUnits: 20000),
            ),
          ],
          deferralAccountId: deferral.id,
          recognitionAllocations: [
            AccountAmountAllocation(
              accountId: fixture.category.id,
              amount: const Money(minorUnits: 20000),
            ),
          ],
          firstRecognitionAt: DateTime(2026, 1, 31),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 1,
          recognitionCount: 2,
          occurredAt: DateTime(2026, 1, 1),
        ),
      );
      await service.generateDue(DateTime(2026, 1, 31));
      final plan = (await fixture.container
          .read(amortizationPlanQueryServiceProvider)
          .findById(planId))!;
      final firstId = plan.periods.first.transactionId!;
      expect((await fixture.transaction(firstId))!.bookId, fixture.a.id);
      await fixture.books.changeTransactionBook(
        ChangeTransactionBookCommand(
          transactionId: plan.initialTransactionId,
          bookId: fixture.b.id,
        ),
      );
      await service.generateDue(DateTime(2026, 2, 28));
      final completed = (await fixture.container
          .read(amortizationPlanQueryServiceProvider)
          .findById(planId))!;
      expect((await fixture.transaction(firstId))!.bookId, fixture.a.id);
      expect(
        (await fixture.transaction(
          completed.periods.last.transactionId!,
        ))!.bookId,
        fixture.b.id,
      );
    },
  );

  test('v17 backup transactions are upgraded to the daily book', () async {
    final id = await fixture.expense(bookId: fixture.b.id);
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-book-backup-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = BackupService(
      gateway: DriftBackupGateway(fixture.db),
      packageStore: const FileBackupPackageStore(),
      appVersion: 'test',
    );
    await service.createBackup(directory);
    final manifestFile = File('${directory.path}/manifest.json');
    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final files = manifest['requiredFiles'] as List;
    final booksFile =
        files.singleWhere((entry) => entry['table'] == 'books') as Map;
    await File('${directory.path}/${booksFile['path']}').delete();
    files.remove(booksFile);
    final transactionsFile =
        files.singleWhere((entry) => entry['table'] == 'transactions') as Map;
    final dataFile = File('${directory.path}/${transactionsFile['path']}');
    final rows = await dataFile.readAsLines();
    final content = rows
        .where((row) => row.isNotEmpty)
        .map((row) {
          final decoded = jsonDecode(row) as Map<String, dynamic>;
          decoded.remove('bookId');
          return jsonEncode(decoded);
        })
        .join('\n');
    final bytes = utf8.encode('$content\n');
    await dataFile.writeAsBytes(bytes);
    transactionsFile['byteCount'] = bytes.length;
    transactionsFile['sha256'] = sha256.convert(bytes).toString();
    manifest['backupSchemaVersion'] = 17;
    await manifestFile.writeAsString(jsonEncode(manifest));
    final inspected = await service.inspect(directory);
    expect(inspected.snapshot.rows('books').single['id'], Book.dailyId);
    final transaction = inspected.snapshot.rows('transactions').single;
    expect(transaction['id'], id);
    expect(transaction['bookId'], Book.dailyId);
    expect(transaction['primaryAmountMinor'], 10000);
  });

  test(
    'backup round trip retains books and rejects a dangling transaction book',
    () async {
      final id = await fixture.expense(bookId: fixture.b.id);
      final snapshot = await DriftBackupGateway(fixture.db).readSnapshot();
      BackupService.validateSnapshot(snapshot);
      final restored = createTestDatabase();
      addTearDown(restored.close);
      await DriftBackupGateway(restored).replaceSnapshot(snapshot);
      expect(
        (await restored.select(restored.books).get())
            .map((book) => book.id)
            .toSet(),
        {Book.dailyId, fixture.a.id, fixture.b.id, fixture.c.id},
      );
      expect(
        (await restored.select(restored.transactions).get()).single.bookId,
        fixture.b.id,
      );
      final invalid = snapshot.copyWith(
        tables: {
          ...snapshot.tables,
          'transactions': [
            for (final row in snapshot.rows('transactions'))
              {...row, 'bookId': 'missing'},
          ],
        },
      );
      expect(
        () => BackupService.validateSnapshot(invalid),
        throwsA(isA<BackupValidationException>()),
      );
      expect((await fixture.transaction(id))!.bookId, fixture.b.id);
    },
  );
}

class _Fixture {
  _Fixture(
    this.db,
    this.container,
    this.cash,
    this.category,
    this.a,
    this.b,
    this.c,
  );
  final AppDatabase db;
  final ProviderContainer container;
  final Account cash;
  final Account category;
  final Book a;
  final Book b;
  final Book c;

  BookAppService get books => container.read(bookAppServiceProvider);

  static Future<_Fixture> create() async {
    final db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        builtinRecognitionRuleCatalogProvider.overrideWithValue(
          RecognitionRuleCatalog(rules: const []),
        ),
        amortizationPlanAppServiceProvider.overrideWith(
          (ref) => AmortizationPlanAppServiceImpl(
            repository: ref.watch(amortizationRepositoryProvider),
            ledger: ref.watch(amortizationLedgerPortProvider),
            transactionRunner: ref.watch(transactionRunnerProvider),
            idGenerator: ref.watch(idGeneratorProvider),
            now: () => DateTime(2026, 1, 1),
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final cash = await container
        .read(accountAppServiceProvider)
        .createAccount(
          const CreateAccountCommand(
            name: '现金测试',
            type: AccountType.asset,
            subtype: AccountSubtype.fund,
            profileKey: 'ledger.fund',
          ),
        );
    final category = await container
        .read(categoryAppServiceProvider)
        .createCategory(
          const CreateCategoryCommand(
            name: '账本测试分类',
            type: AccountType.expense,
          ),
        );
    final books = container.read(bookAppServiceProvider);
    final a = await books.createBook(const CreateBookCommand(name: 'A'));
    final b = await books.createBook(const CreateBookCommand(name: 'B'));
    final c = await books.createBook(const CreateBookCommand(name: 'C'));
    return _Fixture(db, container, cash, category, a, b, c);
  }

  Future<Account?> account() =>
      container.read(accountQueryServiceProvider).findAccountById(cash.id);
  Future<Transaction?> transaction(String id) =>
      container.read(transactionQueryServiceProvider).findTransactionById(id);

  Future<String> expense({String? bookId}) async =>
      (await container
              .read(transactionPostingAppServiceProvider)
              .createExpense(
                CreateExpenseCommand(
                  bookId: bookId,
                  amount: const Money(minorUnits: 10000),
                  categoryAllocations: [
                    AccountAmountAllocation(
                      accountId: category.id,
                      amount: const Money(minorUnits: 10000),
                    ),
                  ],
                  settlementAllocations: [
                    AccountAmountAllocation(
                      accountId: cash.id,
                      amount: const Money(minorUnits: 10000),
                    ),
                  ],
                  occurredAt: DateTime(2026, 1, 10),
                ),
              ))
          .transactionId;

  Future<String> refund(String parentId, {required String bookId}) async =>
      (await container
              .read(transactionPostingAppServiceProvider)
              .createRefund(
                CreateRefundCommand(
                  bookId: bookId,
                  parentTransactionId: parentId,
                  amount: const Money(minorUnits: 2000),
                  categoryAllocations: [
                    AccountAmountAllocation(
                      accountId: category.id,
                      amount: const Money(minorUnits: 2000),
                    ),
                  ],
                  settlementAllocations: [
                    AccountAmountAllocation(
                      accountId: cash.id,
                      amount: const Money(minorUnits: 2000),
                    ),
                  ],
                  occurredAt: DateTime(2026, 1, 11),
                ),
              ))
          .transactionId;
}
