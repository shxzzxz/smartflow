import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/provider.dart';
import '../../../application/import/import_api.dart';
import '../../../core/error/app_exception.dart';
import '../../shared/view_model/ui_action_outcome.dart';

enum ImportPagePhase {
  idle,
  pickingFiles,
  parsing,
  reviewing,
  review,
  committing,
}

enum ImportFileProcessingStatus { waiting, parsing, success, warning, failed }

class ImportFileProgress {
  const ImportFileProgress({
    required this.fileIndex,
    required this.status,
    this.detail,
  });

  final int fileIndex;
  final ImportFileProcessingStatus status;
  final String? detail;
}

class ImportPageState {
  ImportPageState({
    required this.phase,
    required List<ImportFileProgress> fileProgress,
    required Map<ImportMappingKey, String> temporaryMappings,
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
    required Map<int, Map<ImportMappingKey, String>> groupMappingOverrides,
    required Set<int> selectedGroupIndexes,
    required Set<int> confirmedSuspectedDuplicateIndexes,
    required Set<int> confirmedWarningIndexes,
    required List<ImportBatch> batches,
    required this.historyLoading,
    this.mappingConfirmed = false,
    this.saveMappingConfiguration = false,
    this.selectedBundle,
    this.plan,
    this.review,
    this.error,
    this.lastCommit,
    this.revertingBatchId,
  }) : fileProgress = List.unmodifiable(fileProgress),
       temporaryMappings = Map.unmodifiable(temporaryMappings),
       plannedCreations = Map.unmodifiable(plannedCreations),
       groupMappingOverrides =
           Map<int, Map<ImportMappingKey, String>>.unmodifiable({
             for (final entry in groupMappingOverrides.entries)
               entry.key: Map<ImportMappingKey, String>.unmodifiable(
                 entry.value,
               ),
           }),
       selectedGroupIndexes = Set.unmodifiable(selectedGroupIndexes),
       confirmedSuspectedDuplicateIndexes = Set.unmodifiable(
         confirmedSuspectedDuplicateIndexes,
       ),
       confirmedWarningIndexes = Set.unmodifiable(confirmedWarningIndexes),
       batches = List.unmodifiable(batches);

  factory ImportPageState.initial() {
    return ImportPageState(
      phase: ImportPagePhase.idle,
      fileProgress: const [],
      temporaryMappings: const {},
      plannedCreations: const {},
      groupMappingOverrides: const {},
      selectedGroupIndexes: const {},
      confirmedSuspectedDuplicateIndexes: const {},
      confirmedWarningIndexes: const {},
      batches: const [],
      historyLoading: false,
      mappingConfirmed: false,
      saveMappingConfiguration: false,
    );
  }

  final ImportPagePhase phase;
  final ImportBundle? selectedBundle;
  final List<ImportFileProgress> fileProgress;
  final ImportParseResult? plan;
  final ImportPlanReview? review;
  final Map<ImportMappingKey, String> temporaryMappings;
  final Map<ImportMappingKey, ImportMappingCreation> plannedCreations;
  final Map<int, Map<ImportMappingKey, String>> groupMappingOverrides;
  final Set<int> selectedGroupIndexes;
  final Set<int> confirmedSuspectedDuplicateIndexes;
  final Set<int> confirmedWarningIndexes;
  final List<ImportBatch> batches;
  final bool historyLoading;
  final bool mappingConfirmed;
  final bool saveMappingConfiguration;
  final UiError? error;
  final ImportCommitResult? lastCommit;
  final String? revertingBatchId;

  bool get isBusy => switch (phase) {
    ImportPagePhase.pickingFiles ||
    ImportPagePhase.parsing ||
    ImportPagePhase.reviewing ||
    ImportPagePhase.committing => true,
    _ => false,
  };

  bool get hasFatalIssues => plan?.hasFatalIssues ?? false;

  ImportFileProgress fileProgressAt(int index) {
    if (index >= 0 && index < fileProgress.length) return fileProgress[index];
    return ImportFileProgress(
      fileIndex: index,
      status: ImportFileProcessingStatus.waiting,
    );
  }

  int get groupCount => review?.groups.length ?? 0;
  int get selectedGroupCount => selectedGroupIndexes.length;
  int get blockedGroupCount =>
      review?.groups.where((group) => group.isBlocked).length ?? 0;
  int get exactDuplicateGroupCount =>
      review?.groups.where((group) => group.isExactDuplicate).length ?? 0;
  int get suspectedDuplicateGroupCount =>
      review?.groups.where((group) => group.isSuspectedDuplicate).length ?? 0;
  int get filteredRecordCount => review?.plan.filteredRecords.length ?? 0;
  int get missingMappingCount {
    final currentReview = review;
    if (currentReview == null) return 0;
    final requiredMappingKeys = <ImportMappingKey>{};
    for (final group in currentReview.groups) {
      if (!group.canSelect) continue;
      final sourceKeys =
          group.group.transactions
              .expand((draft) => draft.sourceEntityKeys)
              .toSet();
      for (final entity in currentReview.plan.sourceEntities) {
        if (sourceKeys.contains(entity.sourceEntityKey)) {
          requiredMappingKeys.add(ImportMappingKey.fromEntity(entity));
        }
      }
    }
    return currentReview.plan.sourceEntities.where((entity) {
      final key = ImportMappingKey.fromEntity(entity);
      if (!requiredMappingKeys.contains(key)) return false;
      return !currentReview.effectiveMappings.containsKey(key) &&
          !plannedCreations.containsKey(key);
    }).length;
  }

  bool get allDirectlyImportableSelected {
    final directlyImportable = review?.groups.where(
      (group) => group.canSelect && !group.requiresWarningConfirmation,
    );
    return directlyImportable != null &&
        directlyImportable.isNotEmpty &&
        directlyImportable.every(
          (group) => selectedGroupIndexes.contains(group.index),
        );
  }

  ImportPageState copyWith({
    ImportPagePhase? phase,
    Object? selectedBundle = _sentinel,
    List<ImportFileProgress>? fileProgress,
    Object? plan = _sentinel,
    Object? review = _sentinel,
    Map<ImportMappingKey, String>? temporaryMappings,
    Map<ImportMappingKey, ImportMappingCreation>? plannedCreations,
    Map<int, Map<ImportMappingKey, String>>? groupMappingOverrides,
    Set<int>? selectedGroupIndexes,
    Set<int>? confirmedSuspectedDuplicateIndexes,
    Set<int>? confirmedWarningIndexes,
    List<ImportBatch>? batches,
    bool? historyLoading,
    bool? mappingConfirmed,
    bool? saveMappingConfiguration,
    Object? error = _sentinel,
    Object? lastCommit = _sentinel,
    Object? revertingBatchId = _sentinel,
  }) {
    return ImportPageState(
      phase: phase ?? this.phase,
      selectedBundle:
          selectedBundle == _sentinel
              ? this.selectedBundle
              : selectedBundle as ImportBundle?,
      fileProgress: fileProgress ?? this.fileProgress,
      plan: plan == _sentinel ? this.plan : plan as ImportParseResult?,
      review: review == _sentinel ? this.review : review as ImportPlanReview?,
      temporaryMappings: temporaryMappings ?? this.temporaryMappings,
      plannedCreations: plannedCreations ?? this.plannedCreations,
      groupMappingOverrides:
          groupMappingOverrides ?? this.groupMappingOverrides,
      selectedGroupIndexes: selectedGroupIndexes ?? this.selectedGroupIndexes,
      confirmedSuspectedDuplicateIndexes:
          confirmedSuspectedDuplicateIndexes ??
          this.confirmedSuspectedDuplicateIndexes,
      confirmedWarningIndexes:
          confirmedWarningIndexes ?? this.confirmedWarningIndexes,
      batches: batches ?? this.batches,
      historyLoading: historyLoading ?? this.historyLoading,
      mappingConfirmed: mappingConfirmed ?? this.mappingConfirmed,
      saveMappingConfiguration:
          saveMappingConfiguration ?? this.saveMappingConfiguration,
      error: error == _sentinel ? this.error : error as UiError?,
      lastCommit:
          lastCommit == _sentinel
              ? this.lastCommit
              : lastCommit as ImportCommitResult?,
      revertingBatchId:
          revertingBatchId == _sentinel
              ? this.revertingBatchId
              : revertingBatchId as String?,
    );
  }
}

typedef ImportActionOutcome<T> = UiActionOutcome<T>;
typedef ImportActionSuccess<T> = UiActionSuccess<T>;
typedef ImportActionFailure<T> = UiActionFailure<T>;

class ImportViewModel extends Notifier<ImportPageState> {
  @override
  ImportPageState build() => ImportPageState.initial();

  Future<ImportActionOutcome<void>> pickFiles({bool append = false}) async {
    state = state.copyWith(
      phase: ImportPagePhase.pickingFiles,
      error: null,
      lastCommit: null,
    );
    try {
      final bundle = await ref.read(importFilePickerProvider).pickYimuBundle();
      if (bundle == null) {
        state = state.copyWith(phase: _settledPhase);
        return const ImportActionOutcome.success(null);
      }
      final selectedBundle =
          append ? _mergeBundles(state.selectedBundle, bundle) : bundle;
      state = state.copyWith(
        phase: ImportPagePhase.idle,
        selectedBundle: selectedBundle,
        fileProgress: _fileProgressForBundle(
          selectedBundle,
          ImportFileProcessingStatus.waiting,
        ),
        plan: null,
        review: null,
        temporaryMappings: const {},
        plannedCreations: const {},
        groupMappingOverrides: const {},
        selectedGroupIndexes: const {},
        confirmedSuspectedDuplicateIndexes: const {},
        confirmedWarningIndexes: const {},
        error: null,
        lastCommit: null,
        mappingConfirmed: false,
        saveMappingConfiguration: false,
      );
      return const ImportActionOutcome.success(null);
    } on AppException catch (exception) {
      return _fail<void>(UiError.fromException(exception));
    } on Exception {
      return _fail<void>(const UiError.unknown());
    }
  }

  Future<ImportActionOutcome<void>> parseSelectedFiles() async {
    final bundle = state.selectedBundle;
    if (bundle == null || bundle.files.isEmpty) {
      return _invalid<void>('请先选择要导入的文件。');
    }
    return loadBundle(bundle);
  }

  Future<ImportActionOutcome<void>> loadBundle(ImportBundle bundle) async {
    state = state.copyWith(
      phase: ImportPagePhase.parsing,
      selectedBundle: bundle,
      fileProgress: _fileProgressForBundle(
        bundle,
        ImportFileProcessingStatus.parsing,
      ),
      plan: null,
      review: null,
      temporaryMappings: const {},
      plannedCreations: const {},
      groupMappingOverrides: const {},
      selectedGroupIndexes: const {},
      confirmedSuspectedDuplicateIndexes: const {},
      confirmedWarningIndexes: const {},
      error: null,
      lastCommit: null,
      mappingConfirmed: false,
      saveMappingConfiguration: false,
    );
    late final ImportParseResult plan;
    try {
      await Future<void>.delayed(Duration.zero);
      plan = ref
          .read(importPlanAppServiceProvider)
          .parse(source: ImportSource.yimu, bundle: bundle);
    } on AppException catch (exception) {
      return _failParsing<void>(UiError.fromException(exception));
    } on Exception {
      return _failParsing<void>(const UiError.unknown());
    }

    state = state.copyWith(
      phase:
          plan.hasFatalIssues
              ? ImportPagePhase.review
              : ImportPagePhase.reviewing,
      plan: plan,
      review: null,
      fileProgress: _fileProgressForPlan(bundle, plan),
    );
    if (plan.hasFatalIssues) {
      return const ImportActionOutcome.success(null);
    }

    try {
      final review = await ref
          .read(importWorkflowAppServiceProvider)
          .review(plan);
      _replaceReview(
        review,
        temporaryMappings: const {},
        plannedCreations: review.plannedCreations,
        groupMappingOverrides: const {},
        selectAllImportable: true,
      );
      return const ImportActionOutcome.success(null);
    } on AppException catch (exception) {
      return _fail<void>(UiError.fromException(exception));
    } on Exception {
      return _fail<void>(const UiError.unknown());
    }
  }

  Future<ImportActionOutcome<void>> refreshReview() async {
    final plan = state.plan;
    if (plan == null || plan.hasFatalIssues) {
      return _invalid<void>('当前没有可刷新的导入计划。');
    }
    return _reviewWithMappings(
      state.temporaryMappings,
      plannedCreations: state.plannedCreations,
      groupMappingOverrides: state.groupMappingOverrides,
    );
  }

  /// Applies only review-safe fields to one draft and re-runs application
  /// validation. Source identity, operation kind, and child ordering remain
  /// unchanged in the returned plan.
  Future<ImportActionOutcome<void>> editGroupDraft({
    required int groupIndex,
    required ImportDraftEdit edit,
    int? childIndex,
  }) async {
    final plan = state.plan;
    if (plan == null || state.review == null) {
      return _invalid<void>('请先选择并解析一木资料包。');
    }
    if (groupIndex < 0 || groupIndex >= plan.groups.length) {
      return _invalid<void>('找不到要编辑的交易组。');
    }
    final group = plan.groups[groupIndex];
    if (childIndex != null) {
      if (childIndex < 0 || childIndex >= group.children.length) {
        return _invalid<void>('找不到要编辑的子交易。');
      }
    }
    final nextPlan = ref
        .read(importPlanAppServiceProvider)
        .editDraft(
          plan: plan,
          groupIndex: groupIndex,
          childIndex: childIndex,
          edit: edit,
        );
    final overrides = _copyGroupOverrides(state.groupMappingOverrides);
    return _reviewEditedPlan(nextPlan, overrides, editedGroupIndex: groupIndex);
  }

  /// Overrides a source mapping for one transaction group only. The default
  /// mapping and other groups are left untouched.
  Future<ImportActionOutcome<void>> setGroupMappingOverride({
    required int groupIndex,
    required ImportMappingKey key,
    required String? targetAccountId,
  }) async {
    final plan = state.plan;
    if (plan == null || state.review == null) {
      return _invalid<void>('请先选择并解析一木资料包。');
    }
    if (groupIndex < 0 || groupIndex >= plan.groups.length) {
      return _invalid<void>('找不到要编辑的交易组。');
    }
    final overrides = _copyGroupOverrides(state.groupMappingOverrides);
    final group = Map<ImportMappingKey, String>.of(overrides[groupIndex] ?? {});
    if (targetAccountId == null) {
      group.remove(key);
    } else {
      group[key] = targetAccountId;
    }
    if (group.isEmpty) {
      overrides.remove(groupIndex);
    } else {
      overrides[groupIndex] = group;
    }
    return _reviewEditedPlan(plan, overrides);
  }

  Future<ImportActionOutcome<void>> setMapping(
    ImportMappingKey key,
    String? targetAccountId,
  ) {
    return setMappingDecision(
      key,
      targetAccountId == null
          ? const UnresolvedDecision('恢复默认映射')
          : ExistingTargetDecision(targetAccountId),
    );
  }

  Future<ImportActionOutcome<void>> setMappingDecision(
    ImportMappingKey key,
    ImportMappingDecision decision,
  ) async {
    final review = state.review;
    if (review == null) return _invalid<void>('请先选择并解析一木资料包。');

    final mappings = Map<ImportMappingKey, String>.of(state.temporaryMappings);
    final creations = Map<ImportMappingKey, ImportMappingCreation>.of(
      state.plannedCreations,
    );
    switch (decision) {
      case ExistingTargetDecision decision:
        mappings[key] = decision.targetId;
        creations.remove(key);
      case PlannedCreationDecision decision:
        mappings.remove(key);
        creations[key] = decision.creation;
      case UnresolvedDecision _:
        mappings.remove(key);
        creations.remove(key);
    }

    state = state.copyWith(
      phase: ImportPagePhase.reviewing,
      plannedCreations: creations,
      mappingConfirmed: false,
      saveMappingConfiguration: false,
      error: null,
    );
    try {
      final nextReview = await ref
          .read(importWorkflowAppServiceProvider)
          .review(
            review.plan,
            temporaryMappings: mappings,
            plannedCreations: creations,
            groupMappingOverrides: state.groupMappingOverrides,
          );
      _replaceReview(
        nextReview,
        temporaryMappings: mappings,
        plannedCreations: nextReview.plannedCreations,
        groupMappingOverrides: state.groupMappingOverrides,
      );
      return const ImportActionOutcome.success(null);
    } on AppException catch (exception) {
      return _fail<void>(UiError.fromException(exception));
    } on Exception {
      return _fail<void>(const UiError.unknown());
    }
  }

  ImportActionOutcome<void> toggleSaveMappingConfiguration() {
    if (state.review == null) {
      return _invalid<void>('请先选择并解析一木资料包。');
    }
    if (state.missingMappingCount > 0) {
      return _invalid<void>('仍有来源账户或分类尚未配置。');
    }
    state = state.copyWith(
      saveMappingConfiguration: !state.saveMappingConfiguration,
      error: null,
    );
    return const ImportActionOutcome.success(null);
  }

  ImportActionOutcome<void> confirmMappingConfiguration() {
    if (state.review == null) {
      return _invalid<void>('请先选择并解析一木资料包。');
    }
    if (state.missingMappingCount > 0) {
      return _invalid<void>('仍有来源账户或分类尚未配置。');
    }
    state = state.copyWith(mappingConfirmed: true, error: null);
    return const ImportActionOutcome.success(null);
  }

  void setGroupSelected(int index, bool selected) {
    final group = _group(index);
    if (group == null || !group.canSelect) return;
    final selectedIndexes = Set<int>.of(state.selectedGroupIndexes);
    final confirmations = Set<int>.of(state.confirmedSuspectedDuplicateIndexes);
    final warningConfirmations = Set<int>.of(state.confirmedWarningIndexes);
    if (selected) {
      selectedIndexes.add(index);
    } else {
      selectedIndexes.remove(index);
      confirmations.remove(index);
      warningConfirmations.remove(index);
    }
    state = state.copyWith(
      selectedGroupIndexes: selectedIndexes,
      confirmedSuspectedDuplicateIndexes: confirmations,
      confirmedWarningIndexes: warningConfirmations,
      lastCommit: null,
    );
  }

  void setGroupSelection(int index, bool selected) {
    final group = _group(index);
    if (group == null) return;
    if (group.isSuspectedDuplicate) {
      setSuspectedDuplicateConfirmed(index, selected);
    } else if (group.hasWarnings) {
      setWarningConfirmed(index, selected);
    } else {
      setGroupSelected(index, selected);
    }
  }

  void selectAllImportable(bool selected) {
    final review = state.review;
    if (review == null) return;
    final indexes =
        selected
            ? {
              for (final group in review.groups)
                if (group.canSelect && !group.requiresWarningConfirmation)
                  group.index,
            }
            : <int>{};
    state = state.copyWith(
      selectedGroupIndexes: indexes,
      confirmedSuspectedDuplicateIndexes:
          selected
              ? state.confirmedSuspectedDuplicateIndexes.intersection(indexes)
              : const {},
      confirmedWarningIndexes:
          selected
              ? state.confirmedWarningIndexes.intersection(indexes)
              : const {},
      lastCommit: null,
    );
  }

  void setSuspectedDuplicateConfirmed(int index, bool confirmed) {
    final group = _group(index);
    if (group == null || !group.isSuspectedDuplicate || !group.canSelect) {
      return;
    }
    final confirmations = Set<int>.of(state.confirmedSuspectedDuplicateIndexes);
    final selected = Set<int>.of(state.selectedGroupIndexes);
    if (confirmed) {
      confirmations.add(index);
      selected.add(index);
    } else {
      confirmations.remove(index);
      selected.remove(index);
    }
    state = state.copyWith(
      selectedGroupIndexes: selected,
      confirmedSuspectedDuplicateIndexes: confirmations,
      lastCommit: null,
    );
  }

  void setWarningConfirmed(int index, bool confirmed) {
    final group = _group(index);
    if (group == null || !group.hasWarnings || !group.canSelect) return;
    final confirmations = Set<int>.of(state.confirmedWarningIndexes);
    final selected = Set<int>.of(state.selectedGroupIndexes);
    if (confirmed) {
      confirmations.add(index);
      selected.add(index);
    } else {
      confirmations.remove(index);
      selected.remove(index);
    }
    state = state.copyWith(
      selectedGroupIndexes: selected,
      confirmedWarningIndexes: confirmations,
      lastCommit: null,
    );
  }

  Future<ImportActionOutcome<ImportCommitResult>> commitSelectedGroups() async {
    final review = state.review;
    if (review == null) {
      return _invalid<ImportCommitResult>('请先选择并解析一木资料包。');
    }
    if (!state.mappingConfirmed) {
      return _invalid<ImportCommitResult>('请先确认映射配置。');
    }
    if (state.selectedGroupIndexes.isEmpty) {
      return _invalid<ImportCommitResult>('请至少选择一个可导入交易组。');
    }

    state = state.copyWith(phase: ImportPagePhase.committing, error: null);
    try {
      final service = ref.read(importWorkflowAppServiceProvider);
      final result = await service.commit(
        ImportCommitCommand(
          plan: review.plan,
          mappings: review.effectiveMappings,
          plannedCreations: state.plannedCreations,
          selectedGroupIndexes: state.selectedGroupIndexes,
          confirmedSuspectedDuplicateIndexes:
              state.confirmedSuspectedDuplicateIndexes,
          confirmedWarningIndexes: state.confirmedWarningIndexes,
          groupMappingOverrides: state.groupMappingOverrides,
          saveMappingConfiguration: state.saveMappingConfiguration,
        ),
      );

      ImportPlanReview? refreshedReview;
      List<ImportBatch>? batches;
      UiError? refreshError;
      final refreshedMappings = Map<ImportMappingKey, String>.of(
        state.temporaryMappings,
      )..addAll(result.createdMappings);
      final remainingCreations =
          Map<ImportMappingKey, ImportMappingCreation>.of(
            state.plannedCreations,
          )..removeWhere((key, _) => result.createdMappings.containsKey(key));
      try {
        refreshedReview = await service.review(
          review.plan,
          temporaryMappings: refreshedMappings,
          plannedCreations: remainingCreations,
          groupMappingOverrides: state.groupMappingOverrides,
        );
        batches = await service.listBatches(source: ImportSource.yimu);
      } on AppException catch (exception) {
        refreshError = UiError.fromException(exception);
      } on Exception {
        refreshError = const UiError.unknown();
      }

      if (refreshedReview != null) {
        _replaceReview(
          refreshedReview,
          temporaryMappings: refreshedMappings,
          plannedCreations: refreshedReview.plannedCreations,
          groupMappingOverrides: state.groupMappingOverrides,
          lastCommit: result,
          batches: batches,
          error: refreshError,
        );
      } else {
        state = state.copyWith(
          phase: ImportPagePhase.review,
          temporaryMappings: refreshedMappings,
          plannedCreations: remainingCreations,
          lastCommit: result,
          batches: batches,
          error: refreshError,
        );
      }
      return ImportActionOutcome.success(result);
    } on AppException catch (exception) {
      return _fail<ImportCommitResult>(UiError.fromException(exception));
    } on Exception {
      return _fail<ImportCommitResult>(const UiError.unknown());
    }
  }

  Future<ImportActionOutcome<List<ImportBatch>>> loadHistory() async {
    state = state.copyWith(historyLoading: true, error: null);
    try {
      final batches = await ref
          .read(importWorkflowAppServiceProvider)
          .listBatches(source: ImportSource.yimu);
      state = state.copyWith(historyLoading: false, batches: batches);
      return ImportActionOutcome.success(batches);
    } on AppException catch (exception) {
      return _failHistory(UiError.fromException(exception));
    } on Exception {
      return _failHistory(const UiError.unknown());
    }
  }

  Future<ImportActionOutcome<ImportBatch>> revertBatch(String batchId) async {
    state = state.copyWith(revertingBatchId: batchId, error: null);
    try {
      final service = ref.read(importWorkflowAppServiceProvider);
      final reverted = await service.revertBatch(batchId);
      final batches = await service.listBatches(source: ImportSource.yimu);
      ImportPlanReview? review = state.review;
      if (review != null) {
        review = await service.review(
          review.plan,
          temporaryMappings: state.temporaryMappings,
          plannedCreations: state.plannedCreations,
          groupMappingOverrides: state.groupMappingOverrides,
        );
      }
      if (review != null) {
        _replaceReview(
          review,
          temporaryMappings: state.temporaryMappings,
          plannedCreations: review.plannedCreations,
          groupMappingOverrides: state.groupMappingOverrides,
          batches: batches,
        );
      } else {
        state = state.copyWith(batches: batches, revertingBatchId: null);
      }
      return ImportActionOutcome.success(reverted);
    } on AppException catch (exception) {
      return _failRevert<ImportBatch>(UiError.fromException(exception));
    } on Exception {
      return _failRevert<ImportBatch>(const UiError.unknown());
    }
  }

  void reset() {
    final batches = state.batches;
    state = ImportPageState.initial().copyWith(batches: batches);
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  ImportPagePhase get _settledPhase =>
      state.review == null && state.plan == null
          ? ImportPagePhase.idle
          : ImportPagePhase.review;

  Future<ImportActionOutcome<void>> _reviewWithMappings(
    Map<ImportMappingKey, String> mappings, {
    Map<ImportMappingKey, ImportMappingCreation>? plannedCreations,
    Map<int, Map<ImportMappingKey, String>>? groupMappingOverrides,
  }) async {
    final plan = state.plan;
    if (plan == null) return _invalid<void>('当前没有可审阅的导入计划。');
    state = state.copyWith(phase: ImportPagePhase.reviewing, error: null);
    try {
      final review = await ref
          .read(importWorkflowAppServiceProvider)
          .review(
            plan,
            temporaryMappings: mappings,
            plannedCreations: plannedCreations ?? state.plannedCreations,
            groupMappingOverrides:
                groupMappingOverrides ?? state.groupMappingOverrides,
          );
      _replaceReview(
        review,
        temporaryMappings: mappings,
        plannedCreations: review.plannedCreations,
        groupMappingOverrides:
            groupMappingOverrides ?? state.groupMappingOverrides,
      );
      return const ImportActionOutcome.success(null);
    } on AppException catch (exception) {
      return _fail<void>(UiError.fromException(exception));
    } on Exception {
      return _fail<void>(const UiError.unknown());
    }
  }

  Future<ImportActionOutcome<void>> _reviewEditedPlan(
    ImportParseResult plan,
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides, {
    int? editedGroupIndex,
  }) async {
    state = state.copyWith(
      phase: ImportPagePhase.reviewing,
      plan: plan,
      error: null,
      mappingConfirmed: false,
      saveMappingConfiguration: false,
      confirmedSuspectedDuplicateIndexes:
          state.confirmedSuspectedDuplicateIndexes
              .where((index) => index != editedGroupIndex)
              .toSet(),
      confirmedWarningIndexes:
          state.confirmedWarningIndexes
              .where((index) => index != editedGroupIndex)
              .toSet(),
    );
    try {
      final review = await ref
          .read(importWorkflowAppServiceProvider)
          .review(
            plan,
            temporaryMappings: state.temporaryMappings,
            plannedCreations: state.plannedCreations,
            groupMappingOverrides: groupMappingOverrides,
          );
      _replaceReview(
        review,
        temporaryMappings: state.temporaryMappings,
        plannedCreations: review.plannedCreations,
        groupMappingOverrides: groupMappingOverrides,
      );
      return const ImportActionOutcome.success(null);
    } on AppException catch (exception) {
      return _fail<void>(UiError.fromException(exception));
    } on Exception {
      return _fail<void>(const UiError.unknown());
    }
  }

  Map<int, Map<ImportMappingKey, String>> _copyGroupOverrides(
    Map<int, Map<ImportMappingKey, String>> source,
  ) {
    return {
      for (final entry in source.entries)
        entry.key: Map<ImportMappingKey, String>.of(entry.value),
    };
  }

  ImportGroupReview? _group(int index) {
    final review = state.review;
    if (review == null || index < 0 || index >= review.groups.length) {
      return null;
    }
    return review.groups[index];
  }

  void _replaceReview(
    ImportPlanReview review, {
    required Map<ImportMappingKey, String> temporaryMappings,
    required Map<ImportMappingKey, ImportMappingCreation> plannedCreations,
    required Map<int, Map<ImportMappingKey, String>> groupMappingOverrides,
    bool selectAllImportable = false,
    ImportCommitResult? lastCommit,
    List<ImportBatch>? batches,
    UiError? error,
  }) {
    final importable = {
      for (final group in review.groups)
        if (group.canSelect) group.index,
    };
    final selected =
        selectAllImportable
            ? {
              for (final group in review.groups)
                if (group.canSelect && !group.requiresWarningConfirmation)
                  group.index,
            }
            : state.selectedGroupIndexes.intersection(importable);
    final confirmed = state.confirmedSuspectedDuplicateIndexes.intersection(
      selected,
    );
    final confirmedWarnings = state.confirmedWarningIndexes.intersection(
      selected,
    );
    state = state.copyWith(
      phase: ImportPagePhase.review,
      plan: review.plan,
      review: review,
      temporaryMappings: temporaryMappings,
      plannedCreations: plannedCreations,
      groupMappingOverrides: groupMappingOverrides,
      selectedGroupIndexes: selected,
      confirmedSuspectedDuplicateIndexes: confirmed,
      confirmedWarningIndexes: confirmedWarnings,
      lastCommit: lastCommit,
      batches: batches,
      error: error,
      revertingBatchId: null,
    );
  }

  ImportActionFailure<T> _invalid<T>(String message) {
    final error = UiError(code: 'import.ui.invalid_action', message: message);
    state = state.copyWith(error: error);
    return ImportActionFailure<T>(error);
  }

  ImportActionFailure<T> _fail<T>(UiError error) {
    state = state.copyWith(phase: _settledPhase, error: error);
    return ImportActionFailure<T>(error);
  }

  ImportActionFailure<T> _failParsing<T>(UiError error) {
    final bundle = state.selectedBundle;
    state = state.copyWith(
      phase: ImportPagePhase.idle,
      fileProgress:
          bundle == null
              ? const []
              : _fileProgressForBundle(
                bundle,
                ImportFileProcessingStatus.failed,
                detail: error.message,
              ),
      error: error,
    );
    return ImportActionFailure<T>(error);
  }

  ImportActionFailure<List<ImportBatch>> _failHistory(UiError error) {
    state = state.copyWith(historyLoading: false, error: error);
    return ImportActionFailure<List<ImportBatch>>(error);
  }

  ImportActionFailure<T> _failRevert<T>(UiError error) {
    state = state.copyWith(revertingBatchId: null, error: error);
    return ImportActionFailure<T>(error);
  }
}

List<ImportFileProgress> _fileProgressForBundle(
  ImportBundle bundle,
  ImportFileProcessingStatus status, {
  String? detail,
}) {
  return [
    for (var index = 0; index < bundle.files.length; index++)
      ImportFileProgress(fileIndex: index, status: status, detail: detail),
  ];
}

List<ImportFileProgress> _fileProgressForPlan(
  ImportBundle bundle,
  ImportParseResult plan,
) {
  final resultByIndex = {
    for (final result in plan.fileResults) result.fileIndex: result,
  };
  final issueCountByType = <ImportSourceFileType, int>{};
  for (final group in plan.groups) {
    for (final issue in group.issues) {
      final fileType = issue.fileType;
      if (fileType == null) continue;
      issueCountByType.update(
        fileType,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  return [
    for (var index = 0; index < bundle.files.length; index++)
      _fileProgressFromResult(
        index,
        resultByIndex[index],
        issueCountByType,
        planHasFatalIssues: plan.hasFatalIssues,
      ),
  ];
}

ImportFileProgress _fileProgressFromResult(
  int fileIndex,
  ImportFileParseResult? result,
  Map<ImportSourceFileType, int> issueCountByType, {
  required bool planHasFatalIssues,
}) {
  if (result == null) {
    return ImportFileProgress(
      fileIndex: fileIndex,
      status:
          planHasFatalIssues
              ? ImportFileProcessingStatus.failed
              : ImportFileProcessingStatus.success,
      detail: planHasFatalIssues ? '无法确认该文件的解析结果。' : null,
    );
  }
  if (result.hasFatalIssues) {
    return ImportFileProgress(
      fileIndex: fileIndex,
      status: ImportFileProcessingStatus.failed,
      detail: result.fatalIssues.first.message,
    );
  }
  final issueCount =
      result.fileType == null ? 0 : issueCountByType[result.fileType] ?? 0;
  if (issueCount > 0) {
    return ImportFileProgress(
      fileIndex: fileIndex,
      status: ImportFileProcessingStatus.warning,
      detail: '$issueCount 条记录需要处理',
    );
  }
  return ImportFileProgress(
    fileIndex: fileIndex,
    status: ImportFileProcessingStatus.success,
  );
}

ImportBundle _mergeBundles(ImportBundle? current, ImportBundle added) {
  return ImportBundle(files: [...?current?.files, ...added.files]);
}

final importViewModelProvider =
    NotifierProvider<ImportViewModel, ImportPageState>(ImportViewModel.new);

const Object _sentinel = Object();
