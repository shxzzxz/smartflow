import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_surface.dart';

/// 阶段的展开状态由编辑器按稳定 ID 管理，收起的字段仍参与父表单提交。
class InstallmentStageCard extends StatefulWidget {
  const InstallmentStageCard({
    required this.number,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.onInvalid,
    required this.children,
    this.actions = const [],
    super.key,
  });

  final int number;
  final String title;
  final List<String> summary;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<BuildContext> onInvalid;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  State<InstallmentStageCard> createState() => _InstallmentStageCardState();
}

class _InstallmentStageCardState extends State<InstallmentStageCard> {
  final _formKey = GlobalKey<FormState>();
  final _fieldKey = GlobalKey<FormFieldState<void>>();
  bool _refreshingErrors = false;

  String? _validate() {
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isEmpty) return null;
    if (!_refreshingErrors) widget.onInvalid(invalid.first.context);
    return '有 ${invalid.length} 项配置需要检查';
  }

  void _onChanged() {
    final field = _fieldKey.currentState!;
    field.didChange(null);
    if (!field.hasError) return;
    // 修正输入时同步错误摘要，但不打断输入或重复滚动。
    _refreshingErrors = true;
    try {
      field.validate();
    } finally {
      _refreshingErrors = false;
    }
  }

  @override
  Widget build(BuildContext context) => FormField<void>(
    key: _fieldKey,
    validator: (_) => _validate(),
    onSaved: (_) => _formKey.currentState!.save(),
    onReset: () => _formKey.currentState!.reset(),
    builder: (field) => AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space12,
              AppSpacing.space8,
              AppSpacing.space4,
              0,
            ),
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style:
                    (IconButtonTheme.of(context).style ?? const ButtonStyle())
                        .copyWith(
                          iconSize: const WidgetStatePropertyAll(
                            AppSpacing.space18,
                          ),
                        ),
              ),
              child: _header(context),
            ),
          ),
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space4,
                AppSpacing.space16,
                widget.expanded ? 0 : AppSpacing.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.space4,
                children: [
                  for (final line in widget.summary)
                    Text(line, style: context.appTextStyles.formSupporting),
                  if (field.errorText case final error?)
                    Text(
                      error,
                      style: context.appTextStyles.formSupporting.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 内层 Form 保留每个字段的校验与保存行为；外层 FormField 将结果
          // 汇入页面原有 Form，无需每个引用页面单独接入折叠校验。
          Visibility(
            visible: widget.expanded,
            maintainState: true,
            child: Form(
              key: _formKey,
              onChanged: _onChanged,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                  vertical: AppSpacing.space8,
                ),
                child: AppPlainFormSection(children: widget.children),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = Semantics(
      button: true,
      expanded: widget.expanded,
      label: '阶段 ${widget.number}，${widget.title}',
      onTap: widget.onToggle,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppComponentTokens.controlMinHeight,
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.space24,
                  minHeight: AppSpacing.space24,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                ),
                child: Text(
                  '${widget.number}',
                  style: context.appTextStyles.formSupporting.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  widget.title,
                  style: context.appTextStyles.groupTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final toggle = IconButton(
      tooltip: '${widget.expanded ? '收起' : '展开'}阶段 ${widget.number}',
      onPressed: widget.onToggle,
      icon: Icon(
        widget.expanded
            ? RemixIcons.arrow_up_s_line
            : RemixIcons.arrow_down_s_line,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minTitleWidth = MediaQuery.textScalerOf(
          context,
        ).scale(AppComponentTokens.controlMinHeight * 2);
        final controlsWidth =
            (widget.actions.length + 1) * AppComponentTokens.controlMinHeight;
        if (widget.actions.isNotEmpty &&
            constraints.maxWidth < minTitleWidth + controlsWidth) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: title),
                  toggle,
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: widget.actions,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            ...widget.actions,
            toggle,
          ],
        );
      },
    );
  }
}
