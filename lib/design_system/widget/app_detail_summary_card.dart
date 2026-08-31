import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_surface.dart';

enum AppDetailSummaryCardStyle { accent, surface }

class AppDetailSummaryCardItem {
  const AppDetailSummaryCardItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.span = 1,
  }) : assert(span == 1 || span == 2);

  final String label;
  final String value;
  final Color? valueColor;

  /// Supporting items can span both columns when their value is long.
  final int span;
}

class AppDetailSummaryCard extends StatelessWidget {
  const AppDetailSummaryCard({
    required this.title,
    required this.mainItems,
    required this.supportingItems,
    this.headerTrailing,
    this.style = AppDetailSummaryCardStyle.surface,
    super.key,
  });

  final String title;
  final Widget? headerTrailing;
  final List<AppDetailSummaryCardItem> mainItems;
  final List<AppDetailSummaryCardItem> supportingItems;
  final AppDetailSummaryCardStyle style;

  bool get _isAccent => style == AppDetailSummaryCardStyle.accent;

  @override
  Widget build(BuildContext context) {
    if (_isAccent) {
      return _buildAccent(context);
    }
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space14),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildAccent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final gradientEnd =
        Color.lerp(colors.primary, colors.primaryContainer, 0.36) ??
        colors.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, gradientEnd],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: title, trailing: headerTrailing, accent: _isAccent),
        if (mainItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space18),
          _ItemGrid(
            items: mainItems,
            columns: mainItems.length < 3 ? mainItems.length : 3,
            accent: _isAccent,
            main: true,
          ),
        ],
        if (supportingItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space18),
          _SupportingGrid(items: supportingItems, accent: _isAccent),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.trailing,
    required this.accent,
  });

  final String title;
  final Widget? trailing;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: accent ? styles.onPrimaryLabel : styles.groupTitle,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.space12),
          trailing!,
        ],
      ],
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.items,
    required this.columns,
    required this.accent,
    required this.main,
  });

  final List<AppDetailSummaryCardItem> items;
  final int columns;
  final bool accent;
  final bool main;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < items.length; start += columns) {
      final rowItems = items.skip(start).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < columns; index++) ...[
              Expanded(
                child: index < rowItems.length
                    ? _Item(item: rowItems[index], accent: accent, main: main)
                    : const SizedBox.shrink(),
              ),
              if (index < columns - 1)
                const SizedBox(width: AppSpacing.space10),
            ],
          ],
        ),
      );
      if (start + columns < items.length) {
        rows.add(const SizedBox(height: AppSpacing.space10));
      }
    }
    return Column(children: rows);
  }
}

class _SupportingGrid extends StatelessWidget {
  const _SupportingGrid({required this.items, required this.accent});

  final List<AppDetailSummaryCardItem> items;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final rows = <List<AppDetailSummaryCardItem>>[];
    var current = <AppDetailSummaryCardItem>[];
    var remaining = 2;
    for (final item in items) {
      final span = item.span;
      if (span > remaining && current.isNotEmpty) {
        rows.add(current);
        current = <AppDetailSummaryCardItem>[];
        remaining = 2;
      }
      current.add(item);
      remaining -= span;
      if (remaining == 0) {
        rows.add(current);
        current = <AppDetailSummaryCardItem>[];
        remaining = 2;
      }
    }
    if (current.isNotEmpty) rows.add(current);

    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _rowChildren(rows[rowIndex], accent),
          ),
          if (rowIndex < rows.length - 1)
            const SizedBox(height: AppSpacing.space10),
        ],
      ],
    );
  }

  List<Widget> _rowChildren(List<AppDetailSummaryCardItem> row, bool accent) {
    final children = <Widget>[];
    var used = 0;
    for (final item in row) {
      if (used > 0) {
        children.add(const SizedBox(width: AppSpacing.space10));
      }
      children.add(
        Expanded(
          flex: item.span,
          child: _Item(item: item, accent: accent, main: false),
        ),
      );
      used += item.span;
    }
    if (used < 2) {
      if (used > 0) children.add(const SizedBox(width: AppSpacing.space10));
      children.add(const Expanded(child: SizedBox.shrink()));
    }
    return children;
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.accent, required this.main});

  final AppDetailSummaryCardItem item;
  final bool accent;
  final bool main;

  @override
  Widget build(BuildContext context) {
    if (accent) {
      return _AccentItem(item: item, main: main);
    }
    return _SurfaceItem(item: item, main: main);
  }
}

class _AccentItem extends StatelessWidget {
  const _AccentItem({required this.item, required this.main});

  final AppDetailSummaryCardItem item;
  final bool main;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    if (!main) {
      return Text(
        item.label.isEmpty ? item.value : '${item.label} ${item.value}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: styles.onPrimaryTiny.copyWith(
          color: item.valueColor ?? styles.onPrimaryTiny.color,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: styles.onPrimaryTiny,
        ),
        const SizedBox(height: AppSpacing.space6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            item.value,
            maxLines: 1,
            style: styles.metricValue.copyWith(
              color: item.valueColor ?? colors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SurfaceItem extends StatelessWidget {
  const _SurfaceItem({required this.item, required this.main});

  final AppDetailSummaryCardItem item;
  final bool main;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    if (main) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.detailLabel,
          ),
          const SizedBox(height: AppSpacing.space4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              maxLines: 1,
              style: styles.amountPrimary.copyWith(
                color: item.valueColor ?? colors.onSurface,
              ),
            ),
          ),
        ],
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          if (item.label.isNotEmpty)
            TextSpan(
              text: '${item.label}：',
              style: styles.formLabel.copyWith(color: colors.onSurfaceVariant),
            ),
          TextSpan(
            text: item.value,
            style: styles.formLabel.copyWith(
              color:
                  item.valueColor ??
                  (item.label.isEmpty
                      ? colors.onSurfaceVariant
                      : colors.onSurface),
            ),
          ),
        ],
      ),
      maxLines: item.span == 2 ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
