part of 'transaction_form_page.dart';

typedef _TransactionSceneChoice = ({
  TransactionFormMode mode,
  TransactionExpenseScene? expenseScene,
  TransactionIncomeScene? incomeScene,
  TransactionRelationScene? relationScene,
});

final _expenseSceneItems = <AppChoiceGridItem<_TransactionSceneChoice>>[
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.ordinary,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.consumptionInstallment,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.amortization,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.aa,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.reimbursement,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.onBehalf,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.onBehalfAccount,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.aaAccount,
  ),
  _sceneGridItem(
    TransactionFormMode.expense,
    expenseScene: TransactionExpenseScene.reimbursementAccount,
  ),
];

final _allTransactionSceneGroups =
    <AppChoiceGridGroup<_TransactionSceneChoice>>[
      AppChoiceGridGroup(id: 'expense', label: '支出', items: _expenseSceneItems),
      AppChoiceGridGroup(
        id: 'income',
        label: '收入',
        items: [
          _sceneGridItem(
            TransactionFormMode.income,
            incomeScene: TransactionIncomeScene.ordinary,
          ),
          _sceneGridItem(
            TransactionFormMode.income,
            incomeScene: TransactionIncomeScene.amortization,
          ),
        ],
      ),
      AppChoiceGridGroup(
        id: 'transfer',
        label: '转账',
        items: [_sceneGridItem(TransactionFormMode.transfer)],
      ),
      AppChoiceGridGroup(
        id: 'relations',
        label: '往来',
        items: [
          _sceneGridItem(
            TransactionFormMode.borrowing,
            relationScene: TransactionRelationScene.borrowing,
          ),
          _sceneGridItem(
            TransactionFormMode.lending,
            relationScene: TransactionRelationScene.lending,
          ),
          _sceneGridItem(
            TransactionFormMode.lending,
            relationScene: TransactionRelationScene.deposit,
          ),
        ],
      ),
    ];

AppChoiceGridItem<_TransactionSceneChoice> _sceneGridItem(
  TransactionFormMode mode, {
  TransactionExpenseScene? expenseScene,
  TransactionIncomeScene? incomeScene,
  TransactionRelationScene? relationScene,
}) {
  final choice = (
    mode: mode,
    expenseScene: expenseScene,
    incomeScene: incomeScene,
    relationScene: relationScene,
  );
  return AppChoiceGridItem(
    id: _sceneChoiceKey(choice),
    value: choice,
    label: _sceneChoiceLabel(choice),
    iconBuilder: (context, size) => Icon(_sceneChoiceIcon(choice), size: size),
  );
}

Future<_TransactionSceneChoice?> _showTransactionSceneSheet({
  required BuildContext context,
  required TransactionFormMode mode,
  required TransactionExpenseScene expenseScene,
  required TransactionIncomeScene incomeScene,
  required TransactionRelationScene relationScene,
  required List<AppChoiceGridGroup<_TransactionSceneChoice>> groups,
}) {
  return showModalBottomSheet<_TransactionSceneChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _TransactionSceneSheet(
      mode: mode,
      expenseScene: expenseScene,
      incomeScene: incomeScene,
      relationScene: relationScene,
      groups: groups,
    ),
  );
}

class _TransactionSceneSheet extends StatelessWidget {
  const _TransactionSceneSheet({
    required this.mode,
    required this.expenseScene,
    required this.incomeScene,
    required this.relationScene,
    required this.groups,
  });

  final TransactionFormMode mode;
  final TransactionExpenseScene expenseScene;
  final TransactionIncomeScene incomeScene;
  final TransactionRelationScene relationScene;
  final List<AppChoiceGridGroup<_TransactionSceneChoice>> groups;

  @override
  Widget build(BuildContext context) {
    final selectedId = groups
        .expand((group) => group.items)
        .where(
          (item) => _isSceneChoiceSelected(
            item.value,
            mode: mode,
            expenseScene: expenseScene,
            incomeScene: incomeScene,
            relationScene: relationScene,
          ),
        )
        .map((item) => item.id)
        .firstOrNull;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGroupedChoiceGrid<_TransactionSceneChoice>(
              groups: groups,
              selectedId: selectedId,
              onSelected: (item) => Navigator.of(context).pop(item.value),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSceneChoiceSelected(
  _TransactionSceneChoice choice, {
  required TransactionFormMode mode,
  required TransactionExpenseScene expenseScene,
  required TransactionIncomeScene incomeScene,
  required TransactionRelationScene relationScene,
}) {
  if (choice.mode != mode) return false;
  if (choice.mode == TransactionFormMode.expense) {
    return choice.expenseScene == expenseScene;
  }
  if (choice.mode == TransactionFormMode.income) {
    return choice.incomeScene == incomeScene;
  }
  return choice.relationScene == relationScene;
}

String _sceneChoiceKey(_TransactionSceneChoice choice) {
  final scene = choice.expenseScene;
  final incomeScene = choice.incomeScene;
  final relationScene = choice.relationScene;
  if (scene != null) return 'expense:${scene.name}';
  if (incomeScene != null) return 'income:${incomeScene.name}';
  if (relationScene != null) return 'relation:${relationScene.name}';
  return 'mode:${choice.mode.name}';
}

String _sceneChoiceLabel(_TransactionSceneChoice choice) {
  final scene = choice.expenseScene;
  if (scene != null) return scene.label;
  final incomeScene = choice.incomeScene;
  if (incomeScene != null) return incomeScene.label;
  final relationScene = choice.relationScene;
  if (relationScene != null) return relationScene.label;
  return switch (choice.mode) {
    TransactionFormMode.expense => '普通支出',
    TransactionFormMode.income => '普通收入',
    TransactionFormMode.transfer => '转账',
    TransactionFormMode.borrowing ||
    TransactionFormMode.lending => throw StateError('往来场景必须声明 relationScene。'),
  };
}

IconData _sceneChoiceIcon(_TransactionSceneChoice choice) {
  final scene = choice.expenseScene;
  if (scene != null) {
    return switch (scene) {
      TransactionExpenseScene.ordinary => RemixIcons.wallet_line,
      TransactionExpenseScene.consumptionInstallment =>
        RemixIcons.shopping_bag_3_line,
      TransactionExpenseScene.amortization => RemixIcons.calendar_schedule_line,
      TransactionExpenseScene.reimbursement ||
      TransactionExpenseScene.reimbursementAccount =>
        RemixIcons.file_list_3_line,
      TransactionExpenseScene.onBehalf ||
      TransactionExpenseScene.onBehalfAccount => RemixIcons.hand_coin_line,
      TransactionExpenseScene.aa ||
      TransactionExpenseScene.aaAccount => RemixIcons.user_shared_line,
    };
  }
  final incomeScene = choice.incomeScene;
  if (incomeScene == TransactionIncomeScene.amortization) {
    return RemixIcons.calendar_schedule_line;
  }
  final relationScene = choice.relationScene;
  if (relationScene != null) {
    return switch (relationScene) {
      TransactionRelationScene.borrowing => RemixIcons.bank_card_line,
      TransactionRelationScene.lending => RemixIcons.hand_coin_line,
      TransactionRelationScene.deposit => RemixIcons.shield_check_line,
    };
  }
  return switch (choice.mode) {
    TransactionFormMode.expense => RemixIcons.wallet_line,
    TransactionFormMode.income => RemixIcons.money_dollar_circle_line,
    TransactionFormMode.transfer => RemixIcons.arrow_left_right_line,
    TransactionFormMode.borrowing ||
    TransactionFormMode.lending => throw StateError('往来场景必须声明 relationScene。'),
  };
}

Future<int?> showAaPeopleCountSheet({
  required BuildContext context,
  required int initialCount,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => _AaPeopleCountSheet(initialCount: initialCount),
  );
}

class _AaPeopleCountSheet extends StatefulWidget {
  const _AaPeopleCountSheet({required this.initialCount});

  final int initialCount;

  @override
  State<_AaPeopleCountSheet> createState() => _AaPeopleCountSheetState();
}

class _AaPeopleCountSheetState extends State<_AaPeopleCountSheet> {
  late int _count = widget.initialCount.clamp(2, 99).toInt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AA人数', style: context.appTextStyles.subsectionTitle),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '人数仅用于本次场景录入。',
              style: context.appTextStyles.listSupporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const ValueKey('aa-people-minus'),
                  onPressed: _count > 2
                      ? () => setState(() => _count -= 1)
                      : null,
                  icon: const Icon(RemixIcons.subtract_line),
                  tooltip: '减少人数',
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    '$_count人',
                    textAlign: TextAlign.center,
                    style: context.appTextStyles.subsectionTitleStrong,
                  ),
                ),
                IconButton(
                  key: const ValueKey('aa-people-plus'),
                  onPressed: _count < 99
                      ? () => setState(() => _count += 1)
                      : null,
                  icon: const Icon(RemixIcons.add_line),
                  tooltip: '增加人数',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space16),
            AppSubmitButton(
              key: const ValueKey('aa-people-confirm'),
              label: '确定',
              onPressed: () => Navigator.of(context).pop(_count),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvanceSplitSummary extends StatelessWidget {
  const _AdvanceSplitSummary({
    required this.scene,
    required this.aaPeopleCount,
    required this.amountController,
  });

  final TransactionExpenseScene scene;
  final int aaPeopleCount;
  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: amountController,
      builder: (context, value, _) {
        final total = Money.tryParse(value.text);
        if (total == null || total.minorUnits <= 0) {
          return const SizedBox.shrink();
        }
        final selfBorne = selfBorneAmountForExpenseScene(
          scene: scene,
          total: total,
          aaPeopleCount: aaPeopleCount,
        );
        final advance = advanceAmountForExpenseScene(
          scene: scene,
          total: total,
          aaPeopleCount: aaPeopleCount,
        );
        final text = scene.isAa
            ? '按 $aaPeopleCount 人 AA：自承担 ${selfBorne.format()}，'
                  '垫付 ${advance.format()}'
            : '按交易金额全额垫付 ${advance.format()}';
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.space8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: context.appTextStyles.formSupporting.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
