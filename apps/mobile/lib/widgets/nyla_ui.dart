import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/nyla_theme.dart';

class NylaPressable extends StatefulWidget {
  const NylaPressable({
    required this.child,
    this.onTap,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
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
      duration: const Duration(milliseconds: 110),
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
    this.padding = const EdgeInsets.all(18),
    this.color = NylaColors.paper,
    this.radius = const BorderRadius.all(Radius.circular(20)),
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
          border: border ? Border.all(color: NylaColors.outline) : null,
          boxShadow: shadow
              ? const [
                  BoxShadow(
                    color: Color(0x0A30213F),
                    blurRadius: 20,
                    offset: Offset(0, 8),
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
    this.color = NylaColors.violet,
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
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
}

class NylaIconToken extends StatelessWidget {
  const NylaIconToken({
    required this.icon,
    this.background = NylaColors.lavenderSoft,
    this.foreground = NylaColors.violet,
    this.size = 42,
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
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: foreground, size: size * 0.47),
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
      resolvedTrailing = TextButton(onPressed: onAction, child: Text(actionLabel!));
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
                const SizedBox(height: 6),
              ],
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.2),
                ),
              ],
            ],
          ),
        ),
        if (resolvedTrailing != null) ...[
          const SizedBox(width: 10),
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
    this.accent = NylaColors.violet,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NylaIconToken(
              icon: icon,
              size: 38,
              background: Colors.white.withValues(alpha: 0.86),
              foreground: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(body, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
}

class NylaHairline extends StatelessWidget {
  const NylaHairline({this.margin = EdgeInsets.zero, super.key});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        height: 1,
        color: NylaColors.outline,
      );
}

class NylaPillTabs extends StatelessWidget {
  const NylaPillTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: NylaPressable(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? NylaColors.lavenderSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selectedIndex ? NylaColors.wine : NylaColors.mutedInk,
                      fontSize: 11.5,
                      fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (i != labels.length - 1) const SizedBox(width: 4),
          ],
        ],
      );
}

class NylaBloomMark extends StatelessWidget {
  const NylaBloomMark({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _NylaBloomPainter()),
      );
}

class _NylaBloomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    final petals = <Color>[
      NylaColors.lavender,
      const Color(0xFFC8A9DE),
      NylaColors.iris,
      const Color(0xFFC8A9DE),
      NylaColors.lavender,
    ];

    for (var i = 0; i < petals.length; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      final spread = (i - 2) * 0.32;
      canvas.rotate(spread);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -size.height * 0.18),
          width: size.width * 0.28,
          height: size.height * 0.5,
        ),
        Paint()..color = petals[i].withValues(alpha: i == 2 ? 1 : 0.86),
      );
      canvas.restore();
    }
    canvas.drawCircle(center, size.width * 0.075, Paint()..color = NylaColors.wine);
    final stem = Paint()
      ..color = NylaColors.wine
      ..strokeWidth = math.max(1.2, size.width * 0.055)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center + Offset(0, size.height * 0.02), Offset(size.width * 0.5, size.height * 0.95), stem);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
