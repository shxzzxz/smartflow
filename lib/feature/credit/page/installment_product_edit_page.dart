import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_product_view_model.dart';
import '../widget/installment_terms_editor.dart';

class InstallmentProductEditPage extends ConsumerStatefulWidget {
  const InstallmentProductEditPage({
    this.productId,
    this.copy = false,
    super.key,
  });
  final String? productId;
  final bool copy;
  @override
  ConsumerState<InstallmentProductEditPage> createState() =>
      _InstallmentProductEditPageState();
}

class _InstallmentProductEditPageState
    extends ConsumerState<InstallmentProductEditPage> {
  final name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool initialized = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = installmentProductEditViewModelProvider(
      widget.productId,
      widget.copy,
    );
    final async = ref.watch(provider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: widget.productId == null || widget.copy
                  ? '新建分期产品'
                  : '编辑分期产品',
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => const Center(child: Text('产品加载失败')),
                data: (state) {
                  if (!initialized) {
                    initialized = true;
                    name.text = state.name;
                  }
                  final vm = ref.read(provider.notifier);
                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      children: [
                        AppFormSection(
                          children: [
                            AppPlainTextFormRow(
                              label: '产品名称',
                              controller: name,
                              hintText: '例如：借呗等额本息',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space12),
                        InstallmentTermsEditor(
                          value: state.terms,
                          onChanged: vm.setTerms,
                          mode: InstallmentTermsEditorMode.product,
                        ),
                        const SizedBox(height: AppSpacing.space16),
                        AppSubmitButton(
                          label: '保存产品',
                          loading: state.saving,
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            final outcome = await vm.save(name.text);
                            if (!context.mounted) return;
                            switch (outcome) {
                              case UiActionSuccess<String>():
                                context.pop();
                              case UiActionFailure<String>(:final error):
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.message)),
                                );
                            }
                          },
                        ),
                      ],
                    ),
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
