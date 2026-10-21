import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/profile/presentation/profile_menu.dart';

void main() {
  test('balances 14 entries into five columns and three rows', () {
    expect(profileGridColumnCount(entryCount: 14, maxColumns: 5), 5);
  });

  test('keeps 3-5 columns and avoids sparse rows', () {
    expect(profileGridColumnCount(entryCount: 6, maxColumns: 5), 3);
    expect(profileGridColumnCount(entryCount: 7, maxColumns: 5), 4);
    expect(profileGridColumnCount(entryCount: 9, maxColumns: 5), 5);
    expect(profileGridColumnCount(entryCount: 14, maxColumns: 3), 3);
    expect(profileGridColumnCount(entryCount: 2, maxColumns: 5), 3);
  });
}
