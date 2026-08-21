import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/yimu_workbook_reader.dart';
import 'package:smartflow/domain/import/service/source_parsing_models.dart';
import 'package:smartflow/domain/import/service/yimu_file_type.dart';
import 'package:smartflow/domain/import/service/yimu_import_parser.dart';

void main() {
  test('turns a refunded expense into a gross expense and refund child', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-04-04 12:55',
          '收支类型': '支出',
          '金额': -68.0,
          '类别': '餐饮',
          '二级分类': '生鲜',
          '账户': '资产账户A',
          '退款': 2.0,
          '备注': '',
          '其他': '',
        },
      ],
    ).parse(_bundle());

    expect(result.fatalIssues, isEmpty);
    expect(result.fileResults.map((file) => file.fileType?.key), [
      'bill',
      'transfer',
      'debt',
    ]);
    expect(result.fileResults.every((file) => !file.hasFatalIssues), isTrue);
    final groups = _groups(result);
    expect(groups, hasLength(1));
    final group = groups.single;
    final expense = group.topLevel;
    expect(expense, isA<ImportExpenseDraft>());
    expect((expense as ImportExpenseDraft).amount, Money.parse('70'));
    expect(group.children, hasLength(1));
    expect(group.children.single, isA<ImportRefundDraft>());
    expect(
      (group.children.single as ImportRefundDraft).amount,
      Money.parse('2'),
    );
    expect(expense.paidFrom.sourceEntityKey, 'account:资产账户a');
    expect(expense.category.sourceEntityKey, 'category:expense:餐饮 / 生鲜');
    expect(group.sourceOperationKey, isNull);
    expect(group.sourceOperationFingerprint, isNotEmpty);
  });

  test('keeps reimbursement children in receipt then close order', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-03-17 22:57',
          '收支类型': '支出',
          '金额': -150.0,
          '类别': '居家生活',
          '二级分类': '电费',
          '账户': '负债账户A',
          '报销账户': '报销账户A',
          '报销金额': 100.0,
          '报销明细': '2026/03/17资产账户B到账50.0\n2026/03/18资产账户B到账50.0',
          '备注': '',
          '其他': '',
        },
      ],
    ).parse(_bundle());

    final group = _groups(result).single;
    expect(group.topLevel, isA<ImportReimbursementAdvanceDraft>());
    expect(group.children, hasLength(2));
    expect(group.children[0], isA<ImportReimbursementReceiptDraft>());
    expect(group.children[1], isA<ImportReimbursementCloseDraft>());
    final receipt = group.children[0] as ImportReimbursementReceiptDraft;
    final close = group.children[1] as ImportReimbursementCloseDraft;
    expect(receipt.amount, Money.parse('50'));
    expect(close.actualReceivedAmount, Money.parse('50'));
    expect(receipt.occurredAt, DateTime(2026, 3, 17));
    expect(close.occurredAt, DateTime(2026, 3, 18));
  });

  test('filters generated reimbursement gaps and repayment interest rows', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-02-27 16:40',
          '收支类型': '收入',
          '金额': 1.0,
          '类别': '收入',
          '二级分类': '其他',
          '账户': '',
          '备注': '报销差额：自动生成',
          '其他': '',
        },
        {
          '日期': '2026-03-19 10:13',
          '收支类型': '支出',
          '金额': -30.0,
          '类别': '其他',
          '二级分类': '利息',
          '账户': '资产账户A',
          '备注': '负债账户A 还款利息',
          '其他': '',
        },
      ],
    ).parse(_bundle());

    expect(_groups(result), isEmpty);
    expect(result.filteredRecords, hasLength(2));
    expect(
      result.filteredRecords.map((record) => record.reasonCode),
      containsAll([
        'reimbursement_gap_generated',
        'repayment_interest_generated',
      ]),
    );
  });

  test('filters repayment discount bills and maps signed repayment fees', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-05-20 13:14',
          '收支类型': '收入',
          '金额': 0.05,
          '类别': '收入',
          '二级分类': '其他',
          '账户': '中国银行',
          '备注': '美团月付 还款优惠',
          '其他': '',
        },
      ],
      transferRows: [
        {
          '日期': '2026-05-19 13:14',
          '类型': '还款',
          '转出账户': '中国银行',
          '转入账户': '美团月付',
          '金额': 100.0,
          '手续费': 2.0,
          '备注': '',
        },
        {
          '日期': '2026-05-20 13:14',
          '类型': '还款',
          '转出账户': '中国银行',
          '转入账户': '美团月付',
          '金额': 5020.33,
          '手续费': -0.05,
          '备注': '',
        },
      ],
    ).parse(_bundle(names: const ['账单.xls', '转账.xls']));

    expect(
      result.filteredRecords.map((record) => record.reasonCode),
      contains('repayment_discount_generated'),
    );
    final repayments =
        _groups(result)
            .map((group) => group.topLevel)
            .whereType<ImportRepaymentDraft>()
            .toList();
    expect(repayments, hasLength(2));
    expect(repayments[0].interest, Money.parse('2'));
    expect(repayments[0].discount, isNull);
    expect(repayments[1].interest, isNull);
    expect(repayments[1].discount, Money.parse('0.05'));
    expect(repayments[1].amount, Money.parse('5020.28'));
  });

  test(
    'maps debt rows to repayment, interest expense, borrowing, and opening',
    () {
      final result = _parser(
        debtRows: [
          {
            '日期': '2026-03-19 10:13',
            '类型': '还款',
            '转出账户': '资产账户A',
            '转入账户': '负债账户A',
            '金额': 800.0,
            '手续费': 30.0,
            '备注': '',
          },
          {
            '日期': '2026-03-19 09:41',
            '类型': '还款',
            '转出账户': '资产账户A',
            '转入账户': '负债账户A',
            '金额': 0.0,
            '手续费': 120.0,
            '备注': '',
          },
          {
            '日期': '2026-01-29 16:36',
            '类型': '借入',
            '转出账户': '资产账户A',
            '转入账户': '负债账户A',
            '金额': 30000.0,
            '手续费': 0.0,
            '备注': '',
          },
          {
            '日期': '2026-01-17 23:59',
            '类型': '借入',
            '转出账户': '无账户',
            '转入账户': '负债账户A',
            '金额': 10000.0,
            '手续费': 0.0,
            '备注': '',
          },
        ],
      ).parse(_bundle());

      final groups = _groups(result);
      expect(groups, hasLength(4));
      expect(groups[0].topLevel, isA<ImportRepaymentDraft>());
      final repayment = groups[0].topLevel as ImportRepaymentDraft;
      expect(repayment.principal, Money.parse('800'));
      expect(repayment.interest, Money.parse('30'));
      expect(groups[1].topLevel, isA<ImportInterestExpenseDraft>());
      expect(groups[2].topLevel, isA<ImportBorrowingDraft>());
      expect(groups[3].topLevel, isA<ImportOpeningBalanceDraft>());
    },
  );

  test('treats an empty borrowing source account as debt opening balance', () {
    final result = _parser(
      debtRows: [
        {
          '日期': '2026-01-17 23:59',
          '类型': '借入',
          '转出账户': '',
          '转入账户': '负债账户A',
          '金额': 10000.0,
          '手续费': 0.0,
        },
      ],
    ).parse(_bundle());

    expect(_groups(result).single.topLevel, isA<ImportOpeningBalanceDraft>());
    expect(
      result.sourceAccounts.map((account) => account.displayName),
      isNot(contains('无账户')),
    );
  });

  test('keeps posted time and falls back to occurred time when absent', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-04-06 12:49',
          '入账时间': '2026-04-07 08:30',
          '收支类型': '支出',
          '金额': -25.0,
          '类别': '餐饮',
          '账户': '现金',
        },
        {
          '日期': '2026-04-08 09:00',
          '收支类型': '收入',
          '金额': 100.0,
          '类别': '收入',
          '账户': '现金',
        },
      ],
    ).parse(_bundle());

    final groups = _groups(result);
    expect(groups[0].topLevel.postedAt, DateTime(2026, 4, 7, 8, 30));
    expect(groups[1].topLevel.postedAt, groups[1].topLevel.occurredAt);
  });

  test('keeps valid files when another selected file cannot be decoded', () {
    final result = _parser(
      billRows: [
        {
          '日期': '',
          '收支类型': '支出',
          '金额': -1.0,
          '类别': '餐饮',
          '二级分类': '',
          '账户': '现金',
        },
      ],
      includeTransfer: false,
    ).parse(_bundle());

    expect(result.fatalIssues, isEmpty);
    final failedFile = result.fileResults.singleWhere(
      (file) => file.fileName == '转账.xls',
    );
    expect(failedFile.hasFatalIssues, isTrue);
    expect(
      failedFile.fatalIssues.map((issue) => issue.code),
      contains('file_decode_failed'),
    );
    expect(result.groups, isNotEmpty);
    expect(
      result.groups.expand((group) => group.issues).map((issue) => issue.code),
      contains('date_missing'),
    );
  });

  test('allows bill, transfer, and debt files to parse independently', () {
    final parser = _parser();

    final bill = parser.parse(_bundle(names: const ['账单.xls']));
    final transfer = parser.parse(_bundle(names: const ['转账.xls']));
    final debt = parser.parse(_bundle(names: const ['债务.xls']));

    expect(bill.fatalIssues, isEmpty);
    expect(transfer.fatalIssues, isEmpty);
    expect(debt.fatalIssues, isEmpty);
    expect(bill.groups.single.topLevel, isA<ImportIncomeDraft>());
    expect(transfer.groups.single.topLevel, isA<ImportTransferDraft>());
    expect(debt.groups.single.topLevel, isA<ImportBorrowingDraft>());
    expect(bill.sourceCategories, isNotEmpty);
    expect(transfer.sourceCategories, isEmpty);
    expect(debt.sourceCategories, isEmpty);
  });

  test(
    'keeps debt liability targets compatible with payable and loan accounts',
    () {
      final result = _parser(
        debtRows: [
          {
            '日期': '2026-01-29 16:36',
            '类型': '借入',
            '转出账户': '到账资产',
            '转入账户': '来源贷款',
            '金额': 30000.0,
            '手续费': 0.0,
          },
          {
            '日期': '2026-02-01 09:00',
            '类型': '还款',
            '转出账户': '现金',
            '转入账户': '来源贷款',
            '金额': 1000.0,
            '手续费': 10.0,
          },
        ],
      ).parse(_bundle(names: const ['债务.xls']));

      final entity = result.sourceAccounts.singleWhere(
        (candidate) => candidate.displayName == '来源贷款',
      );
      expect(
        entity.allowedTargetDescriptors,
        contains(ImportTargetDescriptor.loanAccount),
      );
      expect(
        entity.preferredTargetDescriptor,
        ImportTargetDescriptor.payableAccount,
      );
      expect(
        entity.allowedTargetDescriptors,
        contains(ImportTargetDescriptor.payableAccount),
      );
      expect(
        entity.allowedTargetDescriptors,
        isNot(contains(ImportTargetDescriptor.creditAccount)),
      );
    },
  );

  test('maps debt lending, collection, and receivable opening balances', () {
    final result = _parser(
      debtRows: [
        {
          '日期': '2026-01-01 09:00',
          '类型': '借出',
          '转出账户': '现金',
          '转入账户': '小王',
          '金额': 100.0,
          '手续费': 0.0,
        },
        {
          '日期': '2026-01-02 09:00',
          '类型': '收款',
          '转出账户': '现金',
          '转入账户': '小王',
          '金额': 40.0,
          '手续费': 0.0,
        },
        {
          '日期': '2026-01-03 09:00',
          '类型': '借出',
          '转出账户': '无账户',
          '转入账户': '旧应收',
          '金额': 60.0,
          '手续费': 0.0,
        },
      ],
    ).parse(_bundle(names: const ['债务.xls']));

    expect(result.groups[0].topLevel, isA<ImportLendingDraft>());
    expect(result.groups[1].topLevel, isA<ImportReceivableCollectionDraft>());
    final opening = result.groups[2].topLevel as ImportOpeningBalanceDraft;
    expect(opening.accountKind, ImportOpeningBalanceAccountKind.receivable);
    final receivable = result.sourceAccounts.singleWhere(
      (account) => account.displayName == '小王',
    );
    expect(receivable.allowedTargetDescriptors, {
      ImportTargetDescriptor.receivableAccount,
    });
  });

  test('turns a reimbursed expense refund into a gross advance and refund', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-08-21 20:24',
          '收支类型': '支出',
          '金额': -18.0,
          '类别': '食品餐饮',
          '二级分类': '请客吃饭',
          '账户': 'test 资金',
          '退款': 2.0,
          '报销账户': 'test 报销',
          '报销金额': 17.0,
          '报销明细':
              '2026/08/21test 资金 B到账10.0\n'
              '2026/08/21test 资金 B到账7.0',
          '备注': '',
          '其他': '',
        },
      ],
    ).parse(_bundle(names: const ['账单.xls']));

    final group = result.groups.single;
    final advance = group.topLevel as ImportReimbursementAdvanceDraft;
    expect(advance.amount, Money.parse('20.00'));
    expect(group.children, hasLength(3));
    final refund = group.children[0] as ImportRefundDraft;
    expect(refund.amount, Money.parse('2.00'));
    final receipt = group.children[1] as ImportReimbursementReceiptDraft;
    expect(receipt.amount, Money.parse('10.00'));
    final close = group.children[2] as ImportReimbursementCloseDraft;
    expect(close.actualReceivedAmount, Money.parse('7.00'));
  });

  test('filters a bill transfer-fee result from its generated note', () {
      final result = _parser(
        billRows: [
          {
            '日期': '2026-01-01 09:00',
            '收支类型': '支出',
            '金额': -3.0,
            '类别': '其他',
            '二级分类': '',
            '账户': '现金',
            '退款': 0.0,
            '报销账户': '',
            '报销金额': '',
            '报销明细': '',
            '备注': '银行卡 转账手续费',
            '其他': '',
          },
        ],
    ).parse(_bundle(names: const ['账单.xls']));

    expect(result.groups, isEmpty);
      expect(
        result.filteredRecords.single.reasonCode,
        'transfer_fee_generated',
      );
      expect(result.sourceCategories, isEmpty);
    },
  );

  test('runs additional source ParseUnits without changing the parser', () {
    final parser = _parser(additionalParseUnits: const [_AdditionalBillUnit()]);

    final result = parser.parse(_bundle(names: const ['账单.xls']));

    expect(
      result.issues.map((issue) => issue.code),
      contains('additional_parse_unit_ran'),
    );
  });

  test(
    'produces deterministic fingerprints without fabricating source keys',
    () {
      final parser = _parser(
        billRows: [
          {
            '日期': '2026-04-06 12:49',
            '收支类型': '支出',
            '金额': -25.0,
            '类别': '餐饮',
            '二级分类': '午餐',
            '账户': '现金',
          },
        ],
      );
      final first = parser.parse(_bundle());
      final second = parser.parse(_bundle());
      final firstGroup = _groups(first).single;
      final secondGroup = _groups(second).single;
      expect(firstGroup.sourceOperationKey, isNull);
      expect(
        firstGroup.sourceOperationFingerprint,
        secondGroup.sourceOperationFingerprint,
      );
      expect(firstGroup.fingerprintVersion, 1);
    },
  );

  test('preserves version 1 fingerprints across typed row normalization', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-07-01 08:00',
          '收支类型': '支出',
          '金额': -12.3,
          '类别': '餐饮',
          '二级分类': '早餐',
          '账户': '现金',
          '退款': '',
          '备注': 'probe-normal',
          '其他': '',
        },
        {
          '日期': '2026-07-02 08:00',
          '收支类型': '支出',
          '金额': -12.3,
          '类别': '餐饮',
          '二级分类': '早餐',
          '账户': '现金',
          '退款': 2.0,
          '备注': 'probe-refund',
          '其他': '',
        },
        {
          '日期': '2026-07-03 08:00',
          '收支类型': '支出',
          '金额': -100.0,
          '类别': '居家生活',
          '二级分类': '电费',
          '账户': '现金',
          '报销账户': '公司应收',
          '报销金额': 80.0,
          '报销明细': '2026/07/04银行卡到账30.0\n2026/07/05银行卡到账50.0',
          '备注': 'probe-reimbursement',
          '其他': '',
        },
      ],
    ).parse(_bundle());
    const expected = {
      'probe-normal':
          '86a5253ba8293a50850e985cee56a5eaa6c481a6aad0e0578c238fda2ea450b7',
      'probe-refund':
          '306632313c61bc0f08fea8e9307afef2722903aece76503280dc2000b20092a7',
      'probe-reimbursement':
          'd45ff9caf1d9db908e463640e7503ba1ce2e0bccfb0ba2e476e69ad8636e91a1',
    };

    for (final entry in expected.entries) {
      final group = result.groups.singleWhere(
        (group) => group.topLevel.note == entry.key,
      );
      expect(group.fingerprintVersion, 1);
      expect(group.sourceOperationFingerprint, entry.value);
    }
  });

  test('keeps income flags and explicit no-account semantics separate', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-02-28 19:53',
          '收支类型': '收入',
          '金额': 18000.0,
          '类别': '收入',
          '二级分类': '工资',
          '账户': '无账户',
          '其他': '不计入收支、不计入预算',
        },
      ],
    ).parse(_bundle());

    final income = _groups(result).single.topLevel as ImportIncomeDraft;
    expect(income.isExcludedFromStats, isTrue);
    expect(income.isExcludedFromBudget, isTrue);
    expect(income.receiveAccount.isExplicitNone, isTrue);
    expect(income.receiveAccount.isUnresolved, isFalse);
    expect(
      result.sourceAccounts.where(
        (account) => !account.displayName.startsWith('测试'),
      ),
      isEmpty,
    );
    expect(income.category.path, '收入 / 工资');
  });

  test(
    'exposes a required missing account as a review-only mapping entity',
    () {
      final result = _parser(
        transferRows: [
          {
            '日期': '2026-04-06 12:49',
            '类型': '转账',
            '转出账户': '',
            '转入账户': '银行卡',
            '金额': 25.0,
            '手续费': 0.0,
            '备注': '',
          },
        ],
      ).parse(_bundle());

      final group = _groups(result).single;
      final transfer = group.topLevel as ImportTransferDraft;
      final missingKey = transfer.fromAccount.sourceEntityKey;
      expect(transfer.fromAccount.isUnresolved, isTrue);
      expect(missingKey, isNotNull);
      expect(
        result.sourceEntities
            .singleWhere((entity) => entity.sourceEntityKey == missingKey)
            .isReviewPlaceholder,
        isTrue,
      );
      expect(
        group.issues.map((issue) => issue.code),
        contains('account_missing'),
      );
    },
  );

  test('blocks rows that explicitly carry unsupported multi-currency data', () {
    final result = _parser(
      billRows: [
        {
          '日期': '2026-04-06 12:49',
          '收支类型': '支出',
          '金额': -25.0,
          '类别': '餐饮',
          '二级分类': '午餐',
          '账户': '现金',
          '多币种': 'USD 3.50',
        },
      ],
    ).parse(_bundle());

    final group = _groups(result).single;
    expect(group.hasBlockingIssues, isTrue);
    expect(
      group.issues.map((issue) => issue.code),
      contains('multi_currency_unsupported'),
    );
  });

  test(
    'attaches normalized row issues to the transaction group from that row',
    () {
      final result = _parser(
        billRows: [
          {
            '日期': 'not-a-date',
            '收支类型': '收入',
            '金额': 'not-a-money',
            '类别': '工资',
            '二级分类': '',
            '账户': '现金',
          },
        ],
      ).parse(_bundle());

      final group = _groups(result).single;
      expect(group.hasBlockingIssues, isTrue);
      expect(
        group.issues.map((issue) => issue.code),
        containsAll(<String>['date_invalid', '金额_invalid']),
      );
    },
  );

  test('marks duplicate explicit operation keys as a plan conflict', () {
    final rows = [
      for (var index = 0; index < 2; index++)
        {
          '日期': '2026-04-06 12:49',
          '收支类型': '支出',
          '金额': -25.0,
          '类别': '餐饮',
          '二级分类': '午餐',
          '账户': '现金',
          '交易ID': 'stable-1',
        },
    ];
    final result = _parser(billRows: rows).parse(_bundle());

    final groups = _groups(result);
    expect(groups, hasLength(2));
    expect(groups.every((group) => group.hasBlockingIssues), isTrue);
    expect(
      groups.expand((group) => group.issues).map((issue) => issue.code),
      contains('duplicate_source_operation_key'),
    );
  });

  test('treats duplicate auto-detected file roles as a bundle fatal error', () {
    final reader = _FakeReader({
      '账单.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '账单',
            rows: const [_fixtureBillRow],
            headers: _billHeaders,
          ),
        ],
      ),
      '账单副本.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '账单',
            rows: const [_fixtureBillRow],
            headers: _billHeaders,
          ),
        ],
      ),
      '转账.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '转账',
            rows: const [_fixtureTransferRow],
            headers: _transferHeaders,
          ),
        ],
      ),
      '债务.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '转账',
            rows: const [_fixtureDebtRow],
            headers: _transferHeaders,
          ),
        ],
      ),
    });
    final result = YimuImportParser(reader: reader).parse(
      ImportBundle(
        files: [
          for (final name in ['账单.xls', '账单副本.xls', '转账.xls', '债务.xls'])
            ImportFilePayload(name: name, bytes: Uint8List(0)),
        ],
      ),
    );

    expect(
      result.fatalIssues.map((issue) => issue.code),
      contains('duplicate_file_role'),
    );
    expect(result.groups, isEmpty);
  });

  test('isolates an empty worksheet when other files remain usable', () {
    final reader = _FakeReader({
      '账单.xls': YimuWorkbook(
        sheets: [YimuSheet(name: '账单', rows: const [], headers: const [])],
      ),
      '转账.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '转账',
            rows: const [_fixtureTransferRow],
            headers: _transferHeaders,
          ),
        ],
      ),
      '债务.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '债务',
            rows: const [_fixtureDebtRow],
            headers: _transferHeaders,
          ),
        ],
      ),
    });

    final result = YimuImportParser(reader: reader).parse(_bundle());

    expect(result.fatalIssues, isEmpty);
    expect(
      result.fileResults
          .singleWhere((file) => file.fileName == '账单.xls')
          .fatalIssues
          .map((issue) => issue.code),
      contains('empty_sheet'),
    );
    expect(result.groups, isNotEmpty);
  });

  test('reports no usable files when every worksheet is empty', () {
    final reader = _FakeReader({
      '账单.xls': YimuWorkbook(
        sheets: [YimuSheet(name: '账单', rows: const [], headers: _billHeaders)],
      ),
      '转账.xls': YimuWorkbook(
        sheets: [
          YimuSheet(name: '转账', rows: const [], headers: _transferHeaders),
        ],
      ),
      '债务.xls': YimuWorkbook(
        sheets: [
          YimuSheet(name: '债务', rows: const [], headers: _transferHeaders),
        ],
      ),
    });

    final result = YimuImportParser(reader: reader).parse(_bundle());

    expect(
      result.fatalIssues.map((issue) => issue.code),
      contains('no_usable_files'),
    );
    expect(
      result.fileResults
          .expand((file) => file.fatalIssues)
          .map((issue) => issue.code),
      everyElement('empty_sheet'),
    );
  });

  test('rejects a bill sheet missing a rule-required header', () {
    final headers = [..._billHeaders]..remove('报销明细');
    final reader = _FakeReader({
      '账单.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '账单',
            rows: const [
              {
                '日期': '2026-04-06 12:49',
                '收支类型': '支出',
                '金额': -25.0,
                '类别': '餐饮',
                '二级分类': '午餐',
                '账户': '现金',
              },
            ],
            headers: headers,
          ),
        ],
      ),
      '转账.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '转账',
            rows: const [_fixtureTransferRow],
            headers: _transferHeaders,
          ),
        ],
      ),
      '债务.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '债务',
            rows: const [_fixtureDebtRow],
            headers: _transferHeaders,
          ),
        ],
      ),
    });

    final result = YimuImportParser(reader: reader).parse(_bundle());

    expect(result.fatalIssues, isEmpty);
    expect(
      result.fileResults
          .singleWhere((file) => file.fileName == '账单.xls')
          .fatalIssues
          .map((issue) => issue.code),
      contains('unsupported_headers'),
    );
    expect(result.groups, isNotEmpty);
  });

  test('does not expose workbook decoder details in fatal messages', () {
    final result = YimuImportParser(reader: const _ThrowingReader()).parse(
      ImportBundle(
        files: [ImportFilePayload(name: '账单.xls', bytes: Uint8List(0))],
      ),
    );

    expect(
      result.fatalIssues.map((issue) => issue.code),
      contains('no_usable_files'),
    );
    final issue = result.fileResults.single.fatalIssues.firstWhere(
      (candidate) => candidate.code == 'file_decode_failed',
    );
    expect(issue.message, isNot(contains('decoder-secret')));
  });
}

YimuImportParser _parser({
  List<Map<String, Object?>> billRows = const [],
  List<Map<String, Object?>> transferRows = const [],
  List<Map<String, Object?>> debtRows = const [],
  bool includeTransfer = true,
  Iterable<ParseUnit> additionalParseUnits = const [],
}) {
  return YimuImportParser(
    reader: _FakeReader({
      '账单.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '账单',
            rows: billRows.isEmpty ? const [_fixtureBillRow] : billRows,
            headers: _billHeaders,
          ),
        ],
      ),
      if (includeTransfer)
        '转账.xls': YimuWorkbook(
          sheets: [
            YimuSheet(
              name: '转账',
              rows:
                  transferRows.isEmpty
                      ? const [_fixtureTransferRow]
                      : transferRows,
              headers: _transferHeaders,
            ),
          ],
        ),
      '债务.xls': YimuWorkbook(
        sheets: [
          YimuSheet(
            name: '转账',
            rows: debtRows.isEmpty ? const [_fixtureDebtRow] : debtRows,
            headers: _transferHeaders,
          ),
        ],
      ),
    }),
    additionalParseUnits: additionalParseUnits,
  );
}

ImportBundle _bundle({List<String>? names}) {
  final selectedNames = names ?? const ['账单.xls', '转账.xls', '债务.xls'];
  return ImportBundle(
    files: [
      for (final name in selectedNames)
        ImportFilePayload(name: name, bytes: Uint8List(0)),
    ],
  );
}

List<ImportTransactionGroupDraft> _groups(ImportParseResult result) {
  return result.groups
      .where((group) => group.topLevel.note != _fixtureNote)
      .toList(growable: false);
}

class _FakeReader implements YimuWorkbookReader {
  _FakeReader(this.workbooks);

  final Map<String, YimuWorkbook> workbooks;

  @override
  YimuWorkbook read(ImportFilePayload file) {
    final workbook = workbooks[file.name];
    if (workbook == null) {
      throw FormatException('missing workbook: ${file.name}');
    }
    return workbook;
  }
}

class _ThrowingReader implements YimuWorkbookReader {
  const _ThrowingReader();

  @override
  YimuWorkbook read(ImportFilePayload file) {
    throw Exception('decoder-secret');
  }
}

class _AdditionalBillUnit implements ParseUnit {
  const _AdditionalBillUnit();

  @override
  String get key => 'test.additional-bill';

  @override
  Set<ImportSourceFileType> get requiredFileTypes => {
    YimuFileType.bill.descriptor,
  };

  @override
  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts) {
    return ParseUnitResult(
      issues: const [
        ImportIssue(
          code: 'additional_parse_unit_ran',
          message: 'additional unit ran',
          severity: ImportIssueSeverity.warning,
        ),
      ],
    );
  }
}

const _billHeaders = [
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
];

const _transferHeaders = ['日期', '类型', '转出账户', '转入账户', '金额', '手续费', '备注'];

const _fixtureTransferRow = {
  '日期': '2026-01-01 00:00',
  '类型': '转账',
  '转出账户': '测试转出账户',
  '转入账户': '测试转入账户',
  '金额': 1.0,
  '手续费': 0.0,
  '备注': _fixtureNote,
};

const _fixtureDebtRow = {
  '日期': '2026-01-01 00:00',
  '类型': '借入',
  '转出账户': '测试到账账户',
  '转入账户': '测试负债账户',
  '金额': 1.0,
  '手续费': 0.0,
  '备注': _fixtureNote,
};

const _fixtureBillRow = {
  '日期': '2026-01-01 00:00',
  '收支类型': '收入',
  '金额': 1.0,
  '类别': '测试',
  '二级分类': '占位',
  '账户': '无账户',
  '退款': '',
  '报销账户': '',
  '报销金额': '',
  '报销明细': '',
  '备注': _fixtureNote,
  '其他': '',
};

const _fixtureNote = '测试占位';
