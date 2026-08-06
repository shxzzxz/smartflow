import '../../../core/time/month_key.dart';
import '../entity/budget.dart';

abstract interface class BudgetRepository {
  Future<Budget?> findById(String id);

  Future<Budget?> findByMonthAndCategory(MonthKey month, String? categoryId);

  Future<List<Budget>> findByMonth(MonthKey month);

  Future<void> save(Budget budget);

  Future<void> saveAll(Iterable<Budget> budgets);

  Future<void> delete(String id);

  Future<void> deleteByMonth(MonthKey month);
}
