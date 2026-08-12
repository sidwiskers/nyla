import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_content/health_content.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/theme/nyla_theme.dart';
import '../../widgets/nyla_page.dart';
import '../../widgets/nyla_ui.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final PageController _controller = PageController(viewportFraction: 0.93);
  TipCategory? selected;
  String query = '';
  int currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = healthTips
        .where((tip) => selected == null || tip.category == selected)
        .where((tip) => tip.matches(query))
        .toList(growable: false);
    final index = cards.isEmpty ? 0 : currentIndex.clamp(0, cards.length - 1);
    final deckHeight =
        (MediaQuery.sizeOf(context).height * 0.63).clamp(480.0, 650.0).toDouble();

    return NylaPage(
      title: 'Learn',
      subtitle: 'Useful enough to remember. Calm enough to revisit.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                query = value;
                currentIndex = 0;
              });
              _resetDeck();
            },
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Find cramps, flow, products…',
              prefixIcon: Icon(Icons.search_rounded, color: NylaColors.violet),
            ),
          ),
          const SizedBox(height: 12),
          _CategoryStrip(selected: selected, onSelected: _chooseCategory),
          const SizedBox(height: 24),
          if (cards.isEmpty)
            const _EmptyDeck()
          else ...[
            _DeckHeader(index: index, total: cards.length),
            const SizedBox(height: 11),
            SizedBox(
              height: deckHeight,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  const Positioned(
                    left: 31,
                    right: 31,
                    top: 18,
                    bottom: 0,
                    child: _BackCard(
                      rotation: -0.018,
                      color: NylaColors.lavenderSoft,
                    ),
                  ),
                  const Positioned(
                    left: 24,
                    right: 24,
                    top: 10,
                    bottom: 9,
                    child: _BackCard(
                      rotation: 0.012,
                      color: NylaColors.peachSoft,
                    ),
                  ),
                  PageView.builder(
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    itemCount: cards.length,
                    onPageChanged: (value) {
                      NylaHaptics.select();
                      setState(() => currentIndex = value);
                    },
                    itemBuilder: (context, cardIndex) => Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
                      child: _KnowledgeCard(
                        key: ValueKey(cards[cardIndex].id),
                        tip: cards[cardIndex],
                        index: cardIndex,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DeckProgress(index: index, total: cards.length),
          ],
          const SizedBox(height: 30),
          const NylaInlineNote(
            icon: Icons.verified_rounded,
            title: 'Written to be useful first',
            body:
                'Each card is reviewed against trusted medical sources. References stay available without taking over the reading experience.',
            accent: Color(0xFF4C7565),
          ),
          const SizedBox(height: 92),
        ],
      ),
    );
  }

  void _chooseCategory(TipCategory? category) {
    NylaHaptics.select();
    setState(() {
      selected = category;
      currentIndex = 0;
    });
    _resetDeck();
  }

  void _resetDeck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(0);
    });
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});

  final TipCategory? selected;
  final ValueChanged<TipCategory?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            const SizedBox(width: 7),
            for (final category in TipCategory.values) ...[
              ChoiceChip(
                label: Text(_categoryName(category)),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
              const SizedBox(width: 7),
            ],
          ],
        ),
      );
}

class _DeckHeader extends StatelessWidget {
  const _DeckHeader({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Text(
              '${index + 1}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: NylaColors.wine),
            ),
            Text(' / $total', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            const Icon(Icons.swipe_rounded, size: 17, color: NylaColors.violet),
            const SizedBox(width: 6),
            Text(
              'Swipe the deck',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      );
}

class _BackCard extends StatelessWidget {
  const _BackCard({required this.rotation, required this.color});

  final double rotation;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: rotation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(34),
              topRight: Radius.circular(34),
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ),
      );
}

class _KnowledgeCard extends StatefulWidget {
  const _KnowledgeCard({required this.tip, required this.index, super.key});

  final HealthTip tip;
  final int index;

  @override
  State<_KnowledgeCard> createState() => _KnowledgeCardState();
}

class _KnowledgeCardState extends State<_KnowledgeCard> {
  bool detailed = false;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(widget.tip.category);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: detailed ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) {
        final angle = value * math.pi;
        final showBack = angle > math.pi / 2;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle);
        return Transform(
          alignment: Alignment.center,
          transform: matrix,
          child: Transform(
            alignment: Alignment.center,
            transform: showBack
                ? (Matrix4.identity()..rotateY(math.pi))
                : Matrix4.identity(),
            child: showBack
                ? _DetailedCard(
                    tip: widget.tip,
                    palette: palette,
                    onClose: _toggle,
                  )
                : _QuickCard(
                    tip: widget.tip,
                    palette: palette,
                    onOpen: _toggle,
                  ),
          ),
        );
      },
    );
  }

  void _toggle() {
    NylaHaptics.select();
    setState(() => detailed = !detailed);
  }
}

const _cardRadius = BorderRadius.only(
  topLeft: Radius.circular(34),
  topRight: Radius.circular(34),
  bottomLeft: Radius.circular(26),
  bottomRight: Radius.circular(18),
);

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.tip, required this.palette, required this.onOpen});

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onOpen,
        borderRadius: _cardRadius,
        child: Container(
          decoration: _cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CardMotifPainter(accent: palette.accent),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 470;
                  final horizontal = compact ? 21.0 : 25.0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      compact ? 20 : 24,
                      horizontal,
                      compact ? 18 : 23,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: _CategoryBadge(
                                category: tip.category,
                                palette: palette,
                              ),
                            ),
                            const Spacer(),
                            NylaIconToken(
                              icon: _categoryIcon(tip.category),
                              size: compact ? 38 : 44,
                              background: palette.soft,
                              foreground: palette.accent,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 14 : 21),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tip.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontSize: compact ? 28 : 33,
                                        height: 1.04,
                                      ),
                                ),
                                SizedBox(height: compact ? 14 : 19),
                                _Takeaway(text: tip.flash, accent: palette.accent),
                                if (tip.details.isNotEmpty) ...[
                                  SizedBox(height: compact ? 13 : 17),
                                  Text(
                                    tip.details.first,
                                    maxLines: compact ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: NylaColors.mutedInk,
                                          height: 1.46,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 11 : 15),
                        Row(
                          children: [
                            Container(
                              width: compact ? 36 : 40,
                              height: compact ? 36 : 40,
                              decoration: BoxDecoration(
                                color: palette.accent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.flip_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'Turn card',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: NylaColors.wine),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: NylaColors.wine,
                              size: 19,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _DetailedCard extends StatelessWidget {
  const _DetailedCard({required this.tip, required this.palette, required this.onClose});

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        decoration: _cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(height: 8, color: palette.accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 13, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CategoryBadge(category: tip.category, palette: palette),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Turn to front',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    color: NylaColors.wine,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 27),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 27),
                    ),
                    const SizedBox(height: 16),
                    _Takeaway(text: tip.flash, accent: palette.accent),
                    const SizedBox(height: 22),
                    for (final paragraph in tip.details) ...[
                      Text(paragraph, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 15),
                    ],
                    if (tip.practical.isNotEmpty)
                      _GuidanceSection(
                        eyebrow: 'Try this',
                        title: 'What can help',
                        icon: Icons.favorite_rounded,
                        items: tip.practical,
                        accent: const Color(0xFF4C7565),
                        surface: NylaColors.sageSoft,
                      ),
                    if (tip.seekCare.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _GuidanceSection(
                        eyebrow: 'Care note',
                        title: 'When to check in',
                        icon: Icons.health_and_safety_rounded,
                        items: tip.seekCare,
                        accent: NylaColors.warning,
                        surface: NylaColors.peachSoft,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _ReferencesButton(tip: tip),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

BoxDecoration _cardDecoration() => const BoxDecoration(
      color: NylaColors.paper,
      borderRadius: _cardRadius,
      boxShadow: [
        BoxShadow(color: Color(0x222A111E), blurRadius: 34, offset: Offset(0, 16)),
      ],
    );

class _Takeaway extends StatelessWidget {
  const _Takeaway({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 62,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE TAKEAWAY',
                  style: TextStyle(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: NylaColors.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.42,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _GuidanceSection extends StatelessWidget {
  const _GuidanceSection({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.items,
    required this.accent,
    required this.surface,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final List<String> items;
  final Color accent;
  final Color surface;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NylaIconToken(
                  icon: icon,
                  size: 39,
                  background: NylaColors.paper.withValues(alpha: 0.75),
                  foreground: accent,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontSize: 9.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.95,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: NylaColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
            ],
          ],
        ),
      );
}

class _ReferencesButton extends StatelessWidget {
  const _ReferencesButton({required this.tip});

  final HealthTip tip;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: () {
          NylaHaptics.select();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => _SourcesSheet(tip: tip),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: NylaColors.lavenderMist,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NylaColors.outline),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: NylaColors.violet, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'References · reviewed ${_reviewDate(tip.lastReviewed)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: NylaColors.faintInk),
            ],
          ),
        ),
      );
}

class _SourcesSheet extends StatelessWidget {
  const _SourcesSheet({required this.tip});

  final HealthTip tip;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.42,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
          children: [
            const NylaOverline('References'),
            const SizedBox(height: 10),
            Text(
              'Reviewed sources',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 27),
            ),
            const SizedBox(height: 7),
            Text(
              'These support the guidance above. The card is written to stand on its own.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final source in tip.sources) ...[
              NylaPressable(
                onTap: () => launchUrl(
                  Uri.parse(source.url),
                  mode: LaunchMode.externalApplication,
                ),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NylaColors.cream,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: NylaColors.outline),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NylaIconToken(
                        icon: Icons.open_in_new_rounded,
                        size: 39,
                        background: NylaColors.lavenderSoft,
                        foreground: NylaColors.violet,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.organization,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(source.title, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.palette});

  final TipCategory category;
  final _CardPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: palette.soft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _categoryName(category).toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.accent,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.85,
          ),
        ),
      );
}

class _DeckProgress extends StatelessWidget {
  const _DeckProgress({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final visible = math.min(total, 8);
    final selected = index.clamp(0, visible - 1);
    return Row(
      children: [
        for (var i = 0; i < visible; i++) ...[
          Expanded(
            flex: i == selected ? 3 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 4,
              decoration: BoxDecoration(
                color: i == selected ? NylaColors.wine : NylaColors.outlineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (i != visible - 1) const SizedBox(width: 4),
        ],
        if (total > visible) ...[
          const SizedBox(width: 8),
          Text(
            '+${total - visible}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.5),
          ),
        ],
      ],
    );
  }
}

class _CardMotifPainter extends CustomPainter {
  const _CardMotifPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.055);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.88, size.height * 0.16),
        radius: size.width * 0.28,
      ),
      -0.8,
      2.5,
      false,
      paint,
    );
    paint
      ..strokeWidth = 5
      ..color = accent.withValues(alpha: 0.075);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.94, size.height * 0.21),
        radius: size.width * 0.18,
      ),
      1.0,
      3.0,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CardMotifPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) => const NylaPaperSurface(
        child: NylaInlineNote(
          icon: Icons.search_off_rounded,
          title: 'Nothing matched that search',
          body: 'Try a shorter phrase or switch back to All.',
          accent: NylaColors.violet,
        ),
      );
}

class _CardPalette {
  const _CardPalette({required this.accent, required this.soft});

  final Color accent;
  final Color soft;
}

_CardPalette _paletteFor(TipCategory category) => switch (category) {
      TipCategory.cycle => const _CardPalette(
          accent: NylaColors.rose,
          soft: NylaColors.roseWash,
        ),
      TipCategory.understanding => const _CardPalette(
          accent: NylaColors.violet,
          soft: NylaColors.lavenderSoft,
        ),
      TipCategory.body => const _CardPalette(
          accent: Color(0xFF6E6651),
          soft: Color(0xFFF2EEE1),
        ),
      TipCategory.care => const _CardPalette(
          accent: Color(0xFF4C7565),
          soft: NylaColors.sageSoft,
        ),
      TipCategory.products => const _CardPalette(
          accent: Color(0xFF8A6048),
          soft: NylaColors.peachSoft,
        ),
      TipCategory.comfort => const _CardPalette(
          accent: Color(0xFF8C6C33),
          soft: Color(0xFFF7EFD5),
        ),
      TipCategory.symptoms => const _CardPalette(
          accent: NylaColors.iris,
          soft: NylaColors.lavenderMist,
        ),
      TipCategory.seekCare => const _CardPalette(
          accent: NylaColors.warning,
          soft: Color(0xFFF7E5E0),
        ),
    };

String _categoryName(TipCategory category) => switch (category) {
      TipCategory.cycle => 'Cycle',
      TipCategory.understanding => 'Understanding',
      TipCategory.body => 'Body',
      TipCategory.care => 'Care',
      TipCategory.products => 'Products',
      TipCategory.comfort => 'Comfort',
      TipCategory.symptoms => 'Symptoms',
      TipCategory.seekCare => 'Seek care',
    };

IconData _categoryIcon(TipCategory category) => switch (category) {
      TipCategory.cycle => Icons.autorenew_rounded,
      TipCategory.understanding => Icons.lightbulb_outline_rounded,
      TipCategory.body => Icons.accessibility_new_rounded,
      TipCategory.care => Icons.spa_rounded,
      TipCategory.products => Icons.inventory_2_outlined,
      TipCategory.comfort => Icons.favorite_outline_rounded,
      TipCategory.symptoms => Icons.monitor_heart_outlined,
      TipCategory.seekCare => Icons.health_and_safety_outlined,
    };

String _reviewDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.year}';
}
