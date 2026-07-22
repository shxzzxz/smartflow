import 'package:flutter/material.dart';

import '../token/spacing.dart';
import '../widget/app_form_section.dart';
import '../widget/app_plain_form_field.dart';
import '../widget/app_plain_form_row.dart';
import '../widget/app_submit_button.dart';

class AppFormShowcasePage extends StatefulWidget {
  const AppFormShowcasePage({super.key});

  @override
  State<AppFormShowcasePage> createState() => _AppFormShowcasePageState();
}

class _AppFormShowcasePageState extends State<AppFormShowcasePage> {
  final _nameController = TextEditingController(text: '工资卡');
  final _focusController = TextEditingController();
  final _noteController = TextEditingController();
  final _readOnlyController = TextEditingController(text: '由系统自动同步');
  bool _enabled = true;

  @override
  void dispose() {
    _nameController.dispose();
    _focusController.dispose();
    _noteController.dispose();
    _readOnlyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('表单组件')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space20,
          AppSpacing.space16,
          AppSpacing.space20,
          AppSpacing.space24,
        ),
        children: [
          AppFormSection(
            title: '文本输入',
            description: '展示必填、辅助说明和只读状态',
            children: [
              AppPlainTextFormRow(
                label: '账户名称',
                controller: _nameController,
                requiredIndicator: true,
                hintText: '请输入账户名称',
              ),
              AppPlainTextFormRow(
                label: '焦点输入',
                controller: _focusController,
                hintText: '当前获得输入焦点',
                autofocus: true,
              ),
              AppPlainTextFormRow(
                label: '备注',
                controller: _noteController,
                hintText: '请输入备注（可选）',
                supportingText: '最多记录一行简短说明',
              ),
              AppPlainTextFormRow(
                label: '同步状态',
                controller: _readOnlyController,
                readOnly: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          AppFormSection(
            title: '选择与状态',
            description: '展示选择、禁用、开关和错误反馈',
            children: [
              AppPlainSelectFormRow<String>(
                label: '账户',
                value: 'cash',
                valueText: '现金账户',
                placeholder: '请选择账户',
                onTap: (_) {},
              ),
              const AppPlainSelectFormRow<String>(
                label: '禁用字段',
                value: null,
                placeholder: '暂无可选项',
                enabled: false,
              ),
              AppPlainSwitchRow(
                label: '参与统计',
                description: '关闭后仍保留记录，但不计入账户汇总和统计',
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const AppPlainFormRow(
                label: '错误状态',
                errorText: '请选择账户',
                child: AppPlainValueText(text: '未选择'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          AppFormSection(
            title: '提交状态',
            description: '提交中禁用重复操作并显示进度',
            children: [
              AppSubmitButton(label: '保存', loading: true, onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
