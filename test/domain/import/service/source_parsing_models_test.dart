import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/service/source_parsing_models.dart';

void main() {
  const source = ImportSource.yimu;
  const a = ImportSourceFileType(source: source, key: 'a', label: 'A');
  const b = ImportSourceFileType(source: source, key: 'b', label: 'B');
  const c = ImportSourceFileType(source: source, key: 'c', label: 'C');

  test('runs an independent A unit and isolates a partial B+C joined unit', () {
    final executions = ParseUnitPlan([
      _ParseUnit(key: 'a', requiredFileTypes: {a}),
      _ParseUnit(key: 'bc', requiredFileTypes: {b, c}),
    ]).execute({a: _fact(a, 0), b: _fact(b, 1)});

    expect(executions.map((execution) => execution.unit.key), ['a', 'bc']);
    expect(executions.first.result.issues, isEmpty);
    expect(
      executions.last.result.issues.single.code,
      'parse_unit_companion_file_missing',
    );
    expect(executions.last.result.issues.single.message, contains('C'));
  });

  test('runs a B+C joined unit only after both file facts are available', () {
    final executions = ParseUnitPlan([
      _ParseUnit(key: 'a', requiredFileTypes: {a}),
      _ParseUnit(key: 'bc', requiredFileTypes: {b, c}),
    ]).execute({a: _fact(a, 0), b: _fact(b, 1), c: _fact(c, 2)});

    expect(executions, hasLength(2));
    expect(executions.last.result.issues, isEmpty);
  });

  test(
    'assembler keeps an empty descriptor intersection as an explicit conflict',
    () {
      const credit = ImportSourceEntity(
        source: source,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:same',
        displayName: '同名账户',
        allowedTargetDescriptors: {ImportTargetDescriptor.creditAccount},
      );
      const loan = ImportSourceEntity(
        source: source,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:same',
        displayName: '同名账户',
        allowedTargetDescriptors: {ImportTargetDescriptor.loanAccount},
      );

      final result = const ImportPlanAssembler().assemble(
        source: source,
        fileResults: const [],
        facts: [
          SourceFileFact(
            fileIndex: 0,
            fileName: 'A.xls',
            fileType: a,
            localEntities: const [credit],
          ),
          SourceFileFact(
            fileIndex: 1,
            fileName: 'B.xls',
            fileType: b,
            localEntities: const [loan],
          ),
        ],
        executions: const [],
      );

      final entity = result.sourceEntities.single;
      expect(entity.allowedTargetDescriptors, isEmpty);
      expect(entity.hasTargetDescriptorConflict, isTrue);
    },
  );

  test('assembler attaches ParseUnit issues to the groups produced by it', () {
    const issue = ImportIssue(
      code: 'joined_rule_blocked',
      message: 'joined rule failed',
      severity: ImportIssueSeverity.blocking,
    );
    final group = ImportTransactionGroupDraft(
      topLevel: ImportOpeningBalanceDraft(
        amount: Money.parse('1'),
        liabilityAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:loan',
          displayName: 'Loan',
        ),
        occurredAt: DateTime(2026, 1, 1),
      ),
      sourceOperationFingerprint: 'joined-fingerprint',
      fingerprintVersion: 1,
    );

    final result = const ImportPlanAssembler().assemble(
      source: source,
      fileResults: const [],
      facts: const [],
      executions: [
        ParseUnitExecution(
          unit: _ParseUnit(key: 'bc', requiredFileTypes: {b, c}),
          result: ParseUnitResult(groups: [group], issues: const [issue]),
        ),
      ],
    );

    expect(result.issues, contains(issue));
    expect(result.groups.single.issues, contains(issue));
    expect(result.groups.single.hasBlockingIssues, isTrue);
  });

  test('file-level fact issues block groups produced from that fact', () {
    const issue = ImportIssue(
      code: 'file_structure_invalid',
      message: 'file structure is invalid',
      severity: ImportIssueSeverity.blocking,
      fileType: b,
    );
    final group = ImportTransactionGroupDraft(
      topLevel: ImportOpeningBalanceDraft(
        amount: Money.parse('1'),
        liabilityAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:loan',
          displayName: 'Loan',
        ),
        occurredAt: DateTime(2026, 1, 1),
      ),
      sourceOperationFingerprint: 'file-issue-fingerprint',
      fingerprintVersion: 1,
    );
    final executions = ParseUnitPlan([
      _ParseUnit(
        key: 'b',
        requiredFileTypes: {b},
        result: ParseUnitResult(groups: [group]),
      ),
    ]).execute({
      b: SourceFileFact(
        fileIndex: 0,
        fileName: 'B.xls',
        fileType: b,
        issues: const [issue],
      ),
    });

    final result = const ImportPlanAssembler().assemble(
      source: source,
      fileResults: const [],
      facts: [
        SourceFileFact(
          fileIndex: 0,
          fileName: 'B.xls',
          fileType: b,
          issues: const [issue],
        ),
      ],
      executions: executions,
    );

    expect(
      result.issues.where((item) => item.code == issue.code),
      hasLength(1),
    );
    expect(result.groups.single.issues, contains(issue));
    expect(result.groups.single.hasBlockingIssues, isTrue);
  });

  test('keeps same-looking issues distinct across files and severities', () {
    const bIssue = ImportIssue(
      code: 'date_invalid',
      message: 'invalid date',
      severity: ImportIssueSeverity.warning,
      fileType: b,
    );
    const cIssue = ImportIssue(
      code: 'date_invalid',
      message: 'invalid date',
      severity: ImportIssueSeverity.blocking,
      fileType: c,
    );
    final result = const ImportPlanAssembler().assemble(
      source: source,
      fileResults: const [],
      facts: [
        SourceFileFact(
          fileIndex: 0,
          fileName: 'B.xls',
          fileType: b,
          issues: const [bIssue],
        ),
        SourceFileFact(
          fileIndex: 1,
          fileName: 'C.xls',
          fileType: c,
          issues: const [cIssue],
        ),
      ],
      executions: const [],
    );

    expect(result.issues, containsAll(const [bIssue, cIssue]));
    expect(result.issues, hasLength(2));
  });

  test('deduplicates a repeated operation issue on the first group', () {
    final groups = [
      for (var index = 0; index < 3; index++)
        ImportTransactionGroupDraft(
          topLevel: ImportOpeningBalanceDraft(
            amount: Money.parse('1'),
            liabilityAccount: const ImportAccountReference.source(
              sourceEntityKey: 'account:loan',
              displayName: 'Loan',
            ),
            occurredAt: DateTime(2026, 1, 1),
          ),
          sourceOperationKey: 'same-key',
          sourceOperationFingerprint: 'fingerprint-$index',
          fingerprintVersion: 1,
        ),
    ];
    final result = const ImportPlanAssembler().assemble(
      source: source,
      fileResults: const [],
      facts: const [],
      executions: [
        ParseUnitExecution(
          unit: _ParseUnit(key: 'a', requiredFileTypes: {a}),
          result: ParseUnitResult(groups: groups),
        ),
      ],
    );

    for (final group in result.groups) {
      expect(
        group.issues.where(
          (issue) => issue.code == 'duplicate_source_operation_key',
        ),
        hasLength(1),
      );
    }
  });
}

SourceFileFact _fact(ImportSourceFileType type, int index) {
  return SourceFileFact(
    fileIndex: index,
    fileName: '${type.label}.xls',
    fileType: type,
  );
}

class _ParseUnit implements ParseUnit {
  const _ParseUnit({
    required this.key,
    required this.requiredFileTypes,
    this.result,
  });

  @override
  final String key;

  @override
  final Set<ImportSourceFileType> requiredFileTypes;

  final ParseUnitResult? result;

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    return result ?? ParseUnitResult();
  }
}
