import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/accounting/enums/accounting_enums.dart';
import 'package:smartflow/domain/accounting/queries/transaction_scope.dart';

void main() {
  group('TransactionScopeFilter presets', () {
    test('stats: current + excluded_from_stats=false', () {
      const scope = TransactionScopeFilter.stats;
      expect(scope.businessStates, {BusinessState.current});
      expect(scope.excludedFromStats, false);
      expect(scope.excludedFromBudget, isNull);
    });

    test('budget: current + excluded_from_budget=false', () {
      const scope = TransactionScopeFilter.budget;
      expect(scope.businessStates, {BusinessState.current});
      expect(scope.excludedFromStats, isNull);
      expect(scope.excludedFromBudget, false);
    });

    test('assetLiability: current 仅 state 过滤,无 exclude 限制', () {
      const scope = TransactionScopeFilter.assetLiability;
      expect(scope.businessStates, {BusinessState.current});
      expect(scope.excludedFromStats, isNull);
      expect(scope.excludedFromBudget, isNull);
    });

    test('actual: current + compensation', () {
      const scope = TransactionScopeFilter.actual;
      expect(scope.businessStates, {
        BusinessState.current,
        BusinessState.compensation,
      });
      expect(scope.excludedFromStats, isNull);
      expect(scope.excludedFromBudget, isNull);
    });

    test('all: 所有 BusinessState', () {
      const scope = TransactionScopeFilter.all;
      expect(scope.businessStates, BusinessState.values.toSet());
      expect(scope.excludedFromStats, isNull);
      expect(scope.excludedFromBudget, isNull);
    });
  });
}
