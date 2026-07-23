// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/import/import_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/import/page/import_page.dart';
import 'package:smartflow/feature/import/presentation/import_presentation.dart';

void main() {
  testWidgets('shows import sources and recent history entry points', (
    tester,
  ) async {
    await tester.pumpWidget(_app(page: const ImportPage()));
    await tester.pump();

    expect(find.text('数据导入'), findsOneWidget);
    expect(find.text('一木记账'), findsOneWidget);
    expect(find.text('微信账单'), findsOneWidget);
    expect(find.text('支付宝账单'), findsOneWidget);
    expect(find.text('云闪付账单'), findsOneWidget);
    expect(find.text('其他格式'), findsOneWidget);
    expect(find.text('查看全部'), findsOneWidget);
  });

  testWidgets('shows fatal package issues and keeps the workflow retryable', (
    tester,
  ) async {
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      fatalIssues: const [
        ImportIssue(
          code: 'missing_file_role',
          message: '资料包缺少债务文件。',
          severity: ImportIssueSeverity.fatal,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(planService: _FakePlanService(plan), picker: _FakePicker(_bundle())),
    );
    await _selectAndParse(tester);

    expect(find.text('资料包无法继续解析'), findsOneWidget);
    expect(find.text('资料包缺少债务文件。'), findsOneWidget);
    expect(find.text('解析未通过'), findsOneWidget);
  });

  testWidgets('shows status for every file in a multi-file package', (
    tester,
  ) async {
    const transferIssue = ImportIssue(
      code: 'file_decode_failed',
      message: '无法读取一木文件 转账.xls，请重新导出。',
      severity: ImportIssueSeverity.fatal,
      fileRole: YimuFileRole.transfer,
    );
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      fileResults: [
        ImportFileParseResult(
          fileIndex: 0,
          fileName: '账单.xls',
          fileRole: YimuFileRole.bill,
        ),
        ImportFileParseResult(
          fileIndex: 1,
          fileName: '转账.xls',
          fileRole: YimuFileRole.transfer,
          fatalIssues: const [transferIssue],
        ),
      ],
      fatalIssues: const [transferIssue],
    );
    final bundle = ImportBundle(
      files: [
        ImportFilePayload(name: '账单.xls', bytes: Uint8List.fromList([1, 2])),
        ImportFilePayload(name: '转账.xls', bytes: Uint8List.fromList([3, 4])),
      ],
    );
    await tester.pumpWidget(
      _app(planService: _FakePlanService(plan), picker: _FakePicker(bundle)),
    );

    await _selectAndParse(tester);

    expect(find.text('账单.xls'), findsOneWidget);
    expect(find.text('转账.xls'), findsOneWidget);
    expect(find.text('解析成功'), findsOneWidget);
    expect(find.text('解析失败'), findsOneWidget);
  });

  testWidgets(
    'renders mappings and transaction groups as whole selectable units',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final plan = _plan();
      await tester.pumpWidget(
        _app(
          planService: _FakePlanService(plan),
          picker: _FakePicker(_bundle()),
          workflow: _FakeWorkflow(_review(plan)),
        ),
      );
      await _selectAndParse(tester);

      expect(find.text('账户与分类映射'), findsOneWidget);
      expect(find.text('现金'), findsWidgets);
      expect(find.byType(ExpansionTile), findsAtLeastNWidgets(1));
      expect(find.text('导入预览（前 5 条）'), findsOneWidget);
      expect(find.text('解析成功'), findsOneWidget);
      expect(find.text('导入'), findsOneWidget);
    },
  );

  testWidgets('history page shows task records and revert action', (
    tester,
  ) async {
    final batch = ImportBatch(
      id: 'batch-1',
      source: ImportSource.yimu,
      status: ImportBatchStatus.imported,
      importedGroupCount: 2,
      createdTransactionCount: 3,
      skippedGroupCount: 1,
      importedAt: DateTime(2026, 7, 22, 10),
    );
    await tester.pumpWidget(
      _app(
        page: const ImportHistoryPage(),
        workflow: _FakeWorkflow(_review(_plan()), batches: [batch]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一木记账_20260722100000'), findsOneWidget);
    expect(find.text('导入 3 条交易 · 2 个交易组'), findsOneWidget);
    expect(find.text('部分导入'), findsOneWidget);
    expect(find.text('跳过 1 个交易组'), findsOneWidget);
    expect(find.text('撤销批次'), findsOneWidget);
  });

  testWidgets('review exposes draft editing and warning confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _plan();
    final warningGroup = base.groups.single.copyWith(
      issues: const [
        ImportIssue(
          code: 'review_warning',
          message: '请确认解析结果。',
          severity: ImportIssueSeverity.warning,
        ),
        ImportIssue(
          code: 'date_invalid',
          message: '交易日期无法解析。',
          severity: ImportIssueSeverity.blocking,
        ),
      ],
    );
    final plan = base.copyWith(groups: [warningGroup]);
    final review = ImportPlanReview(
      plan: plan,
      defaultMappings: const {},
      effectiveMappings: _review(base).effectiveMappings,
      suggestions: const [],
      targets: _review(base).targets,
      groups: [
        ImportGroupReview(
          index: 0,
          group: warningGroup,
          issues: warningGroup.issues,
          isExactDuplicate: false,
          isSuspectedDuplicate: false,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(plan),
        picker: _FakePicker(_bundle()),
        workflow: _FakeWorkflow(review),
      ),
    );
    await _selectAndParse(tester);
    await _openFirstReviewGroup(tester);

    expect(find.text('确认警告后导入此交易组'), findsOneWidget);
    expect(find.text('编辑顶层交易'), findsOneWidget);
    await tester.tap(find.text('编辑顶层交易'));
    await tester.pumpAndSettle();
    expect(find.text('编辑普通支出'), findsOneWidget);
    expect(find.text('交易时间'), findsOneWidget);
    expect(find.text('入账时间'), findsOneWidget);
  });

  testWidgets('transfer review exposes its fee for editing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final plan = _planWithDraft(
      ImportTransferDraft(
        amount: Money.parse('100.00'),
        fromAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:cash',
          displayName: '现金',
        ),
        toAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:bank',
          displayName: '银行卡',
        ),
        feeAmount: Money.parse('1.00'),
        occurredAt: DateTime(2026, 7, 20),
      ),
    );
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(plan),
        picker: _FakePicker(_bundle()),
        workflow: _FakeWorkflow(_review(plan)),
      ),
    );
    await _selectAndParse(tester);
    await _openFirstReviewGroup(tester);
    await tester.tap(find.text('编辑顶层交易'));
    await tester.pumpAndSettle();

    expect(find.text('转账手续费'), findsOneWidget);
  });

  testWidgets('repayment review exposes interest and fee for editing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final plan = _planWithDraft(
      ImportRepaymentDraft(
        principal: Money.parse('100.00'),
        interest: Money.parse('2.00'),
        fee: Money.parse('1.00'),
        liabilityAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:loan',
          displayName: '借款',
        ),
        paidFrom: const ImportAccountReference.source(
          sourceEntityKey: 'account:cash',
          displayName: '现金',
        ),
        occurredAt: DateTime(2026, 7, 20),
      ),
    );
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(plan),
        picker: _FakePicker(_bundle()),
        workflow: _FakeWorkflow(_review(plan)),
      ),
    );
    await _selectAndParse(tester);
    await _openFirstReviewGroup(tester);
    await tester.tap(find.text('编辑顶层交易'));
    await tester.pumpAndSettle();

    expect(find.text('利息'), findsOneWidget);
    expect(find.text('手续费'), findsOneWidget);
  });
}

Widget _app({
  Widget page = const ImportProcessPage(source: ImportEntrySource.yimu),
  ImportPlanAppService? planService,
  ImportWorkflowAppService? workflow,
  ImportFilePicker? picker,
}) {
  return ProviderScope(
    overrides: [
      importPlanAppServiceProvider.overrideWithValue(
        planService ?? _FakePlanService(_plan()),
      ),
      importWorkflowAppServiceProvider.overrideWithValue(
        workflow ?? _FakeWorkflow(_review(_plan())),
      ),
      importFilePickerProvider.overrideWithValue(picker ?? _FakePicker(null)),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: page),
  );
}

Future<void> _selectAndParse(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.text('选择文件'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('解析'));
  await tester.pumpAndSettle();
}

Future<void> _openFirstReviewGroup(WidgetTester tester) async {
  await tester.tap(find.text('导入检查与选择'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ExpansionTile).last);
  await tester.pumpAndSettle();
}

ImportBundle _bundle() {
  return ImportBundle(
    files: [
      ImportFilePayload(name: '账单.xls', bytes: Uint8List.fromList([1])),
    ],
  );
}

ImportParseResult _plan() {
  return ImportParseResult(
    source: ImportSource.yimu,
    fileResults: [
      ImportFileParseResult(
        fileIndex: 0,
        fileName: '账单.xls',
        fileRole: YimuFileRole.bill,
      ),
    ],
    sourceEntities: const [
      ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:cash',
        displayName: '现金',
      ),
      ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.category,
        sourceEntityKey: 'category:expense:餐饮',
        displayName: '餐饮',
        categoryKind: ImportCategoryKind.expense,
      ),
    ],
    groups: [
      ImportTransactionGroupDraft(
        topLevel: ImportExpenseDraft(
          amount: const Money(minorUnits: 1200),
          paidFrom: const ImportAccountReference.source(
            sourceEntityKey: 'account:cash',
            displayName: '现金',
          ),
          category: const ImportCategoryReference(
            sourceEntityKey: 'category:expense:餐饮',
            path: '餐饮',
            kind: ImportCategoryKind.expense,
          ),
          occurredAt: DateTime(2026, 7, 22),
        ),
        sourceOperationKey: 'operation-1',
        sourceOperationFingerprint: 'fingerprint-1',
        fingerprintVersion: 1,
      ),
    ],
  );
}

ImportParseResult _planWithDraft(ImportTransactionDraft draft) {
  final base = _plan();
  return base.copyWith(
    groups: [base.groups.single.copyWith(topLevel: draft, children: const [])],
  );
}

ImportPlanReview _review(ImportParseResult plan) {
  return ImportPlanReview(
    plan: plan,
    defaultMappings: const {},
    effectiveMappings: {
      ImportMappingKey(
            source: ImportSource.yimu,
            entityKind: ImportEntityKind.account,
            sourceEntityKey: 'account:cash',
          ):
          'cash',
      ImportMappingKey(
            source: ImportSource.yimu,
            entityKind: ImportEntityKind.category,
            sourceEntityKey: 'category:expense:餐饮',
          ):
          'food',
    },
    suggestions: const [],
    targets: const [
      ImportMappingTarget(
        id: 'cash',
        name: '现金',
        displayPath: '现金',
        kind: ImportMappingTargetKind.asset,
        isArchived: false,
      ),
      ImportMappingTarget(
        id: 'food',
        name: '餐饮',
        displayPath: '餐饮',
        kind: ImportMappingTargetKind.expenseCategory,
        isArchived: false,
      ),
    ],
    groups: [
      ImportGroupReview(
        index: 0,
        group: plan.groups.single,
        issues: const [],
        isExactDuplicate: false,
        isSuspectedDuplicate: false,
      ),
    ],
  );
}

class _FakePicker implements ImportFilePicker {
  const _FakePicker(this.bundle);

  final ImportBundle? bundle;

  @override
  Future<ImportBundle?> pickYimuBundle() async => bundle;
}

class _FakePlanService implements ImportPlanAppService {
  const _FakePlanService(this.plan);

  final ImportParseResult plan;

  @override
  ImportParseResult parse({
    required ImportSource source,
    required ImportBundle bundle,
  }) => plan;

  @override
  ImportParseResult editDraft({
    required ImportParseResult plan,
    required int groupIndex,
    required ImportDraftEdit edit,
    int? childIndex,
  }) => throw UnimplementedError();
}

class _FakeWorkflow implements ImportWorkflowAppService {
  const _FakeWorkflow(this.planReview, {this.batches = const []});

  final ImportPlanReview planReview;
  final List<ImportBatch> batches;

  @override
  Future<ImportPlanReview> review(
    ImportParseResult plan, {
    Map<ImportMappingKey, String> temporaryMappings = const {},
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
  }) async => planReview;

  @override
  Future<void> saveDefaultMapping({
    required ImportSourceEntity entity,
    required String targetAccountId,
  }) async {}

  @override
  Future<ImportCommitResult> commit(ImportCommitCommand command) async =>
      const ImportCommitResult(batch: null, skippedGroupCount: 1);

  @override
  Future<List<ImportBatch>> listBatches({ImportSource? source}) async =>
      batches;

  @override
  Future<List<ImportBatchItem>> findBatchItems(String batchId) async => [];

  @override
  Future<ImportBatch> revertBatch(String batchId, {DateTime? revertedAt}) {
    throw UnimplementedError();
  }
}
