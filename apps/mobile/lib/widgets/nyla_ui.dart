import 'package:flutter/material.dart';

import '../core/theme/nyla_theme.dart';

class NylaPressable extends StatefulWidget {
  const NylaPressable({
    required this.child,
    this.onTap,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final BorderRadius borderRadius;
  final String? semanticsLabel;

  @override
  State<NylaPressable> createState() => _NylaPressableState();
}

class _NylaPressableState extends State<NylaPressable> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onHighlightChanged: (value) {
            if (!widget.enabled) return;
            if (mounted) setState(() => pressed = value);
          },
          onTap: widget.enabled ? widget.onTap : null,
          child: widget.child,
        ),
      ),
    );

    if (widget.semanticsLabel == null) return child;
    return Semantics(
      button: true,
      enabled: widget.enabled && widget.onTap != null,
      label: widget.semanticsLabel,
      child: child,
    );
  }
}

class NylaPaperSurface extends StatelessWidget {
  const NylaPaperSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = NylaColors.paper,
    this.radius = const BorderRadius.all(Radius.circular(28)),
    this.border = true,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadius radius;
  final bool border;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: border ? Border.all(color: Colors.white.withValues(alpha: 0.9)) : null,
          boxShadow: shadow
              ? const [
                  BoxShadow(
                    color: Color(0x102A111E),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: child,
      );
}

class NylaOverline extends StatelessWidget {
  const NylaOverline(
    this.text, {
    this.color = NylaColors.rose,
    this.dot = false,
    super.key,
  });

  final String text;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.45,
            ),
          ),
        ],
      );
}

class NylaIconToken extends StatelessWidget {
  const NylaIconToken({
    required this.icon,
    this.background = NylaColors.roseWash,
    this.foreground = NylaColors.wine,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.36),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: foreground, size: size * 0.46),
      );
}

class NylaSectionHeader extends StatelessWidget {
  const NylaSectionHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    Widget? resolvedTrailing = trailing;
    if (resolvedTrailing == null && actionLabel != null && onAction != null) {
      resolvedTrailing = TextButton(
        onPressed: onAction,
        child: Text(actionLabel!),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                NylaOverline(eyebrow!),
                const SizedBox(height: 7),
              ],
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        if (resolvedTrailing != null) ...[
          const SizedBox(width: 12),
          resolvedTrailing,
        ],
      ],
    );
  }
}

class NylaInlineNote extends StatelessWidget {
  const NylaInlineNote({
    required this.icon,
    required this.title,
    required this.body,
    this.accent = NylaColors.rose,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 58,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 14),
          NylaIconToken(
            icon: icon,
            size: 42,
            background: accent.withValues(alpha: 0.1),
            foreground: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      );
}

class NylaHairline extends StatelessWidget {
  const NylaHairline({this.margin = EdgeInsets.zero, super.key});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        height: 1,
        color: NylaColors.outline.withValues(alpha: 0.76),
      );
}
