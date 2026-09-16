import 'dart:async';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../presentation/reference_rates_presentation.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'reference_rates_view_model.g.dart';

class ReferenceRatesGroupState {
  const ReferenceRatesGroupState({
    this.history,
    this.year,
    this.loading = true,
    this.error,
  });
  final ReferenceRateHistory? history;
  final int? year;
  final bool loading;
  final UiError? error;

  ReferenceRatesGroupState withYear(int? year) => ReferenceRatesGroupState(
    history: history,
    year: year,
    loading: loading,
    error: error,
  );
}

class ReferenceRatesState {
  ReferenceRatesState({
    this.group = ReferenceRateGroup.lpr,
    Map<ReferenceRateGroup, ReferenceRatesGroupState> groups = const {},
  }) : groups = Map.unmodifiable(groups);
  final ReferenceRateGroup group;
  final Map<ReferenceRateGroup, ReferenceRatesGroupState> groups;
  ReferenceRatesGroupState get current =>
      groups[group] ?? const ReferenceRatesGroupState();
  List<ReferenceRateTableRow> get rows =>
      referenceRateTableRows(group, current.history, year: current.year);
  List<int> get years => {
    for (final row in referenceRateTableRows(group, current.history))
      row.date.year,
    ?current.year,
  }.toList()..sort((a, b) => b.compareTo(a));
  String? get warning => current.error == null
      ? referenceRateHistoryWarning(group, current.history)
      : current.history?.rates.isNotEmpty == true
      ? '更新未完成，当前显示已保存数据'
      : current.error!.message;
}

@riverpod
class ReferenceRatesViewModel extends _$ReferenceRatesViewModel {
  final _requests = <ReferenceRateGroup, int>{};

  @override
  ReferenceRatesState build() {
    unawaited(
      Future.microtask(() {
        if (ref.mounted) return _load(ReferenceRateGroup.lpr);
      }),
    );
    return ReferenceRatesState();
  }

  void selectGroup(ReferenceRateGroup group) {
    if (group == state.group) return;
    state = ReferenceRatesState(group: group, groups: state.groups);
    if (!state.groups.containsKey(group)) unawaited(_load(group));
  }

  void selectYear(int? year) =>
      _update(state.group, state.current.withYear(year));

  Future<void> refresh() =>
      state.current.loading ? Future.value() : _load(state.group);

  void _update(ReferenceRateGroup group, ReferenceRatesGroupState value) {
    state = ReferenceRatesState(
      group: state.group,
      groups: {...state.groups, group: value},
    );
  }

  Future<void> _load(ReferenceRateGroup group) async {
    final request = (_requests[group] ?? 0) + 1;
    _requests[group] = request;
    final previous = state.groups[group];
    _update(
      group,
      ReferenceRatesGroupState(
        history: previous?.history,
        year: previous?.year,
      ),
    );
    final outcome = await guardUiAction(
      Logger('feature.profile.reference_rates'),
      'Load reference rate history',
      () async {
        await for (final history
            in ref.read(referenceRateAppServiceProvider).history(group.types)) {
          if (!ref.mounted || _requests[group] != request) return;
          _update(
            group,
            ReferenceRatesGroupState(
              history: history,
              year: state.groups[group]?.year,
              loading: history.updating,
            ),
          );
        }
      },
    );
    if (!ref.mounted || _requests[group] != request) return;
    final current = state.groups[group]!;
    _update(
      group,
      ReferenceRatesGroupState(
        history: current.history,
        year: current.year,
        loading: false,
        error: switch (outcome) {
          UiActionFailure(:final error) => error,
          UiActionSuccess() => null,
        },
      ),
    );
  }
}
