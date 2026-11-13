part of 'yimu_import_parser.dart';

class YimuBillParseUnit implements ParseUnit {
  const YimuBillParseUnit();

  @override
  String get key => 'yimu.bill';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    YimuFileType.bill.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    final filtered = <ImportFilteredRecord>[];
    _parseBillRows(
      facts[YimuFileType.bill.descriptor]!.records.whereType<YimuBillRecord>(),
      entities: entities,
      groups: groups,
      filtered: filtered,
    );
    return ParseUnitResult(
      derivedEntities: entities.values,
      groups: groups,
      filteredRecords: filtered,
    );
  }
}

/// Default transfer ParseUnit for the Yimu source.
class YimuTransferParseUnit implements ParseUnit {
  const YimuTransferParseUnit();

  @override
  String get key => 'yimu.transfer';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    YimuFileType.transfer.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    _parseTransferRows(
      facts[YimuFileType.transfer.descriptor]!.records
          .whereType<YimuTransferRecord>(),
      role: YimuFileType.transfer,
      entities: entities,
      groups: groups,
    );
    return ParseUnitResult(derivedEntities: entities.values, groups: groups);
  }
}

/// Default debt ParseUnit for the Yimu source.
class YimuDebtParseUnit implements ParseUnit {
  const YimuDebtParseUnit();

  @override
  String get key => 'yimu.debt';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    YimuFileType.debt.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    final entities = <String, ImportSourceEntity>{};
    final groups = <ImportTransactionGroupDraft>[];
    _parseTransferRows(
      facts[YimuFileType.debt.descriptor]!.records.whereType<YimuDebtRecord>(),
      role: YimuFileType.debt,
      entities: entities,
      groups: groups,
    );
    return ParseUnitResult(derivedEntities: entities.values, groups: groups);
  }
}

class _MutableImportFileParseResult {
  _MutableImportFileParseResult({
    required this.fileIndex,
    required this.fileName,
  });

  final int fileIndex;
  final String fileName;
  ImportSourceFileType? fileType;
  final List<ImportIssue> fatalIssues = [];

  ImportFileParseResult freeze() {
    return ImportFileParseResult(
      fileIndex: fileIndex,
      fileName: fileName,
      fileType: fileType,
      fatalIssues: fatalIssues,
    );
  }
}

class _AdvanceDetail {
  const _AdvanceDetail({
    required this.date,
    required this.account,
    required this.amount,
  });

  final DateTime date;
  final ImportAccountReference account;
  final Money amount;
}
