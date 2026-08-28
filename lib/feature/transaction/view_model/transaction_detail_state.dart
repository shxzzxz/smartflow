import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/widget/business/account/account_endpoint.dart';

import '../presentation/transaction_detail_presentation.dart';

part 'transaction_detail_state.freezed.dart';

@freezed
sealed class TransactionDetailUiState with _$TransactionDetailUiState {
  const factory TransactionDetailUiState.loaded({
    required String transactionId,
    required TransactionReadModel detail,
    required DetailBehaviorConfig behavior,
    required DetailHero hero,
    required List<DetailAllocationBreakdown> allocationBreakdowns,
    required String occurredAtText,
    required String postedAtText,
    required String createdAtText,
    required List<DetailAccountRow> accountRows,
    required DetailRefund? refund,
    required DetailReimbursement? reimbursement,
    required bool showExcludeStats,
    required bool showExcludeBudget,
    required bool excludeStats,
    required bool excludeBudget,
    required List<DetailActionButton> actionButtons,
    required bool submitting,
    String? noteText,
  }) = TransactionDetailLoaded;

  const factory TransactionDetailUiState.notFound() = TransactionDetailNotFound;
}

@freezed
abstract class DetailBehaviorConfig with _$DetailBehaviorConfig {
  const factory DetailBehaviorConfig({
    required DetailEditPermission canEditOccurredAt,
    required DetailEditPermission canEditPostedAt,
    required DetailEditPermission canEditNote,
    required DetailEditPermission canEditSettlementAccount,
    required DetailEditPermission canEditTags,
    String? bannerText,
    String? editRoute,
  }) = _DetailBehaviorConfig;
}

@freezed
abstract class DetailAccountRow with _$DetailAccountRow {
  const factory DetailAccountRow({
    required String label,
    required String accountId,
    required AccountEndpoint endpoint,
    required DetailEditPermission permission,
    AccountSelectionPurpose? editPurpose,
  }) = _DetailAccountRow;
}

@freezed
abstract class DetailEditPermission with _$DetailEditPermission {
  const factory DetailEditPermission.allowed() = DetailEditAllowed;

  const factory DetailEditPermission.denied({required String reason}) =
      DetailEditDenied;
}

@freezed
abstract class DetailRefund with _$DetailRefund {
  const factory DetailRefund({
    required bool hasRefund,
    required List<DetailSheetItem> items,
    Money? refundedTotal,
  }) = _DetailRefund;
}

@freezed
abstract class DetailReimbursement with _$DetailReimbursement {
  const factory DetailReimbursement({
    required String summaryText,
    required bool hasActivity,
    required bool isClosed,
    required List<DetailSheetItem> items,
    Money? outstanding,
  }) = _DetailReimbursement;
}

@freezed
abstract class DetailActionButton with _$DetailActionButton {
  const factory DetailActionButton({
    required DetailActionKind kind,
    required String label,
    required bool primary,
    required bool enabled,
    String? route,
    String? deniedReason,
  }) = _DetailActionButton;
}

enum DetailActionKind { refund, reimbursement, edit }

class ReimbursementSubmitInput {
  const ReimbursementSubmitInput({
    required this.amount,
    required this.occurredAt,
    required this.closeReimbursement,
    this.receiveAccountId,
    this.gapExpenseAllocations,
    this.noteText,
  });

  final Money amount;
  final DateTime occurredAt;
  final bool closeReimbursement;
  final String? receiveAccountId;
  final List<AccountAmountAllocation>? gapExpenseAllocations;
  final String? noteText;
}
