part of 'yimu_file_handlers.dart';

class YimuBillFileHandler implements YimuFileHandler {
  const YimuBillFileHandler();

  @override
  YimuFileType get fileType => YimuFileType.bill;

  @override
  List<ImportIssue> validate({
    required String fileName,
    required ImportTabularSheet sheet,
  }) {
    return _validateSheet(
      fileType: fileType,
      fileName: fileName,
      sheet: sheet,
      requiredHeaders: _billRequiredHeaders,
    );
  }

  @override
  SourceFileFact handle({
    required int fileIndex,
    required String fileName,
    required ImportTabularSheet sheet,
  }) {
    final records = [
      for (var index = 0; index < sheet.rows.length; index++)
        ?_normalizeBillRecord(sheet.rows[index], index + 2),
    ];
    return SourceFileFact(
      fileIndex: fileIndex,
      fileName: fileName,
      fileType: fileType.descriptor,
      records: records,
      // Bill entities are derived only after bundle-level filters run. This
      // prevents a generated transfer-fee result row from leaving behind an
      // unnecessary account/category mapping item.
      issues: records.expand((record) => record.issues),
    );
  }

  YimuBillRecord? _normalizeBillRecord(
    Map<String, Object?> row,
    int rowNumber,
  ) {
    if (_isBlankRow(row)) return null;
    final kind = _text(row, '收支类型');
    final note = _text(row, '备注');
    final filterReason = _filterReason(note);
    final issues = <ImportIssue>[];
    final shouldNormalizeTransaction = filterReason == null;
    final occurredAt = shouldNormalizeTransaction
        ? (_date(
                row['日期'],
                fileType: fileType,
                issues: issues,
                rowNumber: rowNumber,
                required: true,
              ) ??
              _epoch)
        : _epoch;
    final postedAt = shouldNormalizeTransaction
        ? _postedAt(
            row,
            occurredAt,
            fileType: fileType,
            issues: issues,
            rowNumber: rowNumber,
          )
        : occurredAt;
    final amount = shouldNormalizeTransaction
        ? (_money(
                row['金额'],
                fileType: fileType,
                issues: issues,
                rowNumber: rowNumber,
                fieldName: '金额',
                required: true,
              ) ??
              Money.zero())
        : Money.zero();
    final hasAdvanceFields =
        kind == '支出' && _hasText(row, '报销账户', '报销金额', '报销明细');
    Money? refundAmount;
    Money? advanceAmount;
    var advanceDetails = const <YimuAdvanceDetail>[];
    if (shouldNormalizeTransaction && kind == '支出') {
      refundAmount = _money(
        row['退款'],
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        fieldName: '退款',
        required: false,
      );
      if (hasAdvanceFields) {
        advanceAmount = _money(
          row['报销金额'],
          fileType: fileType,
          issues: issues,
          rowNumber: rowNumber,
          fieldName: '报销金额',
          required: true,
        );
        advanceDetails = _advanceDetails(
          _text(row, '报销明细'),
          rowNumber: rowNumber,
          issues: issues,
        );
      }
    }
    if (shouldNormalizeTransaction && _text(row, '多币种') != null) {
      issues.add(
        _issue(
          fileType,
          'multi_currency_unsupported',
          '第一版导入不支持多币种金额。',
          rowNumber,
        ),
      );
    }
    return YimuBillRecord(
      rowNumber: rowNumber,
      sourceOperationKey: _sourceOperationKey(row, fileType),
      kind: kind,
      occurredAt: occurredAt,
      postedAt: postedAt,
      amount: amount,
      categoryPath: _categoryPath(row),
      accountName: _text(row, '账户'),
      refundSource: _text(row, '退款'),
      refundAmount: refundAmount,
      hasAdvanceFields: hasAdvanceFields,
      advanceAccountName: _text(row, '报销账户'),
      advanceAmountSource: _text(row, '报销金额'),
      advanceAmount: advanceAmount,
      advanceDetails: advanceDetails,
      advanceDetailsSource: _text(row, '报销明细'),
      note: note,
      other: _text(row, '其他'),
      filterReason: filterReason,
      issues: issues,
    );
  }

  YimuBillFilterReason? _filterReason(String? note) {
    if (note?.startsWith('报销差额') == true) {
      return YimuBillFilterReason.advanceGap;
    }
    if (note?.contains('还款利息') == true) {
      return YimuBillFilterReason.repaymentInterest;
    }
    if (note?.contains('还款优惠') == true) {
      return YimuBillFilterReason.repaymentDiscount;
    }
    return null;
  }

  List<YimuAdvanceDetail> _advanceDetails(
    String? value, {
    required int rowNumber,
    required List<ImportIssue> issues,
  }) {
    if (value == null || value.trim().isEmpty) return const [];
    final details = <YimuAdvanceDetail>[];
    for (final line in value.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(
        r'^(\d{4}/\d{2}/\d{2})(.+?)到账\s*([+-]?\d+(?:\.\d+)?)$',
      ).firstMatch(trimmed);
      if (match == null) {
        issues.add(
          _issue(
            fileType,
            'advance_detail_invalid',
            '无法解析报销明细：$trimmed',
            rowNumber,
          ),
        );
        continue;
      }
      final date = _date(
        match.group(1),
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        required: true,
      );
      final amount = _money(
        match.group(3),
        fileType: fileType,
        issues: issues,
        rowNumber: rowNumber,
        fieldName: '报销明细金额',
        required: true,
      );
      details.add(
        YimuAdvanceDetail(
          occurredAt: date,
          amount: amount,
          accountName: _textValue(match.group(2)),
        ),
      );
    }
    return details;
  }
}
