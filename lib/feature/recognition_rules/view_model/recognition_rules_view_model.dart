import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/recognition_rules_provider.dart';
import '../../../application/intake/intake_rules_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

class RecognitionRulesState {
  const RecognitionRulesState({
    required this.data,
    this.kind = RecognitionRuleKind.account,
    this.searchQuery = '',
    this.saving = false,
    this.error,
  });

  final RecognitionRulesData data;
  final RecognitionRuleKind kind;
  final String searchQuery;
  final bool saving;
  final UiError? error;

  List<RecognitionRule> get rules =>
      data.rules.where((rule) => rule.kind == kind).toList();

  bool get isSearching => searchQuery.trim().isNotEmpty;

  bool get canReorder => !saving && !isSearching;

  List<RecognitionRule> get filteredRules {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return rules;
    final targetNames = {
      for (final target in data.targets)
        if (target.kind == kind) target.id: target.displayName,
    };
    return rules.where((rule) {
      final targetName =
          targetNames[rule.targetAccountId] ?? rule.targetPath.join(' / ');
      return rule.keywords.any(
            (keyword) => keyword.toLowerCase().contains(query),
          ) ||
          targetName.toLowerCase().contains(query);
    }).toList();
  }
}

final recognitionRulesViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      RecognitionRulesViewModel,
      RecognitionRulesState
    >(RecognitionRulesViewModel.new);

class RecognitionRulesViewModel extends AsyncNotifier<RecognitionRulesState> {
  @override
  Future<RecognitionRulesState> build() async => RecognitionRulesState(
    data: await ref.read(recognitionRulesAppServiceProvider).loadData(),
  );

  void selectKind(RecognitionRuleKind kind) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      RecognitionRulesState(
        data: current.data,
        kind: kind,
        searchQuery: current.searchQuery,
        saving: current.saving,
        error: current.error,
      ),
    );
  }

  void setSearchQuery(String query) {
    final current = state.asData?.value;
    if (current == null || current.searchQuery == query) return;
    state = AsyncData(
      RecognitionRulesState(
        data: current.data,
        kind: current.kind,
        searchQuery: query,
        saving: current.saving,
        error: current.error,
      ),
    );
  }

  Future<void> refresh() => _change((_) async {});

  Future<void> setEnabled(String id, bool enabled) =>
      _change((service) => service.setEnabled(id, enabled));

  Future<void> delete(String id) => _change((service) => service.delete(id));

  Future<void> moveToTop(String id) => reorder(id, 0);

  Future<void> reorder(String id, int newIndex) async {
    final current = state.asData?.value;
    if (current == null || current.saving) return;
    final ordered = [...current.rules];
    final oldIndex = ordered.indexWhere((rule) => rule.id == id);
    if (oldIndex < 0 || newIndex < 0 || newIndex >= ordered.length) return;
    final rule = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, rule);
    var position = 0;
    final optimistic = RecognitionRulesData(
      rules: [
        for (final rule in current.data.rules)
          rule.kind == current.kind ? ordered[position++] : rule,
      ],
      targets: current.data.targets,
    );
    await _change(
      (service) => service.reorder(id, newIndex),
      optimisticData: optimistic,
    );
  }

  Future<void> _change(
    Future<void> Function(RecognitionRulesAppService) action, {
    RecognitionRulesData? optimisticData,
  }) async {
    final current = state.asData?.value;
    if (current == null || current.saving) return;
    final service = ref.read(recognitionRulesAppServiceProvider);
    state = AsyncData(
      RecognitionRulesState(
        data: optimisticData ?? current.data,
        kind: current.kind,
        searchQuery: current.searchQuery,
        saving: true,
      ),
    );
    final outcome = await guardUiAction(
      Logger('feature.recognition_rules'),
      'Update recognition rules',
      () async {
        await action(service);
        return service.loadData();
      },
    );
    if (!ref.mounted) return;
    state = AsyncData(
      RecognitionRulesState(
        data: outcome is UiActionSuccess<RecognitionRulesData>
            ? outcome.value
            : current.data,
        kind: state.asData?.value.kind ?? current.kind,
        searchQuery: state.asData?.value.searchQuery ?? current.searchQuery,
        error: outcome is UiActionFailure<RecognitionRulesData>
            ? outcome.error
            : null,
      ),
    );
  }
}
