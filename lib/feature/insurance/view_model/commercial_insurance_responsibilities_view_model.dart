import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_command_api.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_coverage_field.dart';
import 'commercial_insurance_detail_view_model.dart';

part 'commercial_insurance_responsibilities_view_model.g.dart';

final _logger = Logger('feature.insurance.commercial_responsibilities');

@riverpod
class CommercialInsuranceResponsibilitiesViewModel
    extends _$CommercialInsuranceResponsibilitiesViewModel {
  CommercialInsuranceResponsibilitiesState? _initializedState;
  var _draftSequence = 0;

  @override
  Future<CommercialInsuranceResponsibilitiesState?> build(
    String insuranceId,
  ) async {
    final detail = await ref
        .watch(insuranceCoverageQueryServiceProvider)
        .commercialInsuranceDetail(insuranceId);
    if (detail == null) return null;
    return _initializedState ??= CommercialInsuranceResponsibilitiesState(
      insurance: detail.insurance,
      responsibilities: [
        for (final responsibility in detail.insurance.responsibilities)
          InsuranceResponsibilityDraft.fromDomain(responsibility),
      ],
    );
  }

  Future<UiActionOutcome<String>> upsertResponsibility(
    InsuranceResponsibilityDraft draft,
  ) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    if (previous.submitting) return _invalid('正在保存，请勿重复提交');
    _upsertResponsibility(draft);
    return _persistOrRestore(previous);
  }

  Future<UiActionOutcome<String>> removeResponsibility(String id) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    if (previous.submitting) return _invalid('正在保存，请勿重复提交');
    _removeResponsibility(id);
    return _persistOrRestore(previous);
  }

  Future<UiActionOutcome<String>> upsertPoint(
    String responsibilityId,
    InsurancePointDraft point,
  ) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    if (previous.submitting) return _invalid('正在保存，请勿重复提交');
    _upsertPoint(responsibilityId, point);
    return _persistOrRestore(previous);
  }

  Future<UiActionOutcome<String>> removePoint(
    String responsibilityId,
    String pointId,
  ) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    if (previous.submitting) return _invalid('正在保存，请勿重复提交');
    _removePoint(responsibilityId, pointId);
    return _persistOrRestore(previous);
  }

  void setKind(ResponsibilityKind? kind) {
    _update((current) => current.copyWith(selectedKind: kind));
  }

  Future<UiActionOutcome<String>> reorderResponsibilities(
    int oldIndex,
    int newIndex,
  ) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    if (previous.submitting) return _invalid('正在保存，请勿重复提交');
    final visible = [...previous.visibleResponsibilities];
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return _invalid('保障责任顺序无效');
    }
    if (oldIndex == newIndex) {
      return UiActionOutcome.success(previous.insurance.id);
    }
    visible.insert(newIndex, visible.removeAt(oldIndex));
    var index = 0;
    final next = [
      for (final responsibility in previous.responsibilities)
        if (previous.selectedKind == null ||
            responsibility.kind == previous.selectedKind)
          visible[index++]
        else
          responsibility,
    ];
    _update((current) => current.copyWith(responsibilities: next));
    return _persistOrRestore(previous);
  }

  Future<UiActionOutcome<String>> reorderPoints(
    String responsibilityId,
    int oldIndex,
    int newIndex,
  ) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    if (previous.submitting) return _invalid('正在保存，请勿重复提交');
    final index = previous.responsibilities.indexWhere(
      (item) => item.id == responsibilityId,
    );
    if (index == -1) return _invalid('保障责任不存在');
    final responsibility = previous.responsibilities[index];
    final points = [...responsibility.points];
    if (oldIndex < 0 ||
        oldIndex >= points.length ||
        newIndex < 0 ||
        newIndex >= points.length) {
      return _invalid('要点顺序无效');
    }
    if (oldIndex == newIndex) {
      return UiActionOutcome.success(previous.insurance.id);
    }
    points.insert(newIndex, points.removeAt(oldIndex));
    final next = [...previous.responsibilities];
    next[index] = InsuranceResponsibilityDraft(
      id: responsibility.id,
      kind: responsibility.kind,
      name: responsibility.name,
      description: responsibility.description,
      points: points,
    );
    _update((current) => current.copyWith(responsibilities: next));
    return _persistOrRestore(previous);
  }

  void _upsertResponsibility(InsuranceResponsibilityDraft draft) {
    _update((current) {
      final next = [...current.responsibilities];
      final index = next.indexWhere((item) => item.id == draft.id);
      if (index == -1) {
        next.add(draft);
      } else {
        next[index] = draft;
      }
      return current.copyWith(responsibilities: next);
    });
  }

  void _removeResponsibility(String id) {
    _update(
      (current) => current.copyWith(
        responsibilities: [
          for (final item in current.responsibilities)
            if (item.id != id) item,
        ],
      ),
    );
  }

  void _upsertPoint(String responsibilityId, InsurancePointDraft point) {
    _update((current) {
      final index = current.responsibilities.indexWhere(
        (item) => item.id == responsibilityId,
      );
      if (index == -1) return current;
      final responsibility = current.responsibilities[index];
      final points = [...responsibility.points];
      final pointIndex = points.indexWhere((item) => item.id == point.id);
      if (pointIndex == -1) {
        points.add(point);
      } else {
        points[pointIndex] = point;
      }
      final next = [...current.responsibilities];
      next[index] = InsuranceResponsibilityDraft(
        id: responsibility.id,
        kind: responsibility.kind,
        name: responsibility.name,
        description: responsibility.description,
        points: points,
      );
      return current.copyWith(responsibilities: next);
    });
  }

  void _removePoint(String responsibilityId, String pointId) {
    _update((current) {
      final index = current.responsibilities.indexWhere(
        (item) => item.id == responsibilityId,
      );
      if (index == -1) return current;
      final responsibility = current.responsibilities[index];
      final next = [...current.responsibilities];
      next[index] = InsuranceResponsibilityDraft(
        id: responsibility.id,
        kind: responsibility.kind,
        name: responsibility.name,
        description: responsibility.description,
        points: [
          for (final point in responsibility.points)
            if (point.id != pointId) point,
        ],
      );
      return current.copyWith(responsibilities: next);
    });
  }

  Future<UiActionOutcome<String>> _persistOrRestore(
    CommercialInsuranceResponsibilitiesState previous,
  ) async {
    final outcome = await save();
    if (outcome is UiActionFailure<String> && ref.mounted) {
      _initializedState = previous;
      state = AsyncData(previous);
    }
    return outcome;
  }

  String newResponsibilityDraftId() =>
      '__draft_responsibility__${_draftSequence++}';

  String newPointDraftId() => '__draft_point__${_draftSequence++}';

  Future<UiActionOutcome<String>> saveCoverageField(
    InsuranceCoverageField field,
    String value,
  ) {
    return save(
      coverageSummary: field == InsuranceCoverageField.summary ? value : null,
      coverageHighlights: field == InsuranceCoverageField.highlights
          ? value
          : null,
      waitingPeriodDescription: field == InsuranceCoverageField.waitingPeriod
          ? value
          : null,
      exclusionsDescription: field == InsuranceCoverageField.exclusions
          ? value
          : null,
    );
  }

  Future<UiActionOutcome<String>> save({
    String? coverageSummary,
    String? coverageHighlights,
    String? waitingPeriodDescription,
    String? exclusionsDescription,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('保障责任尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');

    _update((value) => value.copyWith(submitting: true));
    try {
      final insurance = current.insurance;
      final outcome = await guardUiAction(
        _logger,
        'Save commercial insurance responsibilities',
        () async {
          final latest = await ref
              .read(insuranceCoverageQueryServiceProvider)
              .commercialInsuranceDetail(insurance.id);
          if (latest == null) {
            throw BusinessException(
              InsuranceErrorCode.commercialInsuranceNotFound,
            );
          }
          final latestInsurance = latest.insurance;
          return ref
              .read(commercialInsuranceAppServiceProvider)
              .save(
                SaveCommercialInsuranceCommand(
                  id: insurance.id,
                  name: latestInsurance.name,
                  insurerName: latestInsurance.insurerName,
                  category: latestInsurance.category,
                  productForm: latestInsurance.productForm,
                  coverageTerm: latestInsurance.coverageTerm,
                  coverageAmount: latestInsurance.coverageAmount,
                  coverageAmountDescription:
                      latestInsurance.coverageAmountDescription,
                  coverageSummary: coverageSummary,
                  coverageHighlights: coverageHighlights,
                  waitingPeriodDescription: waitingPeriodDescription,
                  exclusionsDescription: exclusionsDescription,
                  insuredPersonIds: latestInsurance.insuredPersonIds,
                  responsibilities: [
                    for (final responsibility in current.responsibilities)
                      InsuranceResponsibilityInput(
                        id: responsibility.isNew ? null : responsibility.id,
                        kind: responsibility.kind,
                        name: responsibility.name,
                        description: responsibility.description,
                        points: [
                          for (final point in responsibility.points)
                            InsuranceResponsibilityPointInput(
                              id: point.isNew ? null : point.id,
                              label: point.label,
                              value: point.value,
                            ),
                        ],
                      ),
                  ],
                ),
              );
        },
      );
      if (outcome is UiActionSuccess<String>) {
        final refreshed = await ref
            .read(insuranceCoverageQueryServiceProvider)
            .commercialInsuranceDetail(insurance.id);
        if (ref.mounted && refreshed != null) {
          final next = CommercialInsuranceResponsibilitiesState(
            insurance: refreshed.insurance,
            selectedKind:
                refreshed.insurance.responsibilities.any(
                  (item) => item.kind == state.asData?.value?.selectedKind,
                )
                ? state.asData?.value?.selectedKind
                : null,
            responsibilities: [
              for (final responsibility in refreshed.insurance.responsibilities)
                InsuranceResponsibilityDraft.fromDomain(responsibility),
            ],
          );
          _initializedState = next;
          state = AsyncData(next);
        }
        ref.invalidate(commercialInsuranceDetailViewModelProvider);
      }
      return outcome;
    } finally {
      if (ref.mounted) {
        _update((latest) => latest.copyWith(submitting: false));
      }
    }
  }

  void _update(
    CommercialInsuranceResponsibilitiesState Function(
      CommercialInsuranceResponsibilitiesState,
    )
    update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = update(current);
    _initializedState = next;
    state = AsyncData(next);
  }

  UiActionOutcome<String> _invalid(String message) {
    return UiActionOutcome.failure(
      UiError(code: InsuranceErrorCode.invalidCommand.code, message: message),
    );
  }
}

class CommercialInsuranceResponsibilitiesState {
  CommercialInsuranceResponsibilitiesState({
    required this.insurance,
    required List<InsuranceResponsibilityDraft> responsibilities,
    this.submitting = false,
    this.selectedKind,
  }) : responsibilities = List.unmodifiable(responsibilities);

  final CommercialInsurance insurance;
  final List<InsuranceResponsibilityDraft> responsibilities;
  final bool submitting;
  final ResponsibilityKind? selectedKind;

  List<ResponsibilityKind> get availableKinds => [
    for (final kind in ResponsibilityKind.values)
      if (responsibilities.any((item) => item.kind == kind)) kind,
  ];

  List<InsuranceResponsibilityDraft> get visibleResponsibilities => [
    for (final item in responsibilities)
      if (selectedKind == null || item.kind == selectedKind) item,
  ];

  CommercialInsuranceResponsibilitiesState copyWith({
    List<InsuranceResponsibilityDraft>? responsibilities,
    bool? submitting,
    Object? selectedKind = _sentinel,
  }) {
    return CommercialInsuranceResponsibilitiesState(
      insurance: insurance,
      responsibilities: responsibilities ?? this.responsibilities,
      submitting: submitting ?? this.submitting,
      selectedKind: selectedKind == _sentinel
          ? this.selectedKind
          : selectedKind as ResponsibilityKind?,
    );
  }
}

const Object _sentinel = Object();

class InsurancePointDraft {
  const InsurancePointDraft({
    required this.id,
    required this.label,
    required this.value,
  });

  factory InsurancePointDraft.fromDomain(ResponsibilityPoint point) {
    return InsurancePointDraft(
      id: point.id,
      label: point.label,
      value: point.value,
    );
  }

  final String id;
  final String label;
  final String value;

  bool get isNew => id.startsWith('__draft');
}

class InsuranceResponsibilityDraft {
  const InsuranceResponsibilityDraft({
    required this.id,
    required this.kind,
    required this.name,
    this.description,
    required this.points,
  });

  factory InsuranceResponsibilityDraft.fromDomain(
    CoverageResponsibility responsibility,
  ) {
    return InsuranceResponsibilityDraft(
      id: responsibility.id,
      kind: responsibility.kind,
      name: responsibility.name,
      description: responsibility.description,
      points: [
        for (final point in responsibility.points)
          InsurancePointDraft.fromDomain(point),
      ],
    );
  }

  final String id;
  final ResponsibilityKind kind;
  final String name;
  final String? description;
  final List<InsurancePointDraft> points;

  bool get isNew => id.startsWith('__draft');
}
