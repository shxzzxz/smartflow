import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/import_file_reader.dart';
import 'package:smartflow/domain/import/source/yimu/yimu_import_parser.dart';
import 'package:smartflow/infrastructure/import/tabular_file_readers.dart';
import 'package:smartflow/infrastructure/import/yimu/yimu_file_reader.dart';

void main() {
  test('selects CSV and XLSX readers by extension', () {
    final reader = YimuFileReader(
      csvReader: const _FakeReader(),
      xlsxReader: const _FakeReader(),
    );

    for (final name in ['账单.csv', '账单.xlsx']) {
      expect(
        reader.read(ImportFilePayload(name: name, bytes: Uint8List(0))),
        isA<ImportTabularFile>(),
      );
    }
    expect(
      () => reader.read(ImportFilePayload(name: '账单.xls', bytes: Uint8List(0))),
      throwsA(
        isA<ImportFileReadException>().having(
          (error) => error.failure,
          'failure',
          ImportFileReadFailure.unsupportedFormat,
        ),
      ),
    );
    expect(
      () => reader.read(ImportFilePayload(name: '账单.ods', bytes: Uint8List(0))),
      throwsA(
        isA<ImportFileReadException>().having(
          (error) => error.failure,
          'failure',
          ImportFileReadFailure.unsupportedFormat,
        ),
      ),
    );
  });

  test('Yimu parser explains how to import an XLS file', () {
    final result = YimuImportParser(reader: YimuFileReader()).parse(
      ImportBundle(
        files: [ImportFilePayload(name: '账单.xls', bytes: Uint8List(0))],
      ),
    );

    final issue = result.fileResults.single.fatalIssues.single;
    expect(issue.code, 'unsupported_file_format');
    expect(issue.message, contains('支持 CSV 和 XLSX'));
    expect(issue.message, contains('另存为'));
  });

  test('Yimu parser consumes CSV through the same source handler path', () {
    final parser = YimuImportParser(
      reader: YimuFileReader(
        csvReader: const CsvFileReader(),
        xlsxReader: const _FakeReader(),
      ),
    );

    final result = parser.parse(
      ImportBundle(
        files: [
          ImportFilePayload(
            name: '账单.csv',
            bytes: Uint8List.fromList(utf8.encode(_billCsv)),
          ),
        ],
      ),
    );

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, hasLength(1));
    expect(result.fileResults.single.fileType?.key, 'bill');
  });

  test('Yimu parser consumes XLSX through the same source handler path', () {
    final parser = YimuImportParser(reader: YimuFileReader());

    final result = parser.parse(
      ImportBundle(
        files: [ImportFilePayload(name: '账单.xlsx', bytes: _billXlsxFixture())],
      ),
    );

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, hasLength(1));
    expect(result.fileResults.single.fileType?.key, 'bill');
  });
}

const _billCsv = '''日期,收支类型,金额,类别,二级分类,账户,退款,报销账户,报销金额,报销明细,备注,其他
2026-04-01 09:00,收入,12.5,收入,工资,无账户,,,,,,
''';

Uint8List _billXlsxFixture() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', '账单');
  workbook['账单']
    ..appendRow([
      for (final header in [
        '日期',
        '收支类型',
        '金额',
        '类别',
        '二级分类',
        '账户',
        '退款',
        '报销账户',
        '报销金额',
        '报销明细',
        '备注',
        '其他',
      ])
        TextCellValue(header),
    ])
    ..appendRow([
      DateTimeCellValue.fromDateTime(DateTime(2026, 4, 1, 9)),
      TextCellValue('收入'),
      DoubleCellValue(12.5),
      TextCellValue('收入'),
      TextCellValue('工资'),
      TextCellValue('无账户'),
      null,
      null,
      null,
      null,
      null,
      null,
    ]);
  return Uint8List.fromList(workbook.encode()!);
}

class _FakeReader implements ImportFileReader {
  const _FakeReader();

  @override
  ImportTabularFile read(ImportFilePayload file) {
    return ImportTabularFile(
      sheets: [
        ImportTabularSheet(
          name: '测试',
          headers: const ['值'],
          rows: const [
            {'值': 'ok'},
          ],
        ),
      ],
    );
  }
}
