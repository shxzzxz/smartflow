import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/recognition_rules_provider.dart';
import '../../../application/intake/intake_rules_api.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

class RecognitionRuleEditorState {
  const RecognitionRuleEditorState({
    this.rule,
    this.targets = const [],
    this.loading = true,
    this.saving = false,
    this.error,
  });
  final RecognitionRule? rule;
  final List<RecognitionRuleTarget> targets;
  final bool loading;
  final bool saving;
  final UiError? error;
  List<RecognitionRuleTarget> get availableTargets =>
      targets.where((target) => target.kind == rule?.kind).toList();
}

final recognitionRuleEditorViewModelProvider =
    NotifierProvider.autoDispose<
      RecognitionRuleEditorViewModel,
      RecognitionRuleEditorState
    >(RecognitionRuleEditorViewModel.new);

class RecognitionRuleEditorViewModel
    extends Notifier<RecognitionRuleEditorState> {
  @override
  RecognitionRuleEditorState build() => const RecognitionRuleEditorState();

  Future<RecognitionRule?> initialize({
    String? ruleId,
    required RecognitionRuleKind kind,
  }) async {
    final service = ref.read(recognitionRulesAppServiceProvider);
    state = const RecognitionRuleEditorState();
    final outcome = await guardUiAction(
      Logger('feature.recognition_rules'),
      'Load recognition rule editor',
      service.loadData,
    );
    if (!ref.mounted) return null;
    switch (outcome) {
      case UiActionSuccess(:final value):
        final rule = ruleId == null
            ? service.newRule(kind)
            : value.rules.where((rule) => rule.id == ruleId).firstOrNull;
        state = RecognitionRuleEditorState(
          rule: rule,
          targets: value.targets,
          loading: false,
          error: rule == null
              ? const UiError(code: 'rule_missing', message: '识别规则不存在。')
              : null,
        );
        return rule;
      case UiActionFailure(:final error):
        state = RecognitionRuleEditorState(loading: false, error: error);
        return null;
    }
  }

  void _update(RecognitionRule Function(RecognitionRule) update) {
    final rule = state.rule;
    if (rule == null || state.loading || state.saving) return;
    state = RecognitionRuleEditorState(
      rule: update(rule),
      targets: state.targets,
      loading: false,
    );
  }

  void setEnabled(bool value) =>
      _update((rule) => rule.copyWith(enabled: value));
  void setSource(RecognitionRuleSource? value) =>
      _update((rule) => rule.copyWith(source: value));
  void setKeywords(String value) => _update(
    (rule) => rule.copyWith(
      keywords: value
          .split(RegExp(r'[,，、;；\n]'))
          .map((keyword) => keyword.trim())
          .where((keyword) => keyword.isNotEmpty)
          .toSet()
          .toList(),
    ),
  );
  void setTarget(String id) => _update((rule) {
    final target = state.availableTargets
        .where((target) => target.id == id)
        .firstOrNull;
    return target == null
        ? rule
        : rule.copyWith(
            targetAccountId: target.id,
            targetPath: target.path,
            targetCategoryKind: target.direction,
          );
  });

  Future<SubmitOutcome?> save() async {
    final rule = state.rule;
    if (rule == null || state.loading || state.saving) return null;
    final targets = state.targets;
    final service = ref.read(recognitionRulesAppServiceProvider);
    state = RecognitionRuleEditorState(
      rule: rule,
      targets: targets,
      loading: false,
      saving: true,
    );
    final outcome = await guardUiAction(
      Logger('feature.recognition_rules'),
      'Save recognition rule',
      () => service.save(rule),
    );
    if (!ref.mounted) return null;
    state = RecognitionRuleEditorState(
      rule: rule,
      targets: targets,
      loading: false,
      error: outcome is UiActionFailure<void> ? outcome.error : null,
    );
    return outcome is UiActionFailure<void>
        ? SubmitOutcome.failure(outcome.error)
        : const SubmitOutcome.success();
  }
}
