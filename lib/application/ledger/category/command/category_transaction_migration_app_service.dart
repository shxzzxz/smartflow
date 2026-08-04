import 'package:logging/logging.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_violation_reason.dart';

import '../../transaction/command/transaction_command.dart';
import '../../transaction/command/transaction_edit_app_service.dart';
import '../../transaction/query/port/transaction_read_repository.dart';
import 'category_command.dart';

final _logger = Logger('application.ledger.category_migration');

abstract interface class CategoryTransactionMigrationAppService {
  Future<CategoryTransactionMigrationResult> migrate(
    CategoryTransactionMigrationCommand command,
  );
}

/// 把命中源分类的全部顶层交易组改写到目标分类。
///
/// 复用单笔编辑的交易组重写、派生分录同步与余额维护；整批迁移在同一个
/// 数据库事务内完成，任何一笔重写失败即整体回滚，不产生部分迁移。
class CategoryTransactionMigrationAppServiceImpl
    implements CategoryTransactionMigrationAppService {
  CategoryTransactionMigrationAppServiceImpl({
    required AccountRepository accountRepository,
    required TransactionReadRepository transactionReadRepository,
    required TransactionEditAppService editService,
    required TransactionRunner transactionRunner,
  }) : _accountRepository = accountRepository,
       _transactionRead = transactionReadRepository,
       _editService = editService,
       _transactionRunner = transactionRunner;

  final AccountRepository _accountRepository;
  final TransactionReadRepository _transactionRead;
  final TransactionEditAppService _editService;
  final TransactionRunner _transactionRunner;

  @override
  Future<CategoryTransactionMigrationResult> migrate(
    CategoryTransactionMigrationCommand command,
  ) async {
    final result = await _transactionRunner.run(() async {
      final source = await _loadActiveManageableCategory(
        command.sourceCategoryId,
      );
      if (command.targetCategoryId == source.id) {
        LedgerViolationReason.categoryMigrationTargetInvalid.throwException(
          message: '目标分类不能与源分类相同。',
        );
      }
      final target = await _loadActiveManageableCategory(
        command.targetCategoryId,
      );
      if (target.type != source.type) {
        LedgerViolationReason.categoryMigrationTargetInvalid.throwException(
          message: '目标分类类型必须与源分类一致。',
        );
      }

      final targets = await _transactionRead.findCategoryTransactionTargets(
        source.id,
      );
      for (final transactionTarget in targets) {
        await _migrateGroup(transactionTarget, target.id);
      }
      return CategoryTransactionMigrationResult(
        migratedGroupCount: targets.length,
      );
    });
    _logger.info(
      'Category transaction migration completed: '
      '${command.sourceCategoryId} -> ${command.targetCategoryId}, '
      'migrated=${result.migratedGroupCount} groups.',
    );
    return result;
  }

  Future<void> _migrateGroup(
    CategoryTransactionTarget target,
    String targetCategoryId,
  ) {
    return switch (target.businessPurpose) {
      BusinessPurpose.dailyExpense => _editService.editExpense(
        EditExpenseCommand(
          transactionId: target.transactionId,
          expenseAccountId: targetCategoryId,
        ),
      ),
      BusinessPurpose.dailyIncome => _editService.editIncome(
        EditIncomeCommand(
          transactionId: target.transactionId,
          incomeAccountId: targetCategoryId,
        ),
      ),
      BusinessPurpose.reimbursementAdvance => _editService
          .editReimbursementAdvance(
            EditReimbursementAdvanceCommand(
              transactionId: target.transactionId,
              expenseCategoryId: targetCategoryId,
            ),
          ),
      _ =>
        throw StateError(
          'Unexpected purpose ${target.businessPurpose.name} '
          'for category migration.',
        ),
    };
  }

  Future<Account> _loadActiveManageableCategory(String categoryId) async {
    final category = await _accountRepository.findById(categoryId);
    if (category == null || !category.type.isCategory) {
      throw BusinessException(LedgerErrorCode.categoryNotFound);
    }
    if (!category.isManageableCategory) {
      LedgerViolationReason.categorySystemManaged.throwException();
    }
    if (category.isArchived) {
      LedgerViolationReason.categoryArchived.throwException();
    }
    return category;
  }
}
