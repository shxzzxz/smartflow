import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/intake/intake_recognition_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/capture_review_view_model.dart';
import '../../../design_system/widget/app_scaffold.dart';

class CaptureReviewPage extends ConsumerStatefulWidget {
  const CaptureReviewPage({this.shareId, super.key});

  final String? shareId;

  @override
  ConsumerState<CaptureReviewPage> createState() => _CaptureReviewPageState();
}

class _CaptureReviewPageState extends ConsumerState<CaptureReviewPage> {
  final Object _sessionKey = Object();
  String? _imageId;

  NotifierProvider<CaptureReviewViewModel, CaptureReviewState>
  get _viewModelProvider => captureReviewViewModelProvider(_sessionKey);

  bool get _isCurrent =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    _imageId = widget.shareId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recognize());
  }

  Future<void> _pickImage() async {
    final outcome = await ref.read(_viewModelProvider.notifier).pickImage();
    if (!mounted) return;
    // 选图取消和分享导航可能同帧到达，先让路由替换完成再处理旧结果。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_isCurrent) return;
    if (outcome case UiActionSuccess<String?>(:final value)) {
      if (value == null) {
        if (context.canPop()) context.pop();
        return;
      }
      _imageId = value;
      await _recognize();
    }
  }

  Future<void> _recognize() async {
    if (!_isCurrent) return;
    final imageId = _imageId;
    if (imageId == null) {
      await _pickImage();
      return;
    }
    final outcome = await ref
        .read(_viewModelProvider.notifier)
        .recognize(imageId);
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_isCurrent) return;
    switch (outcome) {
      case UiActionSuccess(:final value):
        if (value.prefill != null) {
          final mode = switch (value.payment.scene) {
            PaymentScreenshotScene.transfer => 'transfer',
            PaymentScreenshotScene.income => 'income',
            _ => 'expense',
          };
          context.pushReplacement(
            '/transaction/new?mode=$mode',
            extra: value.prefill,
          );
        }
      case UiActionFailure():
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_viewModelProvider);
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '截图记账'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.recognizing || state.pickingImage) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.space16),
                        Text(state.pickingImage ? '请选择支付或收款截图…' : '正在识别截图…'),
                      ] else ...[
                        if (state.error case final error?)
                          AppStatusBanner(
                            message: error.message,
                            tone: AppStatusBannerTone.warning,
                          )
                        else if (state.review case final review?
                            when review.reviewMessage.isNotEmpty)
                          AppStatusBanner(
                            message: review.reviewMessage,
                            tone: AppStatusBannerTone.warning,
                          )
                        else
                          const Text('选择单笔支付或收款截图。'),
                        const SizedBox(height: AppSpacing.space16),
                        FilledButton(
                          onPressed: _recognize,
                          child: Text(_imageId == null ? '选择截图' : '重试识别'),
                        ),
                        if (_imageId != null)
                          TextButton(
                            onPressed: _pickImage,
                            child: const Text('重新选择截图'),
                          ),
                        TextButton(
                          onPressed: () =>
                              _openManual(state.review?.manualAction),
                          child: Text(_manualLabel(state.review?.manualAction)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openManual(CaptureManualAction? action) {
    switch (action) {
      case CaptureManualAction.transactions:
        context.go('/');
      case CaptureManualAction.accounts:
        context.go('/account');
      case CaptureManualAction.expense:
        context.pushReplacement('/transaction/new?mode=expense');
      case CaptureManualAction.income:
        context.pushReplacement('/transaction/new?mode=income');
      case CaptureManualAction.transfer:
        context.pushReplacement('/transaction/new?mode=transfer');
      case CaptureManualAction.chooseScene:
      case null:
        context.pushReplacement('/transaction/new');
    }
  }
}

String _manualLabel(CaptureManualAction? action) => switch (action) {
  CaptureManualAction.transactions => '前往交易记录',
  CaptureManualAction.accounts => '前往账户还款',
  CaptureManualAction.expense => '手动填写支出',
  CaptureManualAction.income => '手动填写收入',
  CaptureManualAction.transfer => '手动记录转账',
  _ => '手动记账',
};
