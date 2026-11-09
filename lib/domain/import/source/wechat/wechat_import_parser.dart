import '../../import_models.dart';
import '../../port/import_file_reader.dart';
import '../../port/import_source_parser.dart';
import '../../service/source_parsing_models.dart';
import 'wechat_bill_file_handler.dart';
import 'wechat_bill_parse_unit.dart';
import 'wechat_category_lexicon.dart';
import 'wechat_file_type.dart';

class WechatImportParser implements ImportSourceParser {
  const WechatImportParser({
    required ImportFileReader reader,
    required WechatCategoryLexicon lexicon,
    WechatBillFileHandler fileHandler = const WechatBillFileHandler(),
    ImportPlanAssembler assembler = const ImportPlanAssembler(),
  }) : _reader = reader,
       _lexicon = lexicon,
       _fileHandler = fileHandler,
       _assembler = assembler;

  final ImportFileReader _reader;
  final WechatCategoryLexicon _lexicon;
  final WechatBillFileHandler _fileHandler;
  final ImportPlanAssembler _assembler;

  @override
  ImportSource get source => ImportSource.wechat;

  @override
  ImportParseResult parse(ImportBundle bundle) {
    if (bundle.files.isEmpty) {
      return _fatal('wechat_no_input_files', '请选择微信支付账单 XLSX 文件。');
    }
    if (bundle.files.length != 1) {
      return _fatal('wechat_multiple_files_unsupported', '一次只能导入一个微信支付账单文件。');
    }

    final file = bundle.files.single;
    final ImportTabularFile workbook;
    try {
      workbook = _reader.read(file);
    } on ImportFileReadException catch (error) {
      final unsupported =
          error.failure == ImportFileReadFailure.unsupportedFormat;
      return _fatal(
        unsupported
            ? 'wechat_unsupported_file_format'
            : 'wechat_file_decode_failed',
        unsupported ? '微信导入目前支持 XLSX 账单文件。' : '无法读取微信支付账单，请重新导出。',
      );
    } on Exception {
      return _fatal('wechat_file_decode_failed', '无法读取微信支付账单，请重新导出。');
    }

    if (workbook.sheets.isEmpty) {
      return _fatal('wechat_empty_file', '微信文件中没有可读取的工作表。');
    }
    final sheet = workbook.sheets.first;
    final validationIssues = _fileHandler.validate(
      fileName: file.name,
      sheet: sheet,
    );
    if (validationIssues.isNotEmpty) {
      return _fatalResult(file.name, validationIssues);
    }

    final fact = _fileHandler.handle(
      fileIndex: 0,
      fileName: file.name,
      sheet: sheet,
    );
    final executions = ParseUnitPlan([
      WechatBillParseUnit(lexicon: _lexicon),
    ]).execute({WechatFileType.bill.descriptor: fact});
    return _assembler.assemble(
      source: source,
      fileResults: [
        ImportFileParseResult(
          fileIndex: 0,
          fileName: file.name,
          fileType: WechatFileType.bill.descriptor,
        ),
      ],
      facts: [fact],
      executions: executions,
    );
  }

  ImportParseResult _fatal(String code, String message) {
    return ImportParseResult(
      source: source,
      fatalIssues: [
        ImportIssue(
          code: code,
          message: message,
          severity: ImportIssueSeverity.fatal,
        ),
      ],
    );
  }

  ImportParseResult _fatalResult(String fileName, List<ImportIssue> issues) {
    return ImportParseResult(
      source: source,
      fileResults: [
        ImportFileParseResult(
          fileIndex: 0,
          fileName: fileName,
          fileType: WechatFileType.bill.descriptor,
          fatalIssues: issues,
        ),
      ],
      fatalIssues: issues,
    );
  }
}
