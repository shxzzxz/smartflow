import '../../domain/import/import_models.dart';
import '../../domain/import/import_error_code.dart';
import 'import_parser_registry.dart';

/// Parses an in-memory import bundle into a source-neutral import plan.
///
/// Source dispatch belongs at this application seam so the feature layer does
/// not call a concrete domain parser directly. The first release intentionally
/// supports only 一木记账.
abstract interface class ImportPlanAppService {
  ImportParseResult parse({
    required ImportSource source,
    required ImportBundle bundle,
  });

  ImportParseResult editDraft({
    required ImportParseResult plan,
    required int groupIndex,
    required ImportDraftEdit edit,
    int? childIndex,
  });
}

class ImportPlanAppServiceImpl implements ImportPlanAppService {
  const ImportPlanAppServiceImpl({required ImportParserRegistry parsers})
    : _parsers = parsers;

  final ImportParserRegistry _parsers;

  @override
  ImportParseResult parse({
    required ImportSource source,
    required ImportBundle bundle,
  }) {
    return _parsers.parserFor(source).parse(bundle);
  }

  @override
  ImportParseResult editDraft({
    required ImportParseResult plan,
    required int groupIndex,
    required ImportDraftEdit edit,
    int? childIndex,
  }) {
    if (groupIndex < 0 || groupIndex >= plan.groups.length) {
      throw ImportWorkflowException(
        ImportErrorCode.invalidDraftStructure,
        groupIndex: groupIndex,
      );
    }
    final group = plan.groups[groupIndex];
    final currentDraft = switch (childIndex) {
      null => group.topLevel,
      final index when index >= 0 && index < group.children.length =>
        group.children[index],
      _ =>
        throw ImportWorkflowException(
          ImportErrorCode.invalidDraftStructure,
          groupIndex: groupIndex,
        ),
    };
    final editedDraft = applyImportDraftEdit(currentDraft, edit);
    final nextChildren = [...group.children];
    final ImportTransactionDraft nextTop;
    if (childIndex == null) {
      nextTop = editedDraft;
    } else {
      nextTop = group.topLevel;
      nextChildren[childIndex] = editedDraft;
    }
    final repairedIssueCodes = _repairedIssueCodes(
      currentDraft,
      edit,
      canRepairGroupDateIssues: childIndex == null,
    );
    final groups = [...plan.groups];
    groups[groupIndex] = group.copyWith(
      topLevel: nextTop,
      children: nextChildren,
      issues: group.issues
          .where((issue) => !repairedIssueCodes.contains(issue.code))
          .toList(growable: false),
    );
    return plan.copyWith(groups: groups);
  }
}

Set<String> _repairedIssueCodes(
  ImportTransactionDraft draft,
  ImportDraftEdit edit, {
  required bool canRepairGroupDateIssues,
}) {
  final codes = <String>{};
  if (canRepairGroupDateIssues &&
      (edit.occurredAt != null || edit.postedAt != null)) {
    codes.addAll(const ['date_missing', 'date_invalid']);
  }
  if (edit.amount != null) {
    codes.addAll(_amountIssueCodes(draft));
  }
  if (edit.transferFee != null || edit.interest != null || edit.fee != null) {
    codes.addAll(const ['手续费_missing', '手续费_invalid', '手续费_negative']);
  }
  return codes;
}

Set<String> _amountIssueCodes(ImportTransactionDraft draft) {
  const amount = {'金额_missing', '金额_invalid', '金额_negative'};
  return switch (draft) {
    ImportExpenseDraft() => {...amount, 'expense_amount_zero'},
    ImportIncomeDraft() => {...amount, 'income_amount_invalid'},
    ImportRefundDraft() => const {
      '退款_missing',
      '退款_invalid',
      '退款_negative',
      'refund_negative',
    },
    ImportReimbursementAdvanceDraft() => amount,
    ImportReimbursementReceiptDraft() => const {
      '报销明细金额_missing',
      '报销明细金额_invalid',
      '报销明细金额_negative',
    },
    ImportReimbursementCloseDraft() => const {
      '报销金额_missing',
      '报销金额_invalid',
      '报销金额_negative',
    },
    ImportTransferDraft() => {...amount, 'transfer_amount_invalid'},
    ImportRepaymentDraft() => {...amount, 'repayment_principal_invalid'},
    ImportInterestExpenseDraft() => const {
      '手续费_missing',
      '手续费_invalid',
      '手续费_negative',
    },
    ImportBorrowingDraft() => {...amount, 'borrowing_amount_invalid'},
    ImportOpeningBalanceDraft() => {...amount, 'opening_amount_invalid'},
  };
}
