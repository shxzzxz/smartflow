import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/import_file_reader.dart';
import 'package:smartflow/domain/import/source/wechat/wechat_category_lexicon.dart';
import 'package:smartflow/domain/import/source/wechat/wechat_import_parser.dart';

void main() {
  test('maps directions and writes only the product into the note', () {
    final result = _parser([
      _row(
        transactionType: '商户消费',
        counterparty: '示例面馆',
        product: '牛肉面',
        direction: '支出',
        status: '支付成功',
        note: '这段来源备注不应写入交易备注',
      ),
      _row(
        transactionType: '转账',
        counterparty: '示例公司',
        product: '工资',
        direction: '收入',
        status: '已到账',
        note: '这段来源备注不应写入交易备注',
      ),
    ]).parse(_bundle());

    expect(result.groups, hasLength(2));
    expect(result.groups[0].topLevel, isA<ImportExpenseDraft>());
    expect(result.groups[0].topLevel.note, '牛肉面');
    expect(result.groups[1].topLevel, isA<ImportIncomeDraft>());
    expect(result.groups[1].topLevel.note, '工资');
  });

  test('uses WeChat change as receiving account when status confirms it', () {
    final result = _parser([
      _row(
        transactionType: '转账',
        counterparty: '演示好友',
        product: '虚构转账',
        direction: '收入',
        status: '已存入零钱',
        paymentMethod: '/',
      ),
    ]).parse(_bundle());

    final income = result.groups.single.topLevel as ImportIncomeDraft;
    expect(income.receiveAccount.sourceEntityKey, 'account:零钱');
    expect(income.receiveAccount.displayName, '零钱');
  });

  test('marks a fallback category for unmatched transactions', () {
    final result = _parser([
      _row(
        direction: '支出',
        status: '支付成功',
        counterparty: '示例商户',
        product: '虚构商品',
      ),
    ]).parse(_bundle());

    expect(
      result.groups.single.issues.map((issue) => issue.code),
      contains('category_fallback'),
    );
  });

  test('assigns refund income to income other before keyword matching', () {
    final result = _parser([
      _row(
        transactionType: '示例商户-退款',
        counterparty: '示例公司',
        product: '工资',
        direction: '收入',
        status: '已全额退款',
        paymentMethod: '示例银行储蓄卡(0001)',
      ),
    ], lexiconJson: _refundLexiconJson).parse(_bundle());

    final income = result.groups.single.topLevel as ImportIncomeDraft;
    expect(income.category.path, '其他');
    expect(
      result.groups.single.issues.map((issue) => issue.code),
      isNot(contains('category_fallback')),
    );
  });
}

WechatImportParser _parser(
  List<Map<String, Object?>> rows, {
  Map<String, Object?> lexiconJson = _lexiconJson,
}) {
  return WechatImportParser(
    reader: _FakeReader(
      ImportTabularFile(
        sheets: [
          ImportTabularSheet(name: '微信支付账单', headers: _headers, rows: rows),
        ],
      ),
    ),
    lexicon: WechatCategoryLexicon.fromJson(lexiconJson),
  );
}

ImportBundle _bundle() {
  return ImportBundle(
    files: [ImportFilePayload(name: '微信支付账单流水文件.xlsx', bytes: Uint8List(0))],
  );
}

Map<String, Object?> _row({
  String transactionType = '商户消费',
  String counterparty = '示例商户',
  String product = '虚构商品',
  required String direction,
  required String status,
  String paymentMethod = '零钱',
  String note = '/',
  String transactionId = '9000000000000000000000000001',
}) {
  return {
    '交易时间': DateTime(2025, 12, 24, 12, 15),
    '交易类型': transactionType,
    '交易对方': counterparty,
    '商品': product,
    '收/支': direction,
    '金额(元)': 1.23,
    '支付方式': paymentMethod,
    '当前状态': status,
    '交易单号': transactionId,
    '商户单号': '/',
    '备注': note,
  };
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

const _lexiconJson = <String, Object?>{
  'schemaVersion': 1,
  'source': 'wechat',
  'directRules': <Object?>[],
  'keywordRules': <Object?>[],
  'fallbackRules': [
    {
      'id': 'expense_fallback_other',
      'direction': 'expense',
      'priority': -100,
      'categoryPath': ['其他'],
      'warningCode': 'category_fallback',
    },
    {
      'id': 'income_fallback_other',
      'direction': 'income',
      'priority': -100,
      'categoryPath': ['其他'],
      'warningCode': 'category_fallback',
    },
  ],
};

const _refundLexiconJson = <String, Object?>{
  'schemaVersion': 1,
  'source': 'wechat',
  'directRules': [
    {
      'id': 'income_refund',
      'direction': 'income',
      'priority': 1000,
      'conditions': {
        'logic': 'any',
        'items': [
          {'field': 'transactionType', 'operator': 'contains', 'value': '退款'},
          {'field': 'status', 'operator': 'equals', 'value': '已全额退款'},
        ],
      },
      'categoryPath': ['其他'],
    },
  ],
  'keywordRules': [
    {
      'id': 'income_salary',
      'direction': 'income',
      'priority': 80,
      'fields': ['counterparty', 'product'],
      'keywords': ['工资'],
      'categoryPath': ['工作', '工资'],
    },
  ],
  'fallbackRules': [
    {
      'id': 'income_fallback_other',
      'direction': 'income',
      'priority': -100,
      'categoryPath': ['其他'],
      'warningCode': 'category_fallback',
    },
  ],
};

class _FakeReader implements ImportFileReader {
  const _FakeReader(this.workbook);

  final ImportTabularFile workbook;

  @override
  ImportTabularFile read(ImportFilePayload file) => workbook;
}
