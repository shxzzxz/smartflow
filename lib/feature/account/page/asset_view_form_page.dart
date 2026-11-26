import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import '../../../application/analytics/analytics_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_scaffold.dart';
import '../../../widget/business/account/account_multi_select_sheet.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/asset_view_form_view_model.dart';
import '../widget/asset_view_editor_actions.dart';
import 'asset_view_preview_page.dart';

class AssetViewFormPage extends ConsumerWidget {
  const AssetViewFormPage({
    this.viewId,
    this.copyFrom,
    this.initiallyHideBalances = false,
    super.key,
  });
  final String? viewId;
  final AssetView? copyFrom;
  final bool initiallyHideBalances;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(assetViewFormPageProvider(viewId, copyFrom));
    final title = viewId != null
        ? '编辑视图'
        : copyFrom == null
        ? '新建视图'
        : '复制视图';
    return page.when(
      data: (page) => _AssetViewEditor(
        viewId: viewId,
        copyFrom: copyFrom,
        title: title,
        page: page,
        initiallyHideBalances: initiallyHideBalances,
      ),
      loading: () => AppScaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppPageHeader(title: title),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
      error: (error, trace) => AppScaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppPageHeader(title: title),
              Expanded(
                child: Center(
                  child: AppEmptyState(
                    title: '视图加载失败',
                    action: TextButton(
                      onPressed: () {
                        final form = assetViewFormViewModelProvider(
                          viewId,
                          copyFrom,
                        );
                        if (ref.read(form).hasError) ref.invalidate(form);
                        ref.invalidate(accountListProvider);
                      },
                      child: const Text('重试'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetViewEditor extends ConsumerStatefulWidget {
  const _AssetViewEditor({
    required this.viewId,
    required this.copyFrom,
    required this.title,
    required this.page,
    required this.initiallyHideBalances,
  });
  final String? viewId;
  final AssetView? copyFrom;
  final String title;
  final AssetViewFormPageState page;
  final bool initiallyHideBalances;
  @override
  ConsumerState<_AssetViewEditor> createState() => _AssetViewEditorState();
}

class _AssetViewEditorState extends ConsumerState<_AssetViewEditor> {
  late final _name = TextEditingController(text: widget.page.editor.name);
  final _form = GlobalKey<FormState>();
  bool _allowPop = false;
  bool _confirmingExit = false;
  AssetViewFormViewModel get _controller => ref.read(
    assetViewFormViewModelProvider(widget.viewId, widget.copyFrom).notifier,
  );
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final editor = page.editor;
    final availableIds = page.accounts.map((account) => account.id).toSet();
    final unavailableIds = editor.accountIds.difference(availableIds);
    return PopScope<Object?>(
      canPop: _allowPop || (!editor.hasChanges && !editor.submitting),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: AppScaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppPageHeader(
                title: widget.title,
                onBack: _requestExit,
                actions: [
                  AppHeaderIconButton(
                    icon: RemixIcons.eye_line,
                    tooltip: '预览视图',
                    onPressed: editor.canPreview && !editor.submitting
                        ? _preview
                        : null,
                  ),
                  AppHeaderTextButton(
                    label: editor.submitting
                        ? '保存中'
                        : widget.viewId == null
                        ? '创建'
                        : '保存',
                    onPressed: editor.canSave ? _save : null,
                  ),
                ],
              ),
              Expanded(
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    children: [
                      AppFormSection(
                        children: [
                          AppPlainTextFormRow(
                            label: '视图名称',
                            controller: _name,
                            hintText: '例如 日常资金',
                            requiredIndicator: !editor.isBuiltin,
                            readOnly: editor.isBuiltin,
                            enabled: !editor.submitting,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(120),
                            ],
                            onChanged: _controller.setName,
                            textInputAction: TextInputAction.done,
                            validator: (name) =>
                                name == null || name.trim().isEmpty
                                ? '请输入视图名称'
                                : name.trim().length > 120
                                ? '名称最多 120 个字符'
                                : null,
                          ),
                          AppPlainSelectFormRow<Set<String>>(
                            label: '包含账户',
                            value: editor.accountIds,
                            placeholder: '请选择账户',
                            valueText: editor.accountIds.isEmpty
                                ? null
                                : '${editor.accountIds.length} 个账户',
                            requiredIndicator: !editor.isBuiltin,
                            enabled: !editor.submitting,
                            showChevron: true,
                            supportingText: unavailableIds.isEmpty
                                ? '新建账户只加入创建时选中的视图，其他账户需编辑后加入'
                                : '含 ${unavailableIds.length} 个已归档或已删除账户，恢复后会重新显示',
                            validator: (ids) =>
                                !editor.isBuiltin &&
                                    (ids == null || ids.isEmpty)
                                ? '请至少选择一个账户'
                                : null,
                            onChanged: (ids) {
                              if (ids != null) _controller.setAccounts(ids);
                            },
                            onTap: (onSelected) async {
                              final ids = await showAccountMultiSelectSheet(
                                context: context,
                                accounts: page.accounts,
                                selectedIds: editor.accountIds,
                              );
                              if (mounted && ids != null) {
                                onSelected({...ids, ...unavailableIds});
                              }
                            },
                          ),
                          if (unavailableIds.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: editor.submitting
                                    ? null
                                    : () => _controller.setAccounts(
                                        editor.accountIds.intersection(
                                          availableIds,
                                        ),
                                      ),
                                child: const Text('从视图移除不可用账户'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space16),
                      Text(
                        '统计卡片始终统计本视图包含的全部账户。',
                        style: context.appTextStyles.formSupporting,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final outcome = await _controller.save();
    if (!mounted) return;
    if (outcome case UiActionSuccess<AssetView>(:final value)) {
      _finish(value.id);
    } else {
      showAssetViewFailure(context, outcome);
    }
  }

  void _preview() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AssetViewPreviewPage(
        view: _controller.preview(),
        initiallyHideBalances: widget.initiallyHideBalances,
      ),
    ),
  );
  Future<void> _requestExit() async {
    if (_confirmingExit || widget.page.editor.submitting || _allowPop) return;
    _confirmingExit = true;
    try {
      if (widget.page.editor.hasChanges &&
          !await confirmDiscardAssetViewChanges(context)) {
        return;
      }
      if (mounted) _finish(null);
    } finally {
      _confirmingExit = false;
    }
  }

  void _finish(String? result) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }
}
