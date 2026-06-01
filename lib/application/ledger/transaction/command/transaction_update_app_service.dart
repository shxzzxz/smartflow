import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/domain/ledger/port/root_transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/ledger_update_service.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import 'transaction_command.dart';
import 'transaction_ledger_writer.dart';

abstract interface class TransactionUpdateAppService {
  Future<Result<PostedTransactionResult>> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  );

  Future<Result<PostedTransactionResult>> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  );

  Future<Result<PostedTransactionResult>> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  );
}

class TransactionUpdateAppServiceImpl implements TransactionUpdateAppService {
  TransactionUpdateAppServiceImpl({
    required TransactionRepository transactionRepository,
    required RootTransactionGroupRepository rootGroupRepository,
    required TransactionLedgerWriter ledgerWriter,
    LedgerUpdateService? ledgerUpdateService,
  }) : _ledgerWriter = ledgerWriter,
       _ledgerUpdateService =
           ledgerUpdateService ??
           LedgerUpdateService(
             transactionRepository: transactionRepository,
             rootGroupRepository: rootGroupRepository,
           );

  final TransactionLedgerWriter _ledgerWriter;
  final LedgerUpdateService _ledgerUpdateService;

  @override
  Future<Result<PostedTransactionResult>> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    return _ledgerWriter.persistUpdate(
      await _ledgerUpdateService.updateBasicInfo(
        UpdateTransactionBasicInfoInstruction(
          transactionId: command.transactionId,
          occurredAt: command.occurredAt,
          counterpartyName: command.counterpartyName,
          note: command.note,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  ) async {
    return _ledgerWriter.persistUpdate(
      await _ledgerUpdateService.updateReportingFlag(
        UpdateTransactionReportingFlagInstruction(
          transactionId: command.transactionId,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
        ),
      ),
    );
  }

  @override
  Future<Result<PostedTransactionResult>> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) async {
    return _ledgerWriter.persistUpdate(
      await _ledgerUpdateService.updateOwnership(
        UpdateTransactionOwnershipInstruction(
          transactionId: command.transactionId,
          ownership: command.ownership,
        ),
      ),
    );
  }
}
