import 'package:flutter/material.dart';

import '../core/theme/nyla_theme.dart';

class NylaPage extends StatelessWidget {
  const NylaPage({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.headerBottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? headerBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title.trim().isNotEmpty || subtitle != null || trailing != null || headerBottom != null;
    return ColoredBox(
      color: NylaColors.canvas,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            if (hasHeader)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _PageHeader(
                        title: title,
                        subtitle: subtitle,
                        trailing: trailing,
                        bottom: headerBottom,
                      ),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, hasHeader ? 8 : 16, 20, 34),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.trim().isNotEmpty || trailing != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.trim().isNotEmpty)
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
            ),
          ],
          if (bottom != null) ...[
            const SizedBox(height: 15),
            bottom!,
          ],
        ],
      );
}
