import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_appearance_theme.dart';
import '../../../design_system/theme/app_color_scheme.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';

Future<void> showSettingsColorPicker({
  required BuildContext context,
  required String title,
  required int color,
  required ValueChanged<int> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight:
          MediaQuery.sizeOf(context).height *
          AppComponentTokens.selectionSheetMaxHeightFactor,
    ),
    builder: (context) =>
        _SettingsColorPicker(title: title, color: color, onChanged: onChanged),
  );
}

class _SettingsColorPicker extends StatefulWidget {
  const _SettingsColorPicker({
    required this.title,
    required this.color,
    required this.onChanged,
  });

  final String title;
  final int color;
  final ValueChanged<int> onChanged;

  @override
  State<_SettingsColorPicker> createState() => _SettingsColorPickerState();
}

class _SettingsColorPickerState extends State<_SettingsColorPicker> {
  final _formKey = GlobalKey<FormState>();
  late int _color;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _color = widget.color;
    _hexController = TextEditingController(text: _hex(_color));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _hex(int color) =>
      (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _choose(int value, {bool syncText = true}) {
    setState(() => _color = value);
    if (syncText) {
      final text = _hex(value);
      _hexController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    widget.onChanged(value);
  }

  void _changeChannel(int shift, double value) {
    _choose((_color & ~(0xFF << shift)) | (value.round() << shift));
  }

  void _finish() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            0,
            AppSpacing.space20,
            AppSpacing.space20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: textStyles.sectionTitleStrong,
                      ),
                    ),
                    TextButton(onPressed: _finish, child: const Text('完成')),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                Wrap(
                  spacing: AppSpacing.space8,
                  runSpacing: AppSpacing.space8,
                  children: [
                    for (final color in AppAppearanceTheme.colorChoices)
                      Semantics(
                        button: true,
                        selected: color.toARGB32() == _color,
                        label: '#${_hex(color.toARGB32())}',
                        child: InkResponse(
                          onTap: () => _choose(color.toARGB32()),
                          customBorder: const CircleBorder(),
                          child: CircleAvatar(
                            radius: AppSpacing.space20,
                            backgroundColor: color,
                            foregroundColor: AppColorSchemes.foregroundFor(
                              color,
                            ),
                            child: color.toARGB32() == _color
                                ? const Icon(RemixIcons.check_line)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space16),
                TextFormField(
                  controller: _hexController,
                  decoration: const InputDecoration(
                    labelText: 'HEX 色值',
                    prefixText: '#',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _finish(),
                  validator: (value) =>
                      (value?.length ?? 0) == 6 ? null : '请输入 6 位 HEX 色值',
                  onChanged: (value) {
                    if (value.length == 6) {
                      _choose(
                        int.parse('FF$value', radix: 16),
                        syncText: false,
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.space12),
                for (final channel in const [('红', 16), ('绿', 8), ('蓝', 0)])
                  Row(
                    children: [
                      Text(channel.$1, style: textStyles.settingsTitle),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Slider(
                          value: ((_color >> channel.$2) & 0xFF).toDouble(),
                          max: 255,
                          divisions: 255,
                          label: '${(_color >> channel.$2) & 0xFF}',
                          onChanged: (value) =>
                              _changeChannel(channel.$2, value),
                        ),
                      ),
                      SizedBox(
                        width: AppSpacing.space40,
                        child: Text(
                          '${(_color >> channel.$2) & 0xFF}',
                          textAlign: TextAlign.end,
                          style: textStyles.listSupporting,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
