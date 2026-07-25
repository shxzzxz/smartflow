import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/service/import_target_compatibility.dart';

void main() {
  test('ordinary transfers require fund accounts on both sides', () {
    final requirements = ImportTargetCompatibilityPolicy.requirementsForDraft(
      ImportTransferDraft(
        amount: Money.parse('1'),
        fromAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:from',
          displayName: 'From',
        ),
        toAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:to',
          displayName: 'To',
        ),
        occurredAt: DateTime(2026, 1, 1),
      ),
    ).toList(growable: false);

    expect(requirements.map((requirement) => requirement.sourceEntityKey), [
      'account:from',
      'account:to',
    ]);
    expect(
      requirements.every(
        (requirement) =>
            requirement.descriptors.length == 1 &&
            requirement.descriptors.contains(
              ImportTargetDescriptor.fundAccount,
            ),
      ),
      isTrue,
    );
  });

  test('source constraints narrow liability targets to loans', () {
    const loanEntity = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: 'account:loan',
      displayName: 'Loan',
      allowedTargetDescriptors: {ImportTargetDescriptor.loanAccount},
    );

    expect(
      ImportTargetCompatibilityPolicy.supportsEntity(
        loanEntity,
        ImportTargetDescriptor.loanAccount,
      ),
      isTrue,
    );
    expect(
      ImportTargetCompatibilityPolicy.supportsEntity(
        loanEntity,
        ImportTargetDescriptor.creditAccount,
      ),
      isFalse,
    );
  });
}
