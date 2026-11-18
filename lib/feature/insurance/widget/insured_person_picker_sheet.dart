import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import 'member_avatar_view.dart';

Future<String?> showInsuredPersonPickerSheet({
  required BuildContext context,
  required List<InsuredPerson> people,
  required String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => InsuredPersonPickerSheet(
      people: people,
      selectedId: selectedId,
      onSelected: (id) => Navigator.of(context).pop(id),
    ),
  );
}

class InsuredPersonPickerSheet extends StatelessWidget {
  const InsuredPersonPickerSheet({
    required this.people,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<InsuredPerson> people;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height *
            AppComponentTokens.selectionSheetMaxHeightFactor,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space16),
              child: Text(
                '选择参保人',
                style: context.appTextStyles.subsectionTitleStrong,
              ),
            ),
            Flexible(
              child: people.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      child: Text(
                        '暂无可选成员',
                        style: context.appTextStyles.listSupporting,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: people.length,
                      itemBuilder: (context, index) {
                        final person = people[index];
                        return ListTile(
                          key: ValueKey('insured-person-option-${person.id}'),
                          leading: MemberAvatarView(
                            preset: person.avatarPreset,
                            size: AppSpacing.space40,
                          ),
                          title: Text(
                            person.name,
                            style: context.appTextStyles.formValue,
                          ),
                          subtitle: Text(
                            '${person.relationship.label} · ${person.ageAt(DateTime.now())} 岁',
                            style: context.appTextStyles.listSupporting,
                          ),
                          selected: person.id == selectedId,
                          trailing: person.id == selectedId
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () => onSelected(person.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
