enum AccountProfileMigrationFailureReason {
  unknownAccountType,
  unknownAccountSubtype,
  unknownAccountProfile,
  unknownCreditKind,
  nonUserAccountSignalConflict,
  accountTypeConflict,
  accountSubtypeConflict,
  accountProfileConflict,
  missingAccountProfile,
  standardizedInvariantViolation,
}

/// A non-recoverable inconsistency in the v28 account-profile migration.
///
/// The upgrade transaction must roll back when this is thrown. Its stable reason
/// and source signals allow logs and support diagnostics to identify the account
/// without parsing a free-form exception message.
final class AccountProfileMigrationError implements Exception {
  const AccountProfileMigrationError({
    required this.accountId,
    required this.reason,
    this.accountType,
    this.accountSubtype,
    this.accountProfileKey,
    this.creditKind,
    this.source,
  });

  final String accountId;
  final AccountProfileMigrationFailureReason reason;
  final String? accountType;
  final String? accountSubtype;
  final String? accountProfileKey;
  final String? creditKind;
  final String? source;

  @override
  String toString() {
    return 'AccountProfileMigrationError('
        'reason=${reason.name}, '
        'accountId=$accountId, '
        'accountType=$accountType, '
        'accountSubtype=$accountSubtype, '
        'accountProfileKey=$accountProfileKey, '
        'creditKind=$creditKind, '
        'source=$source)';
  }
}
