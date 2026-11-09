import 'dart:convert';
import 'dart:typed_data';

import 'package:chinese_codec/chinese_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/import_file_reader.dart';
import 'package:smartflow/domain/import/source/alipay/alipay_import_parser.dart';
import 'package:smartflow/infrastructure/import/alipay/alipay_file_reader.dart';

void main() {
  const reader = AlipayFileReader();

  test(
    'reads UTF-8 BOM and locates the transaction header after the preamble',
    () {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(_csv),
      ]);

      final workbook = reader.read(
        ImportFilePayload(name: '支付宝交易明细.csv', bytes: bytes),
      );

      final sheet = workbook.sheets.single;
      expect(sheet.name, '支付宝交易明细');
      expect(sheet.headers, hasLength(12));
      expect(sheet.headers.last, '备注');
      expect(sheet.rows, hasLength(1));
      expect(sheet.rows.single['交易时间'], '2025-01-03 08:15:21');
      expect(sheet.rows.single['交易分类'], '餐饮美食');
      expect(sheet.rows.single['收/支'], '支出');
    },
  );

  test('decodes CP936/GBK transaction exports', () {
    final bytes = Uint8List.fromList(gbk.encode(_csv));

    final workbook = reader.read(
      ImportFilePayload(name: '支付宝交易明细.csv', bytes: bytes),
    );

    final row = workbook.sheets.single.rows.single;
    expect(row['交易对方'], '示例早餐店');
    expect(row['商品说明'], '虚构早餐套餐');
    expect(row['收/付款方式'], '花呗');
  });

  test('parses a CP936 export through the complete Alipay source path', () {
    final parser = const AlipayImportParser(reader: reader);
    final result = parser.parse(
      ImportBundle(
        files: [
          ImportFilePayload(
            name: '支付宝交易明细.csv',
            bytes: Uint8List.fromList(gbk.encode(_csv)),
          ),
        ],
      ),
    );

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, hasLength(1));
    expect(result.filteredRecords, isEmpty);
    expect(
      result.groups.single.topLevel.operationKind,
      ImportOperationKind.expense,
    );
  });

  test('returns an empty sheet when the transaction header is absent', () {
    final workbook = reader.read(
      ImportFilePayload(
        name: '支付宝交易明细.csv',
        bytes: Uint8List.fromList(utf8.encode('这不是支付宝交易明细\n')),
      ),
    );

    expect(workbook.sheets.single.headers, isEmpty);
    expect(workbook.sheets.single.rows, isEmpty);
  });

  test('rejects unsupported physical formats', () {
    expect(
      () => reader.read(
        ImportFilePayload(name: '支付宝交易明细.xlsx', bytes: Uint8List(0)),
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

const _csv = '''支付宝交易明细查询
导出信息
姓名:演示用户
支付宝账户:demo@example.com
------------------------支付宝支付科技有限公司  电子客户回单------------------------
交易时间,交易分类,交易对方,对方账号,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注,
2025-01-03 08:15:21,餐饮美食,示例早餐店,shop001@example.com,虚构早餐套餐,支出,10.01,花呗,交易成功,20250103081521000001,DEMO-M-0001,,
''';
