import '../../../../application/ledger/ledger_query_api.dart';
import '../../../../application/transaction_view/transaction_view_query_api.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/business_scene/business_scene_detail_presentation.dart';
import 'package:smartflow/widget/business/account/account_endpoint.dart';

import '../../presentation/transaction_detail_presentation.dart';
import 'transaction_detail_state.dart';

part 'transaction_detail_behavior_builder.dart';
part 'transaction_detail_ledger_builder.dart';
part 'transaction_detail_shell_builder.dart';

TransactionDetailUiState buildTransactionDetailLoadedState({
  required TransactionDetailContext context,
  required AccountLookup accountLookup,
}) {
  final shell = _buildTransactionDetailShell(context);
  final behavior = _buildTransactionDetailBehavior(
    context,
  ).copyWith(deleteMessage: _transactionDetailDeleteMessage(context));
  final ledger = _buildTransactionDetailLedger(
    context,
    accountLookup,
    behavior,
  );
  final business = presentBusinessSceneDetailContent(context);

  return TransactionDetailUiState.loaded(
    transactionId: context.transaction.id,
    context: context,
    detail: context.transaction,
    behavior: behavior,
    hero: ledger.hero,
    allocationBreakdowns: ledger.allocationBreakdowns,
    occurredAtText: shell.occurredAtText,
    postedAtText: shell.postedAtText,
    createdAtText: shell.createdAtText,
    noteText: shell.noteText,
    accountRows: ledger.accountRows,
    refund: ledger.refund,
    advance: business.advance,
    businessModules: business.modules,
    canEditReportingFlags: shell.canEditReportingFlags,
    showExcludeStats: shell.showExcludeStats,
    showExcludeBudget: shell.showExcludeBudget,
    excludeStats: shell.excludeStats,
    excludeBudget: shell.excludeBudget,
    actionButtons: _buildTransactionDetailActionButtons(context, behavior),
    submitting: false,
  );
}
