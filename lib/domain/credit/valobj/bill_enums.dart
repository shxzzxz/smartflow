enum BillStatus { open, billed, settled }

enum BillItemType { consumption, installment }

/// Whether a consumption projection has crossed its statement boundary.
///
/// Installment projections are always billed because their lifecycle is driven
/// by the repayment schedule rather than the credit account's consumption
/// window.
enum BillItemBillingState { open, billed }

enum BillItemStatus { pending, partiallyPaid, paid, skipped, overpaid }
