/// Defaults used only when an import-created account lacks user-supplied
/// product parameters. They satisfy the credit domain invariant (1..28) and
/// are intentionally easy to replace in tests or a future settings surface.
class ImportAccountCreationDefaults {
  const ImportAccountCreationDefaults({
    this.creditBillingDay = 1,
    this.creditRepaymentDay = 15,
    this.creditBillingDayToNext = true,
  });

  final int creditBillingDay;
  final int creditRepaymentDay;
  final bool creditBillingDayToNext;
}
