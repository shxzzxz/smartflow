import 'dart:convert';
import 'dart:typed_data';

import 'package:chinese_codec/chinese_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/import_file_reader.dart';
import 'package:smartflow/domain/import/source/jd/jd_import_parser.dart';
import 'package:smartflow/infrastructure/import/jd/jd_file_reader.dart';

void main() {
  const reader = JdFileReader();

  test('reads UTF-8 BOM and locates the JD header after the preamble', () {
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(_csv)]);

    final workbook = reader.read(
      ImportFilePayload(name: '京东交易流水.csv', bytes: bytes),
    );

    final sheet = workbook.sheets.single;
    expect(sheet.name, '京东商城交易流水');
    expect(sheet.headers, hasLength(11));
    expect(sheet.headers.last, '备注');
    expect(sheet.rows, hasLength(2));
    expect(sheet.rows.first['交易时间'], '2025-01-03 08:15:21');
    expect(sheet.rows.first['交易分类'], '家居家装');
    expect(sheet.rows.first['收/支'], '支出');
    expect(sheet.rows.last['金额'], '9.99(已全额退款)');
  });

  test('decodes CP936/GBK transaction exports', () {
    final bytes = Uint8List.fromList(gbk.encode(_csv));

    final workbook = reader.read(
      ImportFilePayload(name: '京东交易流水.csv', bytes: bytes),
    );

    final row = workbook.sheets.single.rows.first;
    expect(row['交易说明'], '虚构家居用品订单');
    expect(row['收/付款方式'], '示例银行储蓄卡(0001)');
  });

  test('parses a CP936 export through the complete JD source path', () {
    final parser = const JdImportParser(reader: reader);
    final result = parser.parse(
      ImportBundle(
        files: [
          ImportFilePayload(
            name: '京东交易流水.csv',
            bytes: Uint8List.fromList(gbk.encode(_csv)),
          ),
        ],
      ),
    );

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, hasLength(1));
    expect(result.filteredRecords, hasLength(1));
    expect(
      result.groups.single.topLevel.operationKind,
      ImportOperationKind.expense,
    );
  });

  test('returns an empty sheet when the JD transaction header is absent', () {
    final workbook = reader.read(
      ImportFilePayload(
        name: '京东交易流水.csv',
        bytes: Uint8List.fromList(utf8.encode('这不是京东交易流水\n')),
      ),
    );

    expect(workbook.sheets.single.headers, isEmpty);
    expect(workbook.sheets.single.rows, isEmpty);
  });

  test('rejects unsupported physical formats', () {
    expect(
      () => reader.read(
        ImportFilePayload(name: '京东交易流水.xlsx', bytes: Uint8List(0)),
      ),
      throwsA(
        isA<ImportFileReadException>().having(
          (error) => error.failure,
          'failure',
          ImportFileReadFailure.unsupportedFormat,
        ),
      ),
    );
  });
}

const _csv = '''导出信息：
京东账号名：演示用户
申请时间：2026-01-01 09:00:00

交易时间,商户名称,交易说明,金额,收/付款方式,交易状态,收/支,交易分类,交易订单号,商家订单号,备注
2025-01-03 08:15:21,示例商户,虚构家居用品订单,10.01,示例银行储蓄卡(0001),交易成功,支出,家居家装,JD-TXN-0001,JD-M-0001,
2025-01-03 08:16:21,示例商户,虚构全额退款说明,9.99(已全额退款),示例银行储蓄卡(0001),交易成功,不计收支,其他,JD-TXN-0002,JD-M-0002,
''';
