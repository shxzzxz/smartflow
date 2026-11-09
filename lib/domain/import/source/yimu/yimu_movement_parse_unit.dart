part of 'yimu_import_parser.dart';

void _parseTransferRows(
  Iterable<YimuAccountMovementRecord> records, {
  required YimuFileType role,
  required Map<String, ImportSourceEntity> entities,
  required List<ImportTransactionGroupDraft> groups,
}) {
  for (final record in records) {
    final rowNumber = record.rowNumber;
    final issues = [...record.issues];
    final type = record.kind;
    final actualDate = record.occurredAt;
    final postedAt = record.postedAt;
    final actualAmount = record.amount;
    final note = record.note;
    final fromValue = record.fromAccountName;
    final toValue = record.toAccountName;
    final operationKey = record.sourceOperationKey;
    final canonical = <String>[
      'role=${role.name}',
      'type=${_normalized(type)}',
      'date=${_canonicalDate(actualDate)}',
      'posted=${_canonicalDate(postedAt)}',
      'from=${_normalized(fromValue)}',
      'to=${_normalized(toValue)}',
      'amount=${actualAmount.minorUnits}',
      'fee=${_normalized(record.feeSource)}',
      'note=${_normalized(note)}',
    ];

    if (type == '转账') {
      final from = _accountReference(
        fromValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'from',
        fieldName: '转出账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
      );
      final to = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
      );
      final fee = record.feeAmount;
      if (actualAmount.minorUnits <= 0) {
        issues.add(
          _blocking('transfer_amount_invalid', '转账金额必须大于零。', rowNumber),
        );
      }
      if ((fee?.minorUnits ?? 0) < 0) {
        issues.add(
          _blocking('transfer_fee_negative', '转账手续费不能为负数。', rowNumber),
        );
      }
      groups.add(
        _group(
          ImportTransferDraft(
            amount: actualAmount.abs(),
            fromAccount: from,
            toAccount: to,
            feeAmount: fee,
            occurredAt: actualDate,
            postedAt: postedAt,
            note: note,
          ),
          fileType: role,
          issues: issues,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
      continue;
    }

    if (type == '还款') {
      final paidFrom = _accountReference(
        fromValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'from',
        fieldName: '转出账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
      );
      final liability = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors: role == YimuFileType.debt
            ? const {
                ImportTargetDescriptor.payableAccount,
                ImportTargetDescriptor.loanAccount,
              }
            : const {
                ImportTargetDescriptor.payableAccount,
                ImportTargetDescriptor.creditAccount,
                ImportTargetDescriptor.loanAccount,
              },
        preferredTargetDescriptor: role == YimuFileType.debt
            ? ImportTargetDescriptor.payableAccount
            : ImportTargetDescriptor.creditAccount,
      );
      final fee = record.feeAmount;
      final interest = fee != null && fee.minorUnits > 0 ? fee : null;
      final discount = fee != null && fee.minorUnits < 0 ? fee.abs() : null;
      if (actualAmount.minorUnits == 0 && (fee?.minorUnits ?? 0) > 0) {
        groups.add(
          _group(
            ImportInterestExpenseDraft(
              amount: fee!,
              paidFrom: paidFrom,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      } else {
        if (actualAmount.minorUnits <= 0) {
          issues.add(
            _blocking('repayment_principal_invalid', '还款本金必须大于零。', rowNumber),
          );
        }
        groups.add(
          _group(
            ImportRepaymentDraft(
              principal: actualAmount.abs(),
              interest: interest,
              discount: discount,
              liabilityAccount: liability,
              paidFrom: paidFrom,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      }
      continue;
    }

    if (type == '借入' && role == YimuFileType.debt) {
      final liability = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors: const {
          ImportTargetDescriptor.payableAccount,
          ImportTargetDescriptor.loanAccount,
        },
        preferredTargetDescriptor: ImportTargetDescriptor.payableAccount,
      );
      final isOpening = fromValue == null || _isExplicitNone(fromValue);
      if (isOpening) {
        if (actualAmount.minorUnits <= 0) {
          issues.add(
            _blocking('opening_amount_invalid', '债务期初金额必须大于零。', rowNumber),
          );
        }
        groups.add(
          _group(
            ImportOpeningBalanceDraft(
              amount: actualAmount.abs(),
              account: liability,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      } else {
        final receive = _accountReference(
          fromValue,
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
          fileType: role,
          fieldKey: 'from',
          fieldName: '转出账户',
          allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
          preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
        );
        if (actualAmount.minorUnits <= 0) {
          issues.add(
            _blocking('borrowing_amount_invalid', '借入金额必须大于零。', rowNumber),
          );
        }
        groups.add(
          _group(
            ImportBorrowingDraft(
              amount: actualAmount.abs(),
              liabilityAccount: liability,
              receiveAccount: receive,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      }
      continue;
    }

    if (type == '借出' && role == YimuFileType.debt) {
      final receivable = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors: const {
          ImportTargetDescriptor.receivableAccount,
        },
        preferredTargetDescriptor: ImportTargetDescriptor.receivableAccount,
      );
      final isOpening = fromValue == null || _isExplicitNone(fromValue);
      if (actualAmount.minorUnits <= 0) {
        issues.add(
          _blocking(
            isOpening ? 'opening_amount_invalid' : 'lending_amount_invalid',
            isOpening ? '债务期初金额必须大于零。' : '借出金额必须大于零。',
            rowNumber,
          ),
        );
      }
      if (isOpening) {
        groups.add(
          _group(
            ImportOpeningBalanceDraft(
              amount: actualAmount.abs(),
              account: receivable,
              accountKind: ImportOpeningBalanceAccountKind.receivable,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      } else {
        final paidFrom = _accountReference(
          fromValue,
          entities: entities,
          issues: issues,
          rowNumber: rowNumber,
          required: true,
          fileType: role,
          fieldKey: 'from',
          fieldName: '转出账户',
          allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
          preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
        );
        groups.add(
          _group(
            ImportLendingDraft(
              amount: actualAmount.abs(),
              receivableAccount: receivable,
              paidFrom: paidFrom,
              occurredAt: actualDate,
              postedAt: postedAt,
              note: note,
            ),
            fileType: role,
            issues: issues,
            operationKey: operationKey,
            canonical: canonical,
          ),
        );
      }
      continue;
    }

    if (type == '收款' && role == YimuFileType.debt) {
      final receive = _accountReference(
        fromValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'from',
        fieldName: '转出账户',
        allowedTargetDescriptors: const {ImportTargetDescriptor.fundAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.fundAccount,
      );
      final receivable = _accountReference(
        toValue,
        entities: entities,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
        fileType: role,
        fieldKey: 'to',
        fieldName: '转入账户',
        allowedTargetDescriptors: const {
          ImportTargetDescriptor.receivableAccount,
        },
        preferredTargetDescriptor: ImportTargetDescriptor.receivableAccount,
      );
      if (actualAmount.minorUnits <= 0) {
        issues.add(
          _blocking('collection_principal_invalid', '收款本金必须大于零。', rowNumber),
        );
      }
      groups.add(
        _group(
          ImportReceivableCollectionDraft(
            principal: actualAmount.abs(),
            receivableAccount: receivable,
            receiveAccount: receive,
            occurredAt: actualDate,
            postedAt: postedAt,
            note: note,
          ),
          fileType: role,
          issues: issues,
          operationKey: operationKey,
          canonical: canonical,
        ),
      );
      continue;
    }

    issues.add(
      _blocking(
        'unsupported_transfer_type',
        '${_roleName(role)}文件类型不受支持。',
        rowNumber,
      ),
    );
    groups.add(
      _group(
        ImportTransferDraft(
          amount: actualAmount.abs(),
          fromAccount: ImportAccountReference.unresolved(),
          toAccount: ImportAccountReference.unresolved(),
          occurredAt: actualDate,
          note: note,
        ),
        fileType: role,
        issues: issues,
        operationKey: operationKey,
        canonical: canonical,
      ),
    );
  }
}
