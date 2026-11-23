import '../../../shared/transaction_runner.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/intake/import/import_models.dart'
    show ImportCategoryKind;
import '../../../../domain/intake/recognition/recognized_payment.dart';
import '../../../../domain/intake/rules/port/recognition_rule_repository.dart';
import '../../../../domain/intake/rules/port/recognition_rule_target_query.dart';
import '../../../../domain/intake/rules/recognition_rule_target.dart';
import '../../../../domain/intake/rules/recognition_rule.dart';
import '../../../../domain/intake/rules/recognition_rule_catalog.dart';
import '../../../../domain/intake/rules/recognition_rule_configuration.dart';
import '../../../../domain/intake/rules/recognition_rule_error_code.dart';
import '../../../../domain/intake/rules/recognition_target_resolution.dart';

class RecognitionRulesData {
  RecognitionRulesData({
    required List<RecognitionRule> rules,
    required List<RecognitionRuleTarget> targets,
  }) : rules = List.unmodifiable(rules),
       targets = List.unmodifiable(targets);
  final List<RecognitionRule> rules;
  final List<RecognitionRuleTarget> targets;
}

class RecognizedPaymentMapping {
  const RecognizedPaymentMapping({this.settlementAccountId, this.categoryId});
  final String? settlementAccountId;
  final String? categoryId;
}

class RecognizedTransferMapping {
  const RecognizedTransferMapping({this.fromAccountId, this.toAccountId});
  final String? fromAccountId;
  final String? toAccountId;
}

class RecognitionRulesAppService {
  const RecognitionRulesAppService({
    required RecognitionRuleCatalog builtins,
    required RecognitionRuleRepository repository,
    required RecognitionRuleTargetQuery targets,
    required TransactionRunner transactions,
    required IdGenerator ids,
  }) : _builtins = builtins,
       _repository = repository,
       _targets = targets,
       _transactions = transactions,
       _ids = ids;

  final RecognitionRuleCatalog _builtins;
  final RecognitionRuleRepository _repository;
  final RecognitionRuleTargetQuery _targets;
  final TransactionRunner _transactions;
  final IdGenerator _ids;

  Future<RecognitionRuleCatalog> loadCatalog() async {
    final targets = await _targets.findAvailableTargets();
    return _loadCatalog(targets);
  }

  Future<RecognitionRulesData> loadData() async {
    final targets = await _targets.findAvailableTargets();
    final catalog = await _loadCatalog(targets);
    return RecognitionRulesData(rules: catalog.rules, targets: targets);
  }

  Future<RecognitionRuleCatalog> _loadCatalog(
    List<RecognitionRuleTarget> targets,
  ) async {
    final configuration = await _repository.loadConfiguration();
    final catalog = _builtins.withConfiguration(configuration);
    final needsBindings =
        catalog.rules.any(
          (rule) => !configuration.targetBindings.containsKey(rule.id),
        ) ||
        _builtins.fallbackPaths.keys.any(
          (direction) => !configuration.targetBindings.containsKey(
            RecognitionRuleCatalog.fallbackRuleId(direction),
          ),
        );
    if (!needsBindings) return catalog.withTargets(targets);
    return _transactions.run(() => _loadCatalogForUpdate(targets));
  }

  // 在写事务内重新读取配置，避免首次绑定覆盖并发的用户修改。
  Future<RecognitionRuleCatalog> _loadCatalogForUpdate(
    List<RecognitionRuleTarget> targets,
  ) async {
    var configuration = await _repository.loadConfiguration();
    var catalog = _builtins.withConfiguration(configuration);
    final bindings = {...configuration.targetBindings};
    for (final rule in catalog.rules) {
      if (bindings.containsKey(rule.id)) continue;
      bindings[rule.id] =
          rule.targetAccountId ??
          resolveRecognitionRuleTarget(
            match: RecognitionRuleMatch(
              path: rule.targetPath,
              ruleId: rule.id,
              isFallback: false,
            ),
            targets: targets,
            kind: rule.kind,
            direction: rule.targetCategoryKind ?? ImportCategoryKind.expense,
          );
    }
    for (final entry in _builtins.fallbackPaths.entries) {
      final id = RecognitionRuleCatalog.fallbackRuleId(entry.key);
      if (bindings.containsKey(id)) continue;
      bindings[id] = resolveRecognitionRuleTarget(
        match: RecognitionRuleMatch(
          path: entry.value,
          ruleId: id,
          isFallback: false,
        ),
        targets: targets,
        kind: RecognitionRuleKind.category,
        direction: entry.key,
      );
    }
    if (bindings.length != configuration.targetBindings.length) {
      configuration = RecognitionRuleConfiguration(
        overrides: configuration.overrides,
        order:
            configuration.order ??
            catalog.rules.map((rule) => rule.id).toList(),
        targetBindings: Map.unmodifiable(bindings),
        deletedRuleIds: configuration.deletedRuleIds,
      );
      await _repository.saveConfiguration(configuration);
      catalog = _builtins.withConfiguration(configuration);
    }
    return catalog.withTargets(targets);
  }

  RecognitionRule newRule(RecognitionRuleKind kind) => RecognitionRule(
    id: _ids.newId(),
    kind: kind,
    keywords: const [],
    priority: 0,
  );

  Future<void> save(RecognitionRule rule) async {
    final builtin = _builtin(rule.id);
    if (rule.keywords.isEmpty ||
        rule.keywords.length > 100 ||
        rule.keywords.any(
          (keyword) => keyword.trim().isEmpty || keyword.length > 80,
        ) ||
        (builtin != null && builtin.kind != rule.kind)) {
      throw BusinessException(RecognitionRuleErrorCode.invalidRule);
    }
    final id = rule.targetAccountId;
    RecognitionRuleTarget? target;
    if (id == null) {
      throw BusinessException(RecognitionRuleErrorCode.targetUnavailable);
    }
    target = (await _targets.findAvailableTargets())
        .where((target) => target.id == id && target.kind == rule.kind)
        .firstOrNull;
    if (target == null) {
      throw BusinessException(RecognitionRuleErrorCode.targetUnavailable);
    }
    final saved = rule.copyWith(
      keywords: rule.keywords.map((keyword) => keyword.trim()).toSet().toList(),
      targetPath: target.path,
      targetCategoryKind: target.direction,
      isBuiltin: builtin != null,
    );
    await _update((rules) {
      final index = rules.indexWhere((current) => current.id == saved.id);
      if (index < 0) {
        if (builtin != null) {
          throw BusinessException(RecognitionRuleErrorCode.invalidRule);
        }
        return [saved, ...rules];
      }
      return [...rules]..[index] = saved;
    });
  }

  Future<void> setEnabled(String id, bool enabled) => _update(
    (rules) => [
      for (final rule in rules)
        rule.id == id ? rule.copyWith(enabled: enabled) : rule,
    ],
  );

  /// Reorder one kind while preserving the other kind's relative order.
  Future<void> reorder(String id, int newIndex) => _update((rules) {
    final index = rules.indexWhere((rule) => rule.id == id);
    if (index < 0) {
      throw BusinessException(RecognitionRuleErrorCode.invalidRule);
    }
    final kind = rules[index].kind;
    final ordered = rules.where((rule) => rule.kind == kind).toList();
    if (newIndex < 0 || newIndex >= ordered.length) {
      throw BusinessException(RecognitionRuleErrorCode.invalidRule);
    }
    final rule = ordered.removeAt(ordered.indexWhere((rule) => rule.id == id));
    ordered.insert(newIndex, rule);
    var position = 0;
    return [
      for (final current in rules)
        current.kind == kind ? ordered[position++] : current,
    ];
  });

  Future<void> moveToTop(String id) => reorder(id, 0);

  Future<void> delete(String id) =>
      _update((rules) => rules.where((rule) => rule.id != id).toList());

  RecognitionRule? _builtin(String id) =>
      _builtins.rules.where((rule) => rule.id == id).firstOrNull;

  Future<void> _update(
    List<RecognitionRule> Function(List<RecognitionRule>) change,
  ) => _transactions.run(() async {
    final targets = await _targets.findAvailableTargets();
    final current = await _loadCatalogForUpdate(targets);
    await _repository.saveConfiguration(
      current.configurationFor(change(current.rules)),
    );
  });

  Future<RecognizedPayment> resolveScreenshotScene(
    RecognizedPayment payment,
  ) async {
    if ((!payment.isOrdinary &&
            payment.scene != PaymentScreenshotScene.unknown) ||
        !payment.transferFromAccountReliable ||
        !payment.transferToAccountReliable ||
        payment.transferFromAccount?.trim().isNotEmpty != true ||
        payment.transferToAccount?.trim().isNotEmpty != true) {
      return payment;
    }
    final targets = await _targets.findAvailableTargets();
    final resolver = IntakeTargetResolver(
      rules: await _loadCatalog(targets),
      targets: targets.where((target) => target.isFundAccount).toList(),
    );
    final from = resolver.resolveUniqueAccount(payment.transferFromAccount!);
    final to = resolver.resolveUniqueAccount(payment.transferToAccount!);
    return from != null && to != null && from != to
        ? payment.asTransfer()
        : payment;
  }

  Future<RecognizedPaymentMapping> resolvePayment(
    RecognizedPayment payment,
  ) async {
    final direction = switch (payment.direction) {
      RecognizedPaymentDirection.expense => ImportCategoryKind.expense,
      RecognizedPaymentDirection.income => ImportCategoryKind.income,
      null => null,
    };
    if (!payment.isOrdinary || direction == null) {
      return const RecognizedPaymentMapping();
    }
    final targets = await _targets.findAvailableTargets();
    final catalog = await _loadCatalog(targets);
    final resolver = IntakeTargetResolver(rules: catalog, targets: targets);
    return RecognizedPaymentMapping(
      settlementAccountId: resolver.resolveAccount(
        accountName: payment.paymentMethodReliable
            ? payment.paymentMethod
            : null,
        matchingText: payment.accountMatchingText,
      ),
      categoryId: resolver
          .resolveCategory(
            matchingText: payment.categoryMatchingText,
            direction: direction,
          )
          ?.targetAccountId,
    );
  }

  Future<RecognizedTransferMapping> resolveTransfer(
    RecognizedPayment payment,
  ) async {
    if (payment.scene != PaymentScreenshotScene.transfer) {
      return const RecognizedTransferMapping();
    }
    final targets = await _targets.findAvailableTargets();
    final catalog = await _loadCatalog(targets);
    final resolver = IntakeTargetResolver(
      rules: catalog,
      targets: targets.where((target) => target.isFundAccount).toList(),
    );
    final from = payment.transferFromAccountReliable
        ? payment.transferFromAccount
        : null;
    final to = payment.transferToAccountReliable
        ? payment.transferToAccount
        : null;
    return RecognizedTransferMapping(
      fromAccountId: resolver.resolveAccount(
        accountName: from,
        matchingText: from ?? '',
      ),
      toAccountId: resolver.resolveAccount(
        accountName: to,
        matchingText: to ?? '',
      ),
    );
  }
}
