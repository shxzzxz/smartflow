import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/app.dart';
import 'package:smartflow/data/database_provider.dart';

import '../helper/test_app_database.dart';

void main() {
  testWidgets('renders the stage 2 app shell', (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const SmartFlowApp(),
      ),
    );
    await tester.pump();

    final now = DateTime.now();

    expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('本月预算'), findsOneWidget);
    expect(find.text('本月暂无交易记录'), findsOneWidget);
  });
}
