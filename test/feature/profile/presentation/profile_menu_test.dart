import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/feature/profile/presentation/profile_menu.dart';

void main() {
  test('balances entries within the available capacity', () {
    expect(profileGridColumnCount(entryCount: 14, maxColumns: 5), 5);
    expect(profileGridColumnCount(entryCount: 6, maxColumns: 5), 3);
    expect(profileGridColumnCount(entryCount: 7, maxColumns: 5), 4);
    expect(profileGridColumnCount(entryCount: 9, maxColumns: 5), 5);
    expect(profileGridColumnCount(entryCount: 14, maxColumns: 3), 3);
    expect(profileGridColumnCount(entryCount: 6, maxColumns: 1), 1);
  });

  test('allows columns to grow with the available capacity', () {
    expect(profileGridColumnCount(entryCount: 6, maxColumns: 8), 6);
    expect(profileGridColumnCount(entryCount: 14, maxColumns: 8), 7);
    expect(profileGridColumnCount(entryCount: 14, maxColumns: 20), 14);
    expect(profileGridColumnCount(entryCount: 2, maxColumns: 5), 2);
  });
}
