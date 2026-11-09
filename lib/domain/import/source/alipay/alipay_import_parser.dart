import '../../import_models.dart';
import '../../port/import_file_reader.dart';
import '../../port/import_source_parser.dart';
import '../../service/source_parsing_models.dart';
import 'alipay_bill_file_handler.dart';
import 'alipay_bill_parse_unit.dart';
import 'alipay_file_type.dart';

/// Deterministic, side-effect-free parser for an Alipay transaction CSV.
class AlipayImportParser implements ImportSourceParser {
  const AlipayImportParser({
    required ImportFileReader reader,
    AlipayBillFileHandler fileHandler = const AlipayBillFileHandler(),
    ImportPlanAssembler assembler = const ImportPlanAssembler(),
  }) : _reader = reader,
       _fileHandler = fileHandler,
       _assembler = assembler;

  static const fingerprintVersion = alipayFingerprintVersion;

  final ImportFileReader _reader;
  final AlipayBillFileHandler _fileHandler;
  final ImportPlanAssembler _assembler;

  @override
  ImportSource get source => ImportSource.alipay;

  @override
  ImportParseResult parse(ImportBundle bundle) {
    if (bundle.files.isEmpty) {
      return ImportParseResult(
        source: source,
        fatalIssues: const [
          ImportIssue(
            code: 'alipay_no_input_files',
            message: '请选择支付宝交易明细 CSV 文件。',
            severity: ImportIssueSeverity.fatal,
          ),
        ],
      );
    }
    if (bundle.files.length > 1) {
      return ImportParseResult(
        source: source,
        fileResults: [
          for (var index = 0; index < bundle.files.length; index++)
            ImportFileParseResult(
              fileIndex: index,
              fileName: bundle.files[index].name,
            ),
        ],
        fatalIssues: const [
          ImportIssue(
            code: 'alipay_multiple_files_unsupported',
            message: '一次只能导入一个支付宝交易明细文件。',
            severity: ImportIssueSeverity.fatal,
          ),
        ],
      );
    }

    final file = bundle.files.single;
    final ImportTabularFile workbook;
    try {
      workbook = _reader.read(file);
    } on ImportFileReadException catch (error) {
      final unsupported =
          error.failure == ImportFileReadFailure.unsupportedFormat;
      final issue = ImportIssue(
        code: unsupported
            ? 'alipay_unsupported_file_format'
            : 'alipay_file_decode_failed',
        message: unsupported
            ? '支付宝导入目前支持 CSV 交易明细文件。'
            : '无法读取支付宝交易明细 ${file.name}，请重新导出。',
        severity: ImportIssueSeverity.fatal,
      );
      return _fatalResult(file, issue);
    } on Exception {
      return _fatalResult(
        file,
        const ImportIssue(
          code: 'alipay_file_decode_failed',
          message: '无法读取支付宝交易明细，请重新导出。',
          severity: ImportIssueSeverity.fatal,
        ),
      );
    }

    if (workbook.sheets.isEmpty) {
      return _fatalResult(
        file,
        const ImportIssue(
          code: 'alipay_empty_file',
          message: '支付宝文件中没有可读取的工作表。',
          severity: ImportIssueSeverity.fatal,
        ),
      );
    }
    final sheet = workbook.sheets.first;
    final validationIssues = _fileHandler.validate(
      fileName: file.name,
      sheet: sheet,
    );
    if (validationIssues.isNotEmpty) {
      return ImportParseResult(
        source: source,
        fileResults: [
          ImportFileParseResult(
            fileIndex: 0,
            fileName: file.name,
            fileType: AlipayFileType.bill.descriptor,
            fatalIssues: validationIssues,
          ),
        ],
        fatalIssues: validationIssues,
      );
    }

    final fact = _fileHandler.handle(
      fileIndex: 0,
      fileName: file.name,
      sheet: sheet,
    );
    final executions = ParseUnitPlan([
      const AlipayBillParseUnit(),
    ]).execute({AlipayFileType.bill.descriptor: fact});
    return _assembler.assemble(
      source: source,
      fileResults: [
        ImportFileParseResult(
          fileIndex: 0,
          fileName: file.name,
          fileType: AlipayFileType.bill.descriptor,
        ),
      ],
      facts: [fact],
      executions: executions,
    );
  }

  ImportParseResult _fatalResult(ImportFilePayload file, ImportIssue issue) {
    return ImportParseResult(
      source: source,
      fileResults: [
        ImportFileParseResult(
          fileIndex: 0,
          fileName: file.name,
          fatalIssues: [issue],
        ),
      ],
      fatalIssues: [issue],
    );
  }
}
