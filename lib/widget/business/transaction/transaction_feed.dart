import 'package:flutter/material.dart';

import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';

import 'empty_transaction_card.dart';
import 'transaction_day_card.dart';

const _loadMoreTriggerExtent = 480.0;

class TransactionFeedScrollView extends StatefulWidget {
  const TransactionFeedScrollView({
    required this.groups,
    super.key,
    this.leading = const [],
    this.padding = EdgeInsets.zero,
    this.bottomPadding = 0,
    this.emptyMessage = '暂无交易记录',
    this.emptyState,
    this.showDailyTotals = true,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreErrorMessage,
    this.onLoadMore,
    this.physics = const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
  });

  final List<Widget> leading;
  final List<TransactionDayGroup> groups;
  final EdgeInsets padding;
  final double bottomPadding;
  final String emptyMessage;
  final Widget? emptyState;
  final bool showDailyTotals;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final VoidCallback? onLoadMore;
  final ScrollPhysics physics;

  @override
  State<TransactionFeedScrollView> createState() =>
      _TransactionFeedScrollViewState();
}

class _TransactionFeedScrollViewState extends State<TransactionFeedScrollView> {
  bool _loadMoreRequested = false;

  @override
  void didUpdateWidget(TransactionFeedScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasMore || (oldWidget.isLoadingMore && !widget.isLoadingMore)) {
      _loadMoreRequested = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.hasMore &&
            !widget.isLoadingMore &&
            widget.loadMoreErrorMessage == null &&
            !_loadMoreRequested &&
            notification.metrics.extentAfter < _loadMoreTriggerExtent) {
          _loadMoreRequested = true;
          widget.onLoadMore?.call();
        }
        return false;
      },
      child: CustomScrollView(
        physics: widget.physics,
        slivers: [
          if (widget.leading.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                widget.padding.left,
                widget.padding.top,
                widget.padding.right,
                0,
              ),
              sliver: SliverList.list(children: widget.leading),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              widget.padding.left,
              widget.leading.isEmpty ? widget.padding.top : 0,
              widget.padding.right,
              0,
            ),
            sliver: _TransactionFeedSliver(
              groups: widget.groups,
              emptyState:
                  widget.emptyState ??
                  EmptyTransactionCard(message: widget.emptyMessage),
              showDailyTotals: widget.showDailyTotals,
              isLoadingMore: widget.isLoadingMore,
              loadMoreErrorMessage: widget.loadMoreErrorMessage,
              onRetryLoadMore: widget.onLoadMore,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: widget.padding.bottom + widget.bottomPadding,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionFeedSliver extends StatelessWidget {
  const _TransactionFeedSliver({
    required this.groups,
    required this.emptyState,
    required this.showDailyTotals,
    required this.isLoadingMore,
    required this.loadMoreErrorMessage,
    required this.onRetryLoadMore,
  });

  final List<TransactionDayGroup> groups;
  final Widget emptyState;
  final bool showDailyTotals;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final VoidCallback? onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty && !isLoadingMore && loadMoreErrorMessage == null) {
      return SliverToBoxAdapter(child: emptyState);
    }

    final hasFooter = isLoadingMore || loadMoreErrorMessage != null;
    final itemCount = groups.length + (hasFooter ? 1 : 0);
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == groups.length) {
          final errorMessage = loadMoreErrorMessage;
          if (errorMessage != null) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: onRetryLoadMore,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.only(top: AppSpacing.space12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                index < groups.length - 1 || hasFooter ? AppSpacing.space10 : 0,
          ),
          child: TransactionDayCard(
            group: groups[index],
            showDailyTotals: showDailyTotals,
          ),
        );
      },
    );
  }
}
