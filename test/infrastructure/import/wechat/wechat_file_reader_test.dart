import 'dart:io';
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/source/wechat/wechat_import_parser.dart';
import 'package:smartflow/infrastructure/import/wechat/wechat_file_reader.dart';
import 'package:smartflow/infrastructure/import/wechat/wechat_category_lexicon_loader.dart';

void main() {
  const reader = WechatFileReader();

  test('locates the transaction header after the WeChat preamble', () {
    final workbook = reader.read(
      ImportFilePayload(name: '微信支付账单.xlsx', bytes: _xlsxFixture()),
    );

    final sheet = workbook.sheets.single;
    expect(sheet.name, '微信支付账单');
    expect(sheet.headers, _headers);
    expect(sheet.rows, hasLength(2));
    expect(sheet.rows.first['交易类型'], '商户消费');
    expect(sheet.rows.first['交易对方'], '示例面馆');
    expect(sheet.rows.first['商品'], '牛肉面');
    expect(sheet.rows.first['收/支'], '支出');
    expect(sheet.rows.first['交易单号'], '92222222222222222222222222220001');
    expect(sheet.rows.last['收/支'], '/');
  });

  test('loads the runtime lexicon with practical merchant keywords', () {
    final lexicon = WechatCategoryLexiconLoader.decode(_lexiconJson);

    final food = lexicon.match(
      direction: ImportCategoryKind.expense,
      product: '招牌牛肉面',
    );
    final personalCare = lexicon.match(
      direction: ImportCategoryKind.expense,
      counterparty: '示例造型工作室',
    );
    final refund = lexicon.match(
      direction: ImportCategoryKind.income,
      transactionType: '示例商户-退款',
      status: '已全额退款',
    );

    expect(food?.path, ['食品餐饮']);
    expect(personalCare?.path, ['其他']);
    expect(refund?.path, ['其他']);
  });

  test('parses a WeChat XLSX with the runtime lexicon', () {
    final lexicon = WechatCategoryLexiconLoader.decode(
      File('assets/import/wechat/category_lexicon.json').readAsStringSync(),
    );
    final result = WechatImportParser(reader: reader, lexicon: lexicon).parse(
      ImportBundle(
        files: [ImportFilePayload(name: '微信支付账单.xlsx', bytes: _xlsxFixture())],
      ),
    );

    expect(result.fatalIssues, isEmpty);
    expect(result.groups, hasLength(1));
    expect(
      result.filteredRecords.single.reasonCode,
      'wechat_direction_neutral',
    );
    final expense = result.groups.single.topLevel as ImportExpenseDraft;
    expect(expense.note, '牛肉面');
    expect(expense.category.path, '食品餐饮');
    expect(expense.paidFrom.displayName, '零钱');
  });
}

const _headers = [
  '交易时间',
  '交易类型',
  '交易对方',
  '商品',
  '收/支',
  '金额(元)',
  '支付方式',
  '当前状态',
  '交易单号',
  '商户单号',
  '备注',
];

const _lexiconJson = '''
{
  "schemaVersion": 1,
  "source": "wechat",
  "directRules": [
    {
      "id": "income_refund",
      "direction": "income",
      "priority": 1000,
      "conditions": {
        "logic": "any",
        "items": [
          {"field": "transactionType", "operator": "contains", "value": "退款"},
          {"field": "status", "operator": "equals", "value": "已全额退款"}
        ]
      },
      "categoryPath": ["其他"]
    }
  ],
  "keywordRules": [
    {
      "id": "food_noodles",
      "direction": "expense",
      "priority": 78,
      "fields": ["product"],
      "keywords": ["牛肉面", "面馆"],
      "categoryPath": ["食品餐饮"]
    },
    {
      "id": "personal_care",
      "direction": "expense",
      "priority": 72,
      "fields": ["counterparty"],
      "keywords": ["造型", "剪发"],
      "categoryPath": ["其他"]
    }
  ],
  "fallbackRules": [
    {
      "id": "income_fallback",
      "direction": "income",
      "priority": -100,
      "categoryPath": ["其他"]
    },
    {
      "id": "expense_fallback",
      "direction": "expense",
      "priority": -100,
      "categoryPath": ["其他"]
    }
  ]
}
''';

Uint8List _xlsxFixture() {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', '微信支付账单');
  final sheet = workbook['微信支付账单'];
  sheet.appendRow([TextCellValue('微信支付账单明细')]);
  sheet.appendRow([TextCellValue('微信昵称：演示用户')]);
  sheet.appendRow([TextCellValue('')]);
  sheet.appendRow([
    TextCellValue('----------------------微信支付账单明细列表--------------------'),
  ]);
  sheet.appendRow([for (final header in _headers) TextCellValue(header)]);
  sheet.appendRow([
    DateTimeCellValue.fromDateTime(DateTime(2025, 12, 24, 12, 15)),
    TextCellValue('商户消费'),
    TextCellValue('示例面馆'),
    TextCellValue('牛肉面'),
    TextCellValue('支出'),
    DoubleCellValue(12.5),
    TextCellValue('零钱'),
    TextCellValue('支付成功'),
    TextCellValue('92222222222222222222222222220001'),
    TextCellValue('DEMO-M-0001'),
    TextCellValue('/'),
  ]);
  sheet.appendRow([
    DateTimeCellValue.fromDateTime(DateTime(2025, 12, 23, 9, 30)),
    TextCellValue('零钱通转出-到示例银行(0002)'),
    TextCellValue('示例银行'),
    TextCellValue('/'),
    TextCellValue('/'),
    DoubleCellValue(0.01),
    TextCellValue('零钱通'),
    TextCellValue('支付成功'),
    TextCellValue('92222222222222222222222222220002'),
    TextCellValue('/'),
    TextCellValue('/'),
  ]);
  return Uint8List.fromList(workbook.encode()!);
}
