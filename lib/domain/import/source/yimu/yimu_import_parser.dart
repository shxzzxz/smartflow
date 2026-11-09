import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../port/import_source_parser.dart';
import '../../port/import_file_reader.dart';
import '../../service/source_parsing_models.dart';
import 'yimu_file_handlers.dart';
import 'yimu_file_type.dart';

part 'yimu_bill_parse_unit.dart';
part 'yimu_movement_parse_unit.dart';
part 'yimu_parse_support.dart';
part 'yimu_parse_units.dart';

const yimuFingerprintVersion = 1;

/// Deterministic, side-effect-free parser for the three files exported by
/// 一木记账. Physical file decoding is deliberately injected through
/// [ImportFileReader], keeping CSV/XLSX concerns outside this domain.
class YimuImportParser implements ImportSourceParser {
  YimuImportParser({
    required ImportFileReader reader,
    Iterable<YimuFileHandler> fileHandlers = const [
      YimuBillFileHandler(),
      YimuTransferFileHandler(),
      YimuDebtFileHandler(),
    ],
    Iterable<ParseUnit> additionalParseUnits = const [],
    ImportPlanAssembler assembler = const ImportPlanAssembler(),
  }) : _reader = reader,
       _assembler = assembler,
       _additionalParseUnits = List.unmodifiable(additionalParseUnits),
       _fileHandlers = {
         for (final handler in fileHandlers) handler.fileType: handler,
       };

  static const fingerprintVersion = yimuFingerprintVersion;

  final ImportFileReader _reader;
  final ImportPlanAssembler _assembler;
  final List<ParseUnit> _additionalParseUnits;
  final Map<YimuFileType, YimuFileHandler> _fileHandlers;

  @override
  ImportSource get source => ImportSource.yimu;

  @override
  ImportParseResult parse(ImportBundle bundle) {
    final fatalIssues = <ImportIssue>[];
    final factsByType = <ImportSourceFileType, SourceFileFact>{};
    final acceptedFileIndexByRole = <YimuFileType, int>{};
    final fileResults = [
      for (var index = 0; index < bundle.files.length; index++)
        _MutableImportFileParseResult(
          fileIndex: index,
          fileName: bundle.files[index].name,
        ),
    ];

    for (var fileIndex = 0; fileIndex < bundle.files.length; fileIndex++) {
      final file = bundle.files[fileIndex];
      final fileResult = fileResults[fileIndex];

      void addFileIssue(ImportIssue issue) {
        fileResult.fatalIssues.add(issue);
      }

      ImportTabularFile workbook;
      try {
        workbook = _reader.read(file);
      } on ImportFileReadException catch (error) {
        final isUnsupported =
            error.failure == ImportFileReadFailure.unsupportedFormat;
        addFileIssue(
          ImportIssue(
            code: isUnsupported
                ? 'unsupported_file_format'
                : 'file_decode_failed',
            message: isUnsupported
                ? '无法识别文件 ${file.name} 的格式。支持 CSV 和 XLSX；XLS 文件请先另存为这两种格式。'
                : '无法读取一木文件 ${file.name}，请重新导出或选择有效文件。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      } on Exception {
        addFileIssue(
          ImportIssue(
            code: 'file_decode_failed',
            message: '无法读取一木文件 ${file.name}，请重新导出或选择有效文件。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }

      if (workbook.sheets.isEmpty) {
        addFileIssue(
          ImportIssue(
            code: 'empty_workbook',
            message: '文件 ${file.name} 不包含工作表。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }
      final sheet = workbook.sheets.first;
      final role = _detectRole(file.name, sheet);
      if (role == null) {
        addFileIssue(
          ImportIssue(
            code: 'unsupported_headers',
            message: '无法识别文件 ${file.name} 的一木文件角色或表头。',
            severity: ImportIssueSeverity.fatal,
          ),
        );
        continue;
      }
      fileResult.fileType = role.descriptor;
      final handler = _fileHandlers[role];
      if (handler == null) {
        addFileIssue(
          ImportIssue(
            code: 'file_handler_missing',
            message: '${_roleName(role)}文件暂不支持解析。',
            severity: ImportIssueSeverity.fatal,
            fileType: role.descriptor,
          ),
        );
        continue;
      }
      final validationIssues = handler.validate(
        fileName: file.name,
        sheet: sheet,
      );
      final emptySheetIssues = validationIssues.where(
        (issue) => issue.code == 'empty_sheet',
      );
      if (emptySheetIssues.isNotEmpty) {
        for (final issue in emptySheetIssues) {
          addFileIssue(issue);
        }
        continue;
      }
      if (factsByType.containsKey(role.descriptor)) {
        final issue = ImportIssue(
          code: 'duplicate_file_role',
          message: '一木资料包中重复选择了${_roleName(role)}文件。',
          severity: ImportIssueSeverity.fatal,
          fileType: role.descriptor,
        );
        fatalIssues.add(issue);
        fileResult.fatalIssues.add(issue);
        final acceptedIndex = acceptedFileIndexByRole[role];
        if (acceptedIndex != null) {
          fileResults[acceptedIndex].fatalIssues.add(issue);
        }
        continue;
      }
      if (validationIssues.isNotEmpty) {
        for (final issue in validationIssues) {
          addFileIssue(issue);
        }
        continue;
      }
      try {
        factsByType[role.descriptor] = handler.handle(
          fileIndex: fileIndex,
          fileName: file.name,
          sheet: sheet,
        );
        acceptedFileIndexByRole[role] = fileIndex;
      } on Exception {
        addFileIssue(
          ImportIssue(
            code: 'file_handler_failed',
            message: '无法解析一木文件 ${file.name} 的内容，请重新导出或选择有效文件。',
            severity: ImportIssueSeverity.fatal,
            fileType: role.descriptor,
          ),
        );
      }
    }

    if (factsByType.isEmpty && fatalIssues.isEmpty) {
      fatalIssues.add(
        const ImportIssue(
          code: 'no_usable_files',
          message: '资料包中没有可解析的一木记账文件。',
          severity: ImportIssueSeverity.fatal,
        ),
      );
    }

    if (fatalIssues.isNotEmpty) {
      return ImportParseResult(
        source: ImportSource.yimu,
        fileResults: fileResults.map((result) => result.freeze()),
        fatalIssues: fatalIssues,
      );
    }

    final executions = ParseUnitPlan([
      const YimuBillParseUnit(),
      const YimuTransferParseUnit(),
      const YimuDebtParseUnit(),
      ..._additionalParseUnits,
    ]).execute(factsByType);
    return _assembler.assemble(
      source: ImportSource.yimu,
      fileResults: fileResults.map((result) => result.freeze()),
      facts: factsByType.values,
      executions: executions,
    );
  }
}
