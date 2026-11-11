import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_command_api.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
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
    _upsertResponsibility(draft);
    return _persistOrRestore(previous);
  }

  Future<UiActionOutcome<String>> removeResponsibility(String id) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    _removeResponsibility(id);
    return _persistOrRestore(previous);
  }

  Future<UiActionOutcome<String>> upsertPoint(
    String responsibilityId,
    InsurancePointDraft point,
  ) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    _upsertPoint(responsibilityId, point);
    return _persistOrRestore(previous);
  }

  Future<UiActionOutcome<String>> removePoint(
    String responsibilityId,
    String pointId,
  ) async {
    final previous = state.asData?.value;
    if (previous == null) return _invalid('保障责任尚未加载');
    _removePoint(responsibilityId, pointId);
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

  Future<UiActionOutcome<String>> save() async {
    final current = state.asData?.value;
    if (current == null) return _invalid('保障责任尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');

    _update((value) => value.copyWith(submitting: true));
    try {
      final insurance = current.insurance;
      final outcome = await guardUiAction(
        _logger,
        'Save commercial insurance responsibilities',
        () {
          return ref
              .read(commercialInsuranceAppServiceProvider)
              .save(
                SaveCommercialInsuranceCommand(
                  id: insurance.id,
                  name: insurance.name,
                  insurerName: insurance.insurerName,
                  category: insurance.category,
                  productForm: insurance.productForm,
                  coverageTerm: insurance.coverageTerm,
                  coverageAmount: insurance.coverageAmount,
                  premiumPlan: insurance.premiumPlan,
                  insuredPersonIds: insurance.insuredPersonIds,
                  responsibilities: [
                    for (final responsibility in current.responsibilities)
                      InsuranceResponsibilityInput(
                        id: responsibility.isNew ? null : responsibility.id,
                        kind: responsibility.kind,
                        name: responsibility.name,
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
  }) : responsibilities = List.unmodifiable(responsibilities);

  final CommercialInsurance insurance;
  final List<InsuranceResponsibilityDraft> responsibilities;
  final bool submitting;

  CommercialInsuranceResponsibilitiesState copyWith({
    List<InsuranceResponsibilityDraft>? responsibilities,
    bool? submitting,
  }) {
    return CommercialInsuranceResponsibilitiesState(
      insurance: insurance,
      responsibilities: responsibilities ?? this.responsibilities,
      submitting: submitting ?? this.submitting,
    );
  }
}

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
    required this.points,
  });

  factory InsuranceResponsibilityDraft.fromDomain(
    CoverageResponsibility responsibility,
  ) {
    return InsuranceResponsibilityDraft(
      id: responsibility.id,
      kind: responsibility.kind,
      name: responsibility.name,
      points: [
        for (final point in responsibility.points)
          InsurancePointDraft.fromDomain(point),
      ],
    );
  }

  final String id;
  final ResponsibilityKind kind;
  final String name;
  final List<InsurancePointDraft> points;

  bool get isNew => id.startsWith('__draft');
}
