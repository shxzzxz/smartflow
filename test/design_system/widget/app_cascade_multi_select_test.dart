import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_cascade_multi_select.dart';

void main() {
  testWidgets('only shows the current cascade level', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onResult: (_) {},
        selectedValues: const {},
        nodes: const [
          AppCascadeSelectionNode(
            value: 'parent',
            label: '父级',
            children: [
              AppCascadeSelectionNode(
                value: 'child',
                label: '子级',
                children: [
                  AppCascadeSelectionNode(value: 'grandchild', label: '孙级'),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('父级'), findsOneWidget);
    expect(find.text('子级'), findsNothing);
    expect(find.text('孙级'), findsNothing);

    await tester.tap(find.text('父级'));
    await tester.pump();
    expect(find.text('父级'), findsOneWidget);
    expect(find.text('子级'), findsOneWidget);
    expect(find.text('孙级'), findsNothing);

    await tester.tap(find.text('子级'));
    await tester.pump();
    expect(find.text('父级'), findsNothing);
    expect(find.text('子级'), findsOneWidget);
    expect(find.text('孙级'), findsOneWidget);

    await tester.tap(find.byTooltip('返回上一级'));
    await tester.pump();
    expect(find.text('子级'), findsOneWidget);
    expect(find.text('孙级'), findsNothing);
  });

  testWidgets('selecting a parent selects every descendant', (tester) async {
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await showAppCascadeMultiSelectSheet<String>(
                    context: context,
                    title: '选择项目',
                    sections: const [
                      AppCascadeSelectionSection(
                        label: '分组',
                        nodes: [
                          AppCascadeSelectionNode(
                            value: 'parent',
                            label: '父级',
                            children: [
                              AppCascadeSelectionNode(
                                value: 'child',
                                label: '子级',
                                children: [
                                  AppCascadeSelectionNode(
                                    value: 'grandchild',
                                    label: '孙级',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    selectedValues: const {},
                  );
                },
                child: const Text('打开'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, {'parent', 'child', 'grandchild'});
  });

  testWidgets('clear removes every selected value', (tester) async {
    Set<String>? result;
    await tester.pumpWidget(
      _TestHost(
        onResult: (value) => result = value,
        selectedValues: const {'parent', 'child'},
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, isEmpty);
  });

  testWidgets('all selects every available value', (tester) async {
    Set<String>? result;
    await tester.pumpWidget(_TestHost(onResult: (value) => result = value));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, {'parent', 'child'});
  });

  testWidgets(
    'group nodes select descendants without returning a group value',
    (tester) async {
      Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    result = await showAppCascadeMultiSelectSheet<String>(
                      context: context,
                      title: '选择项目',
                      sections: const [
                        AppCascadeSelectionSection(
                          nodes: [
                            AppCascadeSelectionNode.group(
                              label: '分组',
                              children: [
                                AppCascadeSelectionNode(
                                  value: 'child',
                                  label: '子级',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      selectedValues: const {},
                    );
                  },
                  child: const Text('打开'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(result, {'child'});
    },
  );
}

class _TestHost extends StatelessWidget {
  const _TestHost({
    required this.onResult,
    this.selectedValues = const {},
    this.nodes = const [
      AppCascadeSelectionNode(
        value: 'parent',
        label: '父级',
        children: [AppCascadeSelectionNode(value: 'child', label: '子级')],
      ),
    ],
  });

  final ValueChanged<Set<String>?> onResult;
  final Set<String> selectedValues;
  final List<AppCascadeSelectionNode<String>> nodes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                onResult(
                  await showAppCascadeMultiSelectSheet<String>(
                    context: context,
                    title: '选择项目',
                    sections: [AppCascadeSelectionSection(nodes: nodes)],
                    selectedValues: selectedValues,
                  ),
                );
              },
              child: const Text('打开'),
            );
          },
        ),
      ),
    );
  }
}
