import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/profile/widget/manual_markdown.dart';

void main() {
  test('parseManualHeadings extracts h2 and h3 in order', () {
    const data = '''
# 一级标题

## 第一节

正文

### 小节一

### 小节二

## 第二节
''';
    final headings = parseManualHeadings(data);

    expect(
      headings.map((h) => h.text).toList(),
      equals(['第一节', '小节一', '小节二', '第二节']),
    );
    expect(headings.map((h) => h.level).toList(), equals([2, 3, 3, 2]));
    expect(
      headings.map((h) => h.key).toList(),
      equals(['第一节', '小节一', '小节二', '第二节']),
    );
  });

  test('parseManualHeadings ignores h1 and disambiguates duplicate titles', () {
    const data = '''
# 一级标题

## 重复

## 重复

### 其他
''';
    final headings = parseManualHeadings(data);

    expect(headings.map((h) => h.key).toList(), equals(['重复', '重复 #2', '其他']));
  });

  test(
    'stripLeadingH1 removes only the leading h1 and following blank lines',
    () {
      expect(stripLeadingH1('# 标题\n\n正文'), equals('正文'));
      expect(stripLeadingH1('## 小节\n正文'), equals('## 小节\n正文'));
    },
  );
}
