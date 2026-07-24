import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/import/import_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/import/import_models.dart'
    show applyImportDraftEdit;
import 'package:smartflow/feature/import/view_model/import_view_model.dart';

void main() {
  group('ImportViewModel', () {
    test(
      'automatically matches known targets and plans unmatched targets',
      () async {
        final base = _plan(groupCount: 1);
        const categoryEntity = ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.category,
          sourceEntityKey: 'category:expense:new-food',
          displayName: '新餐饮',
          categoryKind: ImportCategoryKind.expense,
        );
        final plan = base.copyWith(
          sourceEntities: [...base.sourceEntities, categoryEntity],
        );
        const categoryKey = ImportMappingKey(
          source: ImportSource.yimu,
          entityKind: ImportEntityKind.category,
          sourceEntityKey: 'category:expense:new-food',
        );
        final workflow = _FakeImportWorkflowAppService(
          reviewBuilder: (
            reviewPlan,
            temporaryMappings,
            plannedCreations,
            groupMappingOverrides,
          ) {
            final effectiveMappings = <ImportMappingKey, String>{
              ...temporaryMappings,
              if (!temporaryMappings.containsKey(_mappingKey))
                _mappingKey: 'cash',
            };
            final resolvedCreations = <ImportMappingKey, ImportMappingCreation>{
              ...plannedCreations,
              if (!plannedCreations.containsKey(categoryKey))
                categoryKey: const ImportMappingCreation(
                  name: '新餐饮',
                  kind: ImportMappingTargetKind.expenseCategory,
                ),
            };
            return _review(
              reviewPlan,
              temporaryMappings: temporaryMappings,
              effectiveMappings: effectiveMappings,
              plannedCreations: resolvedCreations,
              suggestions:
                  temporaryMappings.containsKey(_mappingKey)
                      ? const []
                      : const [
                        ImportMappingSuggestion(
                          key: _mappingKey,
                          targetAccountId: 'cash',
                        ),
                      ],
              groups: [
                ImportGroupReview(
                  index: 0,
                  group: reviewPlan.groups.single,
                  issues: const [],
                  isExactDuplicate: false,
                  isSuspectedDuplicate: false,
                ),
              ],
            );
          },
        );
        final container = _container(
          planService: _FakeImportPlanAppService(plan),
          workflow: workflow,
          picker: _FakeImportFilePicker(_bundle()),
        );

        final viewModel = container.read(importViewModelProvider.notifier);
        await viewModel.pickFiles();
        await viewModel.parseSelectedFiles();

        final state = container.read(importViewModelProvider);
        expect(state.review?.effectiveMappings[_mappingKey], 'cash');
        expect(
          state.plannedCreations[categoryKey]?.kind,
          ImportMappingTargetKind.expenseCategory,
        );
        expect(workflow.reviewCalls, 1);
      },
    );

    test(
      'confirms mapping configuration and saves it with the import',
      () async {
        final plan = _plan(groupCount: 1);
        final workflow = _FakeImportWorkflowAppService(
          reviewBuilder:
              (
                reviewPlan,
                temporaryMappings,
                plannedCreations,
                groupMappingOverrides,
              ) => _review(
                reviewPlan,
                temporaryMappings: temporaryMappings,
                plannedCreations:
                    plannedCreations.isEmpty
                        ? {
                          _mappingKey: ImportMappingCreation(
                            name: '现金',
                            kind: ImportMappingTargetKind.asset,
                          ),
                        }
                        : plannedCreations,
                groups: [
                  ImportGroupReview(
                    index: 0,
                    group: reviewPlan.groups.single,
                    issues: const [],
                    isExactDuplicate: false,
                    isSuspectedDuplicate: false,
                  ),
                ],
              ),
        );
        final container = _container(
          planService: _FakeImportPlanAppService(plan),
          workflow: workflow,
          picker: _FakeImportFilePicker(_bundle()),
        );
        final viewModel = container.read(importViewModelProvider.notifier);
        await viewModel.pickFiles();
        await viewModel.parseSelectedFiles();

        viewModel.toggleSaveMappingConfiguration();
        expect(
          container.read(importViewModelProvider).saveMappingConfiguration,
          isTrue,
        );
        viewModel.toggleSaveMappingConfiguration();
        expect(
          container.read(importViewModelProvider).saveMappingConfiguration,
          isFalse,
        );
        viewModel.toggleSaveMappingConfiguration();
        final confirmation = viewModel.confirmMappingConfiguration();

        expect(confirmation, isA<ImportActionSuccess<void>>());
        expect(
          container.read(importViewModelProvider).mappingConfirmed,
          isTrue,
        );
        expect(
          container.read(importViewModelProvider).saveMappingConfiguration,
          isTrue,
        );

        await viewModel.commitSelectedGroups();

        final command = workflow.commitCommands.single;
        expect(command.saveMappingConfiguration, isTrue);
        expect(command.plannedCreations, contains(_mappingKey));
      },
    );

    test(
      'requires mapping confirmation again after a mapping override',
      () async {
        final plan = _plan(groupCount: 1);
        final workflow = _FakeImportWorkflowAppService(
          reviewBuilder:
              (
                reviewPlan,
                temporaryMappings,
                plannedCreations,
                groupMappingOverrides,
              ) => _review(
                reviewPlan,
                temporaryMappings: {
                  ...temporaryMappings,
                  ...?groupMappingOverrides[0],
                },
                plannedCreations:
                    plannedCreations.isEmpty && temporaryMappings.isEmpty
                        ? {
                          _mappingKey: ImportMappingCreation(
                            name: '现金',
                            kind: ImportMappingTargetKind.asset,
                          ),
                        }
                        : plannedCreations,
                groups: [
                  ImportGroupReview(
                    index: 0,
                    group: reviewPlan.groups.single,
                    issues: const [],
                    isExactDuplicate: false,
                    isSuspectedDuplicate: false,
                  ),
                ],
              ),
        );
        final container = _container(
          planService: _FakeImportPlanAppService(plan),
          workflow: workflow,
          picker: _FakeImportFilePicker(_bundle()),
        );
        final viewModel = container.read(importViewModelProvider.notifier);
        await viewModel.pickFiles();
        await viewModel.parseSelectedFiles();
        expect(
          viewModel.confirmMappingConfiguration(),
          isA<ImportActionSuccess<void>>(),
        );
        expect(
          container.read(importViewModelProvider).mappingConfirmed,
          isTrue,
        );

        final outcome = await viewModel.setMapping(_mappingKey, 'cash');

        expect(outcome, isA<ImportActionSuccess<void>>());
        expect(
          container.read(importViewModelProvider).mappingConfirmed,
          isFalse,
        );
        expect(
          container.read(importViewModelProvider).saveMappingConfiguration,
          isFalse,
        );

        expect(
          viewModel.confirmMappingConfiguration(),
          isA<ImportActionSuccess<void>>(),
        );
        await viewModel.setGroupMappingOverride(
          groupIndex: 0,
          key: _mappingKey,
          targetAccountId: 'cash',
        );
        expect(
          container.read(importViewModelProvider).mappingConfirmed,
          isFalse,
        );
      },
    );

    test('does not commit before mapping configuration is confirmed', () async {
      final plan = _plan(groupCount: 1);
      final workflow = _FakeImportWorkflowAppService(
        reviewBuilder:
            (reviewPlan, temporaryMappings, plannedCreations, groupOverrides) =>
                _review(
                  reviewPlan,
                  temporaryMappings: temporaryMappings,
                  effectiveMappings: {
                    _mappingKey: 'cash',
                    ...temporaryMappings,
                  },
                  plannedCreations: plannedCreations,
                  groups: [
                    ImportGroupReview(
                      index: 0,
                      group: reviewPlan.groups.single,
                      issues: const [],
                      isExactDuplicate: false,
                      isSuspectedDuplicate: false,
                    ),
                  ],
                ),
      );
      final container = _container(
        planService: _FakeImportPlanAppService(plan),
        workflow: workflow,
        picker: _FakeImportFilePicker(_bundle()),
      );
      final viewModel = container.read(importViewModelProvider.notifier);
      await viewModel.pickFiles();
      await viewModel.parseSelectedFiles();

      final outcome = await viewModel.commitSelectedGroups();

      expect(outcome, isA<ImportActionFailure<ImportCommitResult>>());
      expect(workflow.commitCommands, isEmpty);
    });

    test(
      'loads a bundle and selects only importable transaction groups',
      () async {
        final plan = _plan();
        final planService = _FakeImportPlanAppService(plan);
        final workflow = _FakeImportWorkflowAppService(
          reviewBuilder:
              (
                reviewPlan,
                temporaryMappings,
                plannedCreations,
                groupMappingOverrides,
              ) => _review(
                reviewPlan,
                temporaryMappings: temporaryMappings,
                effectiveMappings: {_mappingKey: 'cash', ...temporaryMappings},
                plannedCreations: plannedCreations,
                groups: [
                  ImportGroupReview(
                    index: 0,
                    group: plan.groups[0],
                    issues: const [],
                    isExactDuplicate: false,
                    isSuspectedDuplicate: false,
                  ),
                  ImportGroupReview(
                    index: 1,
                    group: plan.groups[1],
                    issues: const [],
                    isExactDuplicate: true,
                    isSuspectedDuplicate: false,
                  ),
                  ImportGroupReview(
                    index: 2,
                    group: plan.groups[2],
                    issues: const [
                      ImportIssue(
                        code: 'account_missing',
                        message: '来源账户为空。',
                        severity: ImportIssueSeverity.blocking,
                      ),
                    ],
                    isExactDuplicate: false,
                    isSuspectedDuplicate: false,
                  ),
                ],
              ),
        );
        final container = _container(
          planService: planService,
          workflow: workflow,
          picker: _FakeImportFilePicker(_bundle()),
        );

        final pickOutcome =
            await container.read(importViewModelProvider.notifier).pickFiles();

        expect(pickOutcome, isA<ImportActionSuccess<void>>());
        expect(
          container.read(importViewModelProvider).phase,
          ImportPagePhase.idle,
        );
        expect(
          container.read(importViewModelProvider).selectedBundle?.files,
          hasLength(1),
        );
        expect(
          container.read(importViewModelProvider).fileProgress.single.status,
          ImportFileProcessingStatus.waiting,
        );
        expect(planService.parseCalls, 0);

        final parseOutcome =
            await container
                .read(importViewModelProvider.notifier)
                .parseSelectedFiles();

        expect(parseOutcome, isA<ImportActionSuccess<void>>());
        final state = container.read(importViewModelProvider);
        expect(state.phase, ImportPagePhase.review);
        expect(state.review?.plan, same(plan));
        expect(state.selectedGroupIndexes, {0});
        expect(
          state.fileProgress.single.status,
          ImportFileProcessingStatus.success,
        );
        expect(planService.parseCalls, 1);
      },
    );

    test('marks every selected file failed when parsing throws', () async {
      final container = _container(
        planService: _FakeImportPlanAppService(
          _plan(groupCount: 1),
          throwOnParse: true,
        ),
        workflow: _FakeImportWorkflowAppService(
          reviewBuilder:
              (_, _, _, _) => throw StateError('review should not be called'),
        ),
        picker: _FakeImportFilePicker(_bundle()),
      );
      final viewModel = container.read(importViewModelProvider.notifier);
      await viewModel.pickFiles();

      final outcome = await viewModel.parseSelectedFiles();

      expect(outcome, isA<ImportActionFailure<void>>());
      final state = container.read(importViewModelProvider);
      expect(state.phase, ImportPagePhase.idle);
      expect(
        state.fileProgress.single.status,
        ImportFileProcessingStatus.failed,
      );
      expect(state.fileProgress.single.detail, isNotEmpty);
    });

    test(
      'uses a unique match automatically and commits a confirmed duplicate',
      () async {
        final plan = _plan(groupCount: 1);
        final workflow = _FakeImportWorkflowAppService(
          reviewBuilder:
              (
                reviewPlan,
                temporaryMappings,
                plannedCreations,
                groupMappingOverrides,
              ) => _review(
                reviewPlan,
                temporaryMappings: temporaryMappings,
                effectiveMappings: {_mappingKey: 'cash', ...temporaryMappings},
                plannedCreations: plannedCreations,
                suggestions:
                    temporaryMappings.isEmpty
                        ? [
                          const ImportMappingSuggestion(
                            key: _mappingKey,
                            targetAccountId: 'cash',
                          ),
                        ]
                        : const [],
                groups: [
                  ImportGroupReview(
                    index: 0,
                    group: plan.groups[0],
                    issues: const [],
                    isExactDuplicate: false,
                    isSuspectedDuplicate: true,
                  ),
                ],
              ),
          commitResult: ImportCommitResult(
            batch: ImportBatch(
              id: 'batch-1',
              source: ImportSource.yimu,
              status: ImportBatchStatus.imported,
              importedGroupCount: 1,
              createdTransactionCount: 1,
              skippedGroupCount: 0,
              importedAt: DateTime(2026, 7, 22),
            ),
            skippedGroupCount: 0,
          ),
        );
        final container = _container(
          planService: _FakeImportPlanAppService(plan),
          workflow: workflow,
          picker: _FakeImportFilePicker(_bundle()),
        );
        final viewModel = container.read(importViewModelProvider.notifier);
        await viewModel.pickFiles();
        await viewModel.parseSelectedFiles();

        viewModel.setSuspectedDuplicateConfirmed(0, true);
        expect(
          viewModel.confirmMappingConfiguration(),
          isA<ImportActionSuccess<void>>(),
        );
        final outcome = await viewModel.commitSelectedGroups();

        expect(outcome, isA<ImportActionSuccess<ImportCommitResult>>());
        final command = workflow.commitCommands.single;
        expect(command.mappings[_mappingKey], 'cash');
        expect(command.selectedGroupIndexes, {0});
        expect(command.confirmedSuspectedDuplicateIndexes, {0});
        expect(
          container.read(importViewModelProvider).lastCommit?.batch?.id,
          'batch-1',
        );
      },
    );

    test('edits review-safe draft fields and keeps source identity', () async {
      final plan = _plan(groupCount: 1);
      final originalGroup = plan.groups.single;
      final workflow = _FakeImportWorkflowAppService(
        reviewBuilder: (
          reviewPlan,
          temporaryMappings,
          plannedCreations,
          groupOverrides,
        ) {
          final effective = <ImportMappingKey, String>{
            ...temporaryMappings,
            ...?groupOverrides[0],
          };
          return ImportPlanReview(
            plan: reviewPlan,
            defaultMappings: const {},
            effectiveMappings: effective,
            suggestions: const [],
            plannedCreations: plannedCreations,
            groupMappingOverrides: groupOverrides,
            groups: [
              ImportGroupReview(
                index: 0,
                group: reviewPlan.groups.single,
                issues: const [],
                isExactDuplicate: false,
                isSuspectedDuplicate: false,
                effectiveMappings: effective,
              ),
            ],
          );
        },
      );
      final container = _container(
        planService: _FakeImportPlanAppService(plan),
        workflow: workflow,
        picker: _FakeImportFilePicker(_bundle()),
      );
      final viewModel = container.read(importViewModelProvider.notifier);
      await viewModel.pickFiles();
      await viewModel.parseSelectedFiles();

      await viewModel.editGroupDraft(
        groupIndex: 0,
        edit: ImportDraftEdit(
          amount: Money.parse('25'),
          occurredAt: DateTime(2026, 7, 21, 9),
          postedAt: DateTime(2026, 7, 22, 10),
          note: const Patch.set('审阅修正'),
        ),
      );
      await viewModel.setGroupMappingOverride(
        groupIndex: 0,
        key: _mappingKey,
        targetAccountId: 'cash-override',
      );
      expect(
        viewModel.confirmMappingConfiguration(),
        isA<ImportActionSuccess<void>>(),
      );
      await viewModel.commitSelectedGroups();

      final edited =
          container.read(importViewModelProvider).review!.plan.groups.single;
      final draft = edited.topLevel as ImportTransferDraft;
      expect(draft.amount, Money.parse('25'));
      expect(draft.occurredAt, DateTime(2026, 7, 21, 9));
      expect(draft.postedAt, DateTime(2026, 7, 22, 10));
      expect(draft.note, '审阅修正');
      expect(
        edited.sourceOperationFingerprint,
        originalGroup.sourceOperationFingerprint,
      );
      expect(edited.sourceOperationKey, originalGroup.sourceOperationKey);
      expect(workflow.commitCommands.single.groupMappingOverrides[0], {
        _mappingKey: 'cash-override',
      });
    });

    test('requires explicit confirmation for ordinary warnings', () async {
      final base = _plan(groupCount: 1);
      final warningGroup = base.groups.single.copyWith(
        issues: const [
          ImportIssue(
            code: 'review_warning',
            message: '请确认解析结果。',
            severity: ImportIssueSeverity.warning,
          ),
        ],
      );
      final plan = base.copyWith(groups: [warningGroup]);
      final workflow = _FakeImportWorkflowAppService(
        reviewBuilder:
            (reviewPlan, temporaryMappings, plannedCreations, groupOverrides) =>
                ImportPlanReview(
                  plan: reviewPlan,
                  defaultMappings: const {},
                  effectiveMappings: {
                    _mappingKey: 'cash',
                    ...temporaryMappings,
                  },
                  suggestions: const [],
                  plannedCreations: plannedCreations,
                  groups: [
                    ImportGroupReview(
                      index: 0,
                      group: reviewPlan.groups.single,
                      issues: reviewPlan.groups.single.issues,
                      isExactDuplicate: false,
                      isSuspectedDuplicate: false,
                    ),
                  ],
                ),
      );
      final container = _container(
        planService: _FakeImportPlanAppService(plan),
        workflow: workflow,
        picker: _FakeImportFilePicker(_bundle()),
      );
      final viewModel = container.read(importViewModelProvider.notifier);
      await viewModel.pickFiles();
      await viewModel.parseSelectedFiles();

      expect(
        container.read(importViewModelProvider).selectedGroupIndexes,
        isEmpty,
      );
      viewModel.setWarningConfirmed(0, true);
      expect(
        viewModel.confirmMappingConfiguration(),
        isA<ImportActionSuccess<void>>(),
      );
      await viewModel.commitSelectedGroups();

      expect(workflow.commitCommands.single.confirmedWarningIndexes, {0});
      expect(workflow.commitCommands.single.selectedGroupIndexes, {0});
    });
  });
}

ProviderContainer _container({
  required ImportPlanAppService planService,
  required ImportWorkflowAppService workflow,
  required ImportFilePicker picker,
}) {
  final container = ProviderContainer(
    overrides: [
      importPlanAppServiceProvider.overrideWithValue(planService),
      importWorkflowAppServiceProvider.overrideWithValue(workflow),
      importFilePickerProvider.overrideWithValue(picker),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ImportBundle _bundle() {
  return ImportBundle(
    files: [
      ImportFilePayload(name: '账单.xls', bytes: Uint8List.fromList([1])),
    ],
  );
}

ImportParseResult _plan({int groupCount = 3}) {
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
    ],
    groups: [
      for (var index = 0; index < groupCount; index++)
        ImportTransactionGroupDraft(
          topLevel: ImportTransferDraft(
            amount: const Money(minorUnits: 1000),
            fromAccount: const ImportAccountReference.source(
              sourceEntityKey: 'account:cash',
              displayName: '现金',
            ),
            toAccount: const ImportAccountReference.source(
              sourceEntityKey: 'account:cash',
              displayName: '现金',
            ),
            occurredAt: DateTime(2026, 7, 20),
          ),
          sourceOperationKey: 'operation-$index',
          sourceOperationFingerprint: 'fingerprint-$index',
          fingerprintVersion: 1,
        ),
    ],
  );
}

ImportPlanReview _review(
  ImportParseResult plan, {
  required Map<ImportMappingKey, String> temporaryMappings,
  Map<ImportMappingKey, String>? effectiveMappings,
  Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
  required List<ImportGroupReview> groups,
  List<ImportMappingSuggestion> suggestions = const [],
}) {
  return ImportPlanReview(
    plan: plan,
    defaultMappings: const {},
    effectiveMappings: effectiveMappings ?? temporaryMappings,
    suggestions: suggestions,
    plannedCreations: plannedCreations,
    targets: const [
      ImportMappingTarget(
        id: 'cash',
        name: '现金',
        displayPath: '现金',
        kind: ImportMappingTargetKind.asset,
        isArchived: false,
      ),
    ],
    groups: groups,
  );
}

const _mappingKey = ImportMappingKey(
  source: ImportSource.yimu,
  entityKind: ImportEntityKind.account,
  sourceEntityKey: 'account:cash',
);

class _FakeImportFilePicker implements ImportFilePicker {
  const _FakeImportFilePicker(this.bundle);

  final ImportBundle? bundle;

  @override
  Future<ImportBundle?> pickYimuBundle() async => bundle;
}

class _FakeImportPlanAppService implements ImportPlanAppService {
  _FakeImportPlanAppService(this.plan, {this.throwOnParse = false});

  final ImportParseResult plan;
  final bool throwOnParse;
  int parseCalls = 0;

  @override
  ImportParseResult parse({
    required ImportSource source,
    required ImportBundle bundle,
  }) {
    parseCalls += 1;
    if (throwOnParse) throw Exception('parse failed');
    return plan;
  }

  @override
  ImportParseResult editDraft({
    required ImportParseResult plan,
    required int groupIndex,
    required ImportDraftEdit edit,
    int? childIndex,
  }) {
    final group = plan.groups[groupIndex];
    final children = [...group.children];
    final topLevel =
        childIndex == null
            ? applyImportDraftEdit(group.topLevel, edit)
            : group.topLevel;
    if (childIndex != null) {
      children[childIndex] = applyImportDraftEdit(children[childIndex], edit);
    }
    final groups = [...plan.groups];
    groups[groupIndex] = group.copyWith(topLevel: topLevel, children: children);
    return plan.copyWith(groups: groups);
  }
}

class _FakeImportWorkflowAppService implements ImportWorkflowAppService {
  _FakeImportWorkflowAppService({
    required this.reviewBuilder,
    ImportCommitResult? commitResult,
  }) : commitResult =
           commitResult ??
           ImportCommitResult(batch: null, skippedGroupCount: 0);

  final ImportPlanReview Function(
    ImportParseResult plan,
    Map<ImportMappingKey, String> temporaryMappings,
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations,
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides,
  )
  reviewBuilder;
  final ImportCommitResult commitResult;
  final List<ImportCommitCommand> commitCommands = [];
  int reviewCalls = 0;

  @override
  Future<ImportPlanReview> review(
    ImportParseResult plan, {
    Map<ImportMappingKey, String> temporaryMappings = const {},
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
  }) async {
    reviewCalls += 1;
    return reviewBuilder(
      plan,
      temporaryMappings,
      plannedCreations,
      groupMappingOverrides,
    );
  }

  @override
  Future<ImportCommitResult> commit(ImportCommitCommand command) async {
    commitCommands.add(command);
    return commitResult;
  }

  @override
  Future<List<ImportBatch>> listBatches({ImportSource? source}) async => [];

  @override
  Future<List<ImportBatchItem>> findBatchItems(String batchId) async => [];

  @override
  Future<ImportBatch> revertBatch(String batchId, {DateTime? revertedAt}) {
    throw UnimplementedError();
  }
}
