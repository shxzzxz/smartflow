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
  testWidgets('upload dropzone picks files and keeps package actions visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(_plan()),
        picker: _FakePicker(_bundle()),
      ),
    );
    await tester.pump();

    expect(find.text('点击选择文件'), findsOneWidget);
    expect(find.textContaining('XLS 文件请先另存为'), findsOneWidget);
    expect(find.byTooltip('清空'), findsNothing);
    expect(find.byTooltip('添加文件'), findsNothing);
    expect(find.text('解析文件'), findsNothing);
    expect(find.text('共 1 个文件'), findsNothing);

    await tester.tap(find.text('点击选择文件'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('清空'), findsOneWidget);
    expect(find.byTooltip('添加文件'), findsOneWidget);
    expect(find.text('解析文件'), findsOneWidget);
    expect(find.text('共 1 个文件'), findsOneWidget);
    expect(find.byTooltip('移除文件'), findsNothing);

    await tester.tap(find.byTooltip('添加文件'));
    await tester.pumpAndSettle();

    expect(find.text('共 2 个文件'), findsOneWidget);
  });

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
    expect(find.text('共 1 个文件'), findsOneWidget);
  });

  testWidgets('shows status for every file in a multi-file package', (
    tester,
  ) async {
    const transferIssue = ImportIssue(
      code: 'file_decode_failed',
      message: '无法读取一木文件 转账.xls，请重新导出。',
      severity: ImportIssueSeverity.fatal,
      fileType: ImportSourceFileType(
        source: ImportSource.yimu,
        key: 'transfer',
        label: '转账',
      ),
    );
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      fileResults: [
        ImportFileParseResult(
          fileIndex: 0,
          fileName: '账单.xls',
          fileType: const ImportSourceFileType(
            source: ImportSource.yimu,
            key: 'bill',
            label: '账单',
          ),
        ),
        ImportFileParseResult(
          fileIndex: 1,
          fileName: '转账.xls',
          fileType: const ImportSourceFileType(
            source: ImportSource.yimu,
            key: 'transfer',
            label: '转账',
          ),
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
    expect(find.text('共 2 个文件'), findsOneWidget);
    expect(find.text('解析成功'), findsOneWidget);
    expect(find.text('解析失败'), findsOneWidget);
  });

  testWidgets('renders analysis cards without inline mapping or preview data', (
    tester,
  ) async {
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
    expect(find.text('现金'), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('导入预览'), findsOneWidget);
    expect(find.text('映射成功'), findsOneWidget);
    expect(find.text('无法映射'), findsOneWidget);
    expect(find.text('解析成功'), findsWidgets);
    expect(find.text('餐饮'), findsNothing);
    expect(find.text('导入检查与选择'), findsNothing);
    expect(find.text('已过滤来源记录'), findsNothing);
    expect(find.text('导入'), findsOneWidget);
  });

  testWidgets('shows non-fatal parse-unit issues alongside usable results', (
    tester,
  ) async {
    final plan = _plan().copyWith(
      issues: const [
        ImportIssue(
          code: 'parse_unit_companion_file_missing',
          message: '联合解析缺少伴随文件：C。',
          severity: ImportIssueSeverity.blocking,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(plan),
        picker: _FakePicker(_bundle()),
        workflow: _FakeWorkflow(_review(plan)),
      ),
    );

    await _selectAndParse(tester);

    expect(find.text('解析步骤需要注意'), findsOneWidget);
    expect(find.text('联合解析缺少伴随文件：C。'), findsOneWidget);
  });

  testWidgets('shows mapping analysis and opens all mappings as a page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final plan = _mappingPlan();
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(plan),
        picker: _FakePicker(_bundle()),
        workflow: _FakeWorkflow(_mappingReview(plan)),
      ),
    );
    await _selectAndParse(tester);

    expect(find.text('审阅摘要'), findsNothing);
    expect(find.textContaining('应用建议'), findsNothing);
    expect(find.text('新建账户'), findsNothing);
    expect(find.text('新建收入分类'), findsNothing);
    expect(find.text('新建支出分类'), findsNothing);
    for (var index = 1; index <= 6; index++) {
      expect(find.text('来源账户$index'), findsNothing);
    }
    expect(find.text('来源账户6'), findsNothing);
    expect(find.text('保存映射配置'), findsOneWidget);
    expect(find.text('确认配置'), findsOneWidget);

    await tester.tap(find.text('查看全部').first);
    await tester.pumpAndSettle();

    expect(find.text('账户与分类映射'), findsOneWidget);
    expect(find.text('来源账户6'), findsWidgets);
    expect(find.text('映射概览'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '导入'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('确认配置'));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '导入'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('opens all import previews as a page', (tester) async {
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

    await tester.tap(find.text('查看全部').last);
    await tester.pumpAndSettle();

    expect(find.text('导入预览'), findsOneWidget);
    expect(find.text('解析概览'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('解析概览'), findsNothing);
  });

  testWidgets('confirms warning groups from the row details sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final plan = _plan();
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(plan),
        picker: _FakePicker(_bundle()),
        workflow: _FakeWorkflow(_warningReview(plan)),
      ),
    );
    await _selectAndParse(tester);

    await tester.tap(find.text('查看全部').last);
    await tester.pumpAndSettle();

    expect(find.text('有 1 条交易需要确认后才能导入。'), findsOneWidget);
    expect(find.text('需确认'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('已选 0 笔'), findsOneWidget);

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.text('需要确认的原因'), findsOneWidget);
    expect(find.text('请确认这条交易的来源提示。'), findsOneWidget);

    await tester.tap(find.text('确认导入'));
    await tester.pumpAndSettle();

    expect(find.text('解析结果已准备，可查看全部交易预览。'), findsOneWidget);
    expect(find.text('有 1 条交易需要确认后才能导入。'), findsNothing);
    expect(find.text('已选 1 笔'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('excludes transactions in batch selection mode', (tester) async {
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

    await tester.tap(find.text('查看全部').last);
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('已选 1 笔'), findsOneWidget);

    await tester.tap(find.text('排除交易'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('已选 0 笔'), findsOneWidget);
  });

  testWidgets(
    'shows parsing problems and skipped reasons on the issues page',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final plan = _plan().copyWith(
        filteredRecords: const [
          ImportFilteredRecord(
            reasonCode: 'empty_row',
            reason: '空白记录',
            fileType: ImportSourceFileType(
              source: ImportSource.yimu,
              key: 'bill',
              label: '账单',
            ),
            rowNumber: 8,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(
          planService: _FakePlanService(plan),
          picker: _FakePicker(_bundle()),
          workflow: _FakeWorkflow(_blockedReview(plan)),
        ),
      );
      await _selectAndParse(tester);

      expect(find.text('解析详情'), findsNothing);
      await tester.tap(find.text('查看全部').last);
      await tester.pumpAndSettle();

      expect(find.text('解析详情'), findsOneWidget);
      expect(find.text('无法解析 1 · 已跳过 1'), findsOneWidget);
      expect(find.textContaining('来源账户缺失，无法生成交易。'), findsNothing);

      await tester.tap(find.text('解析详情'));
      await tester.pumpAndSettle();

      expect(find.text('无法解析 (1)'), findsOneWidget);
      expect(find.textContaining('来源账户缺失，无法生成交易。'), findsOneWidget);
      expect(find.text('已跳过记录 (1)'), findsOneWidget);
      expect(find.text('账单文件 · 第 8 行'), findsOneWidget);
      expect(find.text('空白记录'), findsOneWidget);

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.textContaining('来源账户缺失，无法生成交易。'), findsNothing);
    },
  );

  testWidgets('collapses missing accounts into a single no-account mapping', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _plan();
    const missing1 = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: 'review:missing:account:bill:2:account',
      displayName: '缺失账户（账单文件第 2 行）',
      isReviewPlaceholder: true,
    );
    const missing2 = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: 'review:missing:account:transfer:3:from',
      displayName: '缺失转出账户（转账文件第 3 行）',
      isReviewPlaceholder: true,
    );
    const missingCategory = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.category,
      sourceEntityKey: 'review:missing:category:income:2',
      displayName: '缺失收入分类（账单文件第 2 行）',
      categoryKind: ImportCategoryKind.income,
      isReviewPlaceholder: true,
    );
    const missingReceivable = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: 'review:missing:account:reimbursement:4:receivable',
      displayName: '缺失报销应收账户（报销文件第 4 行）',
      isReviewPlaceholder: true,
    );
    final plan = base.copyWith(
      sourceEntities: const [
        missing1,
        missing2,
        missingCategory,
        missingReceivable,
      ],
    );
    final categoryKey = ImportMappingKey.fromEntity(missingCategory);
    final review = ImportPlanReview(
      plan: plan,
      defaultMappings: const {},
      effectiveMappings: {
        ImportMappingKey.fromEntity(missing1): 'ghost',
        ImportMappingKey.fromEntity(missing2): 'ghost',
      },
      suggestions: const [],
      plannedCreations: {
        categoryKey: const ImportMappingCreation(
          name: '缺失收入分类（账单文件第 2 行）',
          kind: ImportMappingTargetKind.incomeCategory,
        ),
      },
      targets: const [
        ImportMappingTarget(
          id: 'ghost',
          name: '幽灵账户',
          displayPath: '幽灵账户',
          kind: ImportMappingTargetKind.ghost,
          isArchived: false,
        ),
      ],
      mappingItems: [
        ImportMappingReviewItem(
          key: ImportMappingKey.fromEntity(missing1),
          sourceName: '缺失账户',
          sourceDescription: '账户',
          action: ImportMappingAction.map,
          targetName: '无账户',
          targetId: 'ghost',
          targetPath: '无账户',
          targetDescription: '无账户',
          decision: const ExistingTargetDecision('ghost'),
        ),
        ImportMappingReviewItem(
          key: ImportMappingKey.fromEntity(missingCategory),
          sourceName: missingCategory.displayName,
          sourceDescription: '收入分类',
          action: ImportMappingAction.create,
          targetName: missingCategory.displayName,
          targetPath: missingCategory.displayName,
          targetDescription: '收入分类',
          creationOptions: [
            const ImportMappingCreation(
              name: '缺失收入分类（账单文件第 2 行）',
              kind: ImportMappingTargetKind.incomeCategory,
            ),
          ],
          decision: const PlannedCreationDecision(
            ImportMappingCreation(
              name: '缺失收入分类（账单文件第 2 行）',
              kind: ImportMappingTargetKind.incomeCategory,
            ),
          ),
        ),
        ImportMappingReviewItem(
          key: ImportMappingKey.fromEntity(missingReceivable),
          sourceName: missingReceivable.displayName,
          sourceDescription: '账户',
          action: ImportMappingAction.unresolved,
          targetName: '待配置',
          decision: const UnresolvedDecision('当前映射尚未完成。'),
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
    await tester.pumpWidget(
      _app(
        planService: _FakePlanService(plan),
        picker: _FakePicker(_bundle()),
        workflow: _FakeWorkflow(review),
      ),
    );
    await _selectAndParse(tester);

    expect(find.text('缺失账户'), findsNothing);
    expect(find.text('无账户'), findsNothing);
    expect(find.text(missing1.displayName), findsNothing);
    expect(find.text(missing2.displayName), findsNothing);
    expect(find.text('幽灵账户'), findsNothing);
    await tester.tap(find.text('查看全部').first);
    await tester.pumpAndSettle();

    expect(find.text('缺失账户'), findsOneWidget);
    expect(find.text('无账户'), findsOneWidget);
    expect(find.text('缺失收入分类（账单文件第 2 行）'), findsWidgets);
    final semanticLabels =
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .map((widget) => widget.properties.label)
            .whereType<String>();
    expect(
      semanticLabels,
      contains('缺失收入分类（账单文件第 2 行），导入时新建 缺失收入分类（账单文件第 2 行）'),
    );
    expect(find.text(missingReceivable.displayName), findsWidgets);
    expect(semanticLabels, contains('缺失报销应收账户（报销文件第 4 行），映射到 待配置'));
  });

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
  await tester.tap(find.text('点击选择文件'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('解析文件'));
  await tester.pumpAndSettle();
}

ImportParseResult _mappingPlan() {
  final base = _plan();
  return base.copyWith(
    sourceEntities: [
      for (var index = 1; index <= 6; index++)
        ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.account,
          sourceEntityKey: 'account:source-$index',
          displayName: '来源账户$index',
        ),
    ],
  );
}

ImportPlanReview _mappingReview(ImportParseResult plan) {
  const firstKey = ImportMappingKey(
    source: ImportSource.yimu,
    entityKind: ImportEntityKind.account,
    sourceEntityKey: 'account:source-1',
  );
  return ImportPlanReview(
    plan: plan,
    defaultMappings: {firstKey: 'cash'},
    effectiveMappings: {firstKey: 'cash'},
    suggestions: const [],
    plannedCreations: {
      for (var index = 2; index <= 6; index++)
        ImportMappingKey(
          source: ImportSource.yimu,
          entityKind: ImportEntityKind.account,
          sourceEntityKey: 'account:source-$index',
        ): ImportMappingCreation(
          name: '来源账户$index',
          kind: ImportMappingTargetKind.asset,
        ),
    },
    targets: const [
      ImportMappingTarget(
        id: 'cash',
        name: '现金',
        displayPath: '现金',
        kind: ImportMappingTargetKind.asset,
        isArchived: false,
      ),
    ],
    mappingItems: [
      ImportMappingReviewItem(
        key: firstKey,
        sourceName: '来源账户1',
        sourceDescription: '账户',
        action: ImportMappingAction.map,
        targetName: '现金',
        targetId: 'cash',
        targetPath: '现金',
        targetDescription: '资金账户',
        decision: const ExistingTargetDecision('cash'),
      ),
      for (var index = 2; index <= 6; index++)
        ImportMappingReviewItem(
          key: ImportMappingKey(
            source: ImportSource.yimu,
            entityKind: ImportEntityKind.account,
            sourceEntityKey: 'account:source-$index',
          ),
          sourceName: '来源账户$index',
          sourceDescription: '账户',
          action: ImportMappingAction.create,
          targetName: '来源账户$index',
          targetPath: '来源账户$index',
          targetDescription: '资金账户',
          creationOptions: [
            ImportMappingCreation(
              name: '来源账户$index',
              kind: ImportMappingTargetKind.asset,
            ),
          ],
          decision: PlannedCreationDecision(
            ImportMappingCreation(
              name: '来源账户$index',
              kind: ImportMappingTargetKind.asset,
            ),
          ),
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
        fileType: const ImportSourceFileType(
          source: ImportSource.yimu,
          key: 'bill',
          label: '账单',
        ),
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
    mappingItems: [
      ImportMappingReviewItem(
        key: const ImportMappingKey(
          source: ImportSource.yimu,
          entityKind: ImportEntityKind.account,
          sourceEntityKey: 'account:cash',
        ),
        sourceName: '现金',
        sourceDescription: '账户',
        action: ImportMappingAction.map,
        targetName: '现金',
        targetId: 'cash',
        targetPath: '现金',
        targetDescription: '资金账户',
        decision: const ExistingTargetDecision('cash'),
      ),
      ImportMappingReviewItem(
        key: const ImportMappingKey(
          source: ImportSource.yimu,
          entityKind: ImportEntityKind.category,
          sourceEntityKey: 'category:expense:餐饮',
        ),
        sourceName: '餐饮',
        sourceDescription: '支出分类',
        action: ImportMappingAction.map,
        targetName: '餐饮',
        targetId: 'food',
        targetPath: '餐饮',
        targetDescription: '支出分类',
        decision: const ExistingTargetDecision('food'),
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

ImportPlanReview _warningReview(ImportParseResult plan) {
  final base = _review(plan);
  return ImportPlanReview(
    plan: plan,
    defaultMappings: base.defaultMappings,
    effectiveMappings: base.effectiveMappings,
    suggestions: base.suggestions,
    targets: base.targets,
    mappingItems: base.mappingItems,
    groups: [
      ImportGroupReview(
        index: 0,
        group: plan.groups.single,
        issues: const [
          ImportIssue(
            code: 'warning',
            message: '请确认这条交易的来源提示。',
            severity: ImportIssueSeverity.warning,
          ),
        ],
        isExactDuplicate: false,
        isSuspectedDuplicate: false,
      ),
    ],
  );
}

ImportPlanReview _blockedReview(ImportParseResult plan) {
  final base = _review(plan);
  return ImportPlanReview(
    plan: plan,
    defaultMappings: base.defaultMappings,
    effectiveMappings: base.effectiveMappings,
    suggestions: base.suggestions,
    targets: base.targets,
    mappingItems: base.mappingItems,
    groups: [
      ImportGroupReview(
        index: 0,
        group: plan.groups.single,
        issues: const [
          ImportIssue(
            code: 'missing_account',
            message: '来源账户缺失，无法生成交易。',
            severity: ImportIssueSeverity.blocking,
            fileType: ImportSourceFileType(
              source: ImportSource.yimu,
              key: 'bill',
              label: '账单',
            ),
            rowNumber: 3,
          ),
        ],
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
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
  }) async {
    final resolvedCreations = <ImportMappingKey, ImportMappingCreation>{
      ...planReview.plannedCreations,
      ...plannedCreations,
    };
    final effectiveMappings = <ImportMappingKey, String>{
      ...planReview.effectiveMappings,
      ...temporaryMappings,
    }..removeWhere((key, _) => resolvedCreations.containsKey(key));
    return ImportPlanReview(
      plan: plan,
      defaultMappings: planReview.defaultMappings,
      effectiveMappings: effectiveMappings,
      suggestions: planReview.suggestions,
      plannedCreations: resolvedCreations,
      targets: planReview.targets,
      compatibleTargetKinds: planReview.compatibleTargetKinds,
      groupMappingOverrides: groupMappingOverrides,
      mappingItems: planReview.mappingItems,
      groups: [
        for (final group in planReview.groups)
          ImportGroupReview(
            index: group.index,
            group: plan.groups[group.index],
            issues: group.issues,
            isExactDuplicate: group.isExactDuplicate,
            isSuspectedDuplicate: group.isSuspectedDuplicate,
            effectiveMappings: effectiveMappings,
            compatibleTargetKinds: group.compatibleTargetKinds,
          ),
      ],
    );
  }

  @override
  Future<ImportCommitResult> commit(ImportCommitCommand command) async =>
      ImportCommitResult(batch: null, skippedGroupCount: 1);

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
