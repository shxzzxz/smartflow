import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/profile/data/manual_catalog.dart';

void main() {
  test('contains the first six manual articles in product order', () {
    expect(manualArticles, hasLength(6));
    expect(
      manualArticles.map((article) => article.slug).toList(),
      equals([
        'getting-started',
        'record-expense',
        'ledger-concepts',
        'credit-bills',
        'installment-contracts',
        'credit-metrics',
      ]),
    );
  });

  test('search matches article metadata and ignores case', () {
    final article = findManualArticle('credit-metrics');

    expect(article, isNotNull);
    expect(article!.matches('irr'), isTrue);
    expect(article.matches('IRR'), isTrue);
    expect(article.matches('not a manual topic'), isFalse);
  });
}
