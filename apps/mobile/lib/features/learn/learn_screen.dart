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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final deckHeight = (screenHeight * 0.54).clamp(360.0, 540.0).toDouble();

    return NylaPage(
      title: 'Learn',
      subtitle: 'A small deck of things worth knowing.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrowseBar(
            category: selected,
            query: query,
            total: cards.length,
            onTap: _openBrowse,
          ),
          const SizedBox(height: 14),
          if (cards.isEmpty)
            _EmptyDeck(onReset: _resetBrowse)
          else ...[
            _DeckHeader(index: index, total: cards.length),
            const SizedBox(height: 9),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            _DeckProgress(index: index, total: cards.length),
          ],
          const SizedBox(height: 24),
          const NylaInlineNote(
            icon: Icons.verified_rounded,
            title: 'Reviewed, then rewritten for real life',
            body:
                'The guidance stays on the card. References are there when you want to verify it, not as homework.',
            accent: Color(0xFF4C7565),
          ),
          const SizedBox(height: 92),
        ],
      ),
    );
  }

  Future<void> _openBrowse() async {
    await NylaHaptics.select();
    if (!mounted) return;
    final result = await showModalBottomSheet<_BrowseSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BrowseSheet(
        initialCategory: selected,
        initialQuery: query,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      selected = result.category;
      query = result.query;
      currentIndex = 0;
    });
    _resetDeck();
  }

  void _resetBrowse() {
    NylaHaptics.select();
    setState(() {
      selected = null;
      query = '';
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

class _BrowseSelection {
  const _BrowseSelection({required this.category, required this.query});

  final TipCategory? category;
  final String query;
}

class _BrowseBar extends StatelessWidget {
  const _BrowseBar({
    required this.category,
    required this.query,
    required this.total,
    required this.onTap,
  });

  final TipCategory? category;
  final String query;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    final title = hasQuery
        ? '“${query.trim()}”'
        : category == null
            ? 'Browse the deck'
            : _categoryName(category!);
    final subtitle = category == null
        ? '$total card${total == 1 ? '' : 's'} · all topics'
        : '$total card${total == 1 ? '' : 's'} · ${_categoryName(category!).toLowerCase()}';

    return NylaPressable(
      onTap: onTap,
      semanticsLabel: 'Browse and search learning cards',
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.fromLTRB(15, 11, 13, 11),
        decoration: BoxDecoration(
          color: NylaColors.paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NylaColors.outline),
          boxShadow: const [
            BoxShadow(color: Color(0x0C2A111E), blurRadius: 22, offset: Offset(0, 9)),
          ],
        ),
        child: Row(
          children: [
            const NylaIconToken(
              icon: Icons.search_rounded,
              size: 38,
              background: NylaColors.lavenderSoft,
              foreground: NylaColors.wine,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.tune_rounded, color: NylaColors.violet, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BrowseSheet extends StatefulWidget {
  const _BrowseSheet({required this.initialCategory, required this.initialQuery});

  final TipCategory? initialCategory;
  final String initialQuery;

  @override
  State<_BrowseSheet> createState() => _BrowseSheetState();
}

class _BrowseSheetState extends State<_BrowseSheet> {
  late TipCategory? category = widget.initialCategory;
  late final TextEditingController controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NylaOverline('Browse the deck'),
            const SizedBox(height: 10),
            Text(
              'Find what you need',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 27),
            ),
            const SizedBox(height: 7),
            Text(
              'Search by a word, or narrow the deck to one topic.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Cramps, flow, products…',
                prefixIcon: Icon(Icons.search_rounded, color: NylaColors.violet),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: category == null,
                  onSelected: (_) {
                    NylaHaptics.select();
                    setState(() => category = null);
                  },
                ),
                for (final value in TipCategory.values)
                  ChoiceChip(
                    label: Text(_categoryName(value)),
                    selected: category == value,
                    onSelected: (_) {
                      NylaHaptics.select();
                      setState(() => category = value);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      controller.clear();
                      setState(() => category = null);
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      NylaHaptics.confirm();
                      Navigator.pop(
                        context,
                        _BrowseSelection(
                          category: category,
                          query: controller.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Show cards'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: NylaColors.wine),
            ),
            Text(' / $total', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            const Icon(Icons.swipe_rounded, size: 17, color: NylaColors.violet),
            const SizedBox(width: 6),
            Text(
              'Swipe',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.8),
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
            borderRadius: _cardRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ),
      );
}

class _KnowledgeCard extends StatefulWidget {
  const _KnowledgeCard({required this.tip, super.key});

  final HealthTip tip;

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
            transform: showBack ? (Matrix4.identity()..rotateY(math.pi)) : Matrix4.identity(),
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
  bottomLeft: Radius.circular(27),
  bottomRight: Radius.circular(19),
);

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.tip, required this.palette, required this.onOpen});

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onOpen,
        semanticsLabel: '${tip.title}. Turn card for full details.',
        borderRadius: _cardRadius,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF765166), Color(0xFF4D2C3D), Color(0xFF351727)],
              stops: [0, 0.55, 1],
            ),
            borderRadius: _cardRadius,
            boxShadow: [
              BoxShadow(color: Color(0x3A351727), blurRadius: 36, offset: Offset(0, 17)),
            ],
          ),
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
                  final compact = constraints.maxHeight < 405;
                  final horizontal = compact ? 20.0 : 24.0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      compact ? 18 : 22,
                      horizontal,
                      compact ? 17 : 21,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _FrontCategoryBadge(category: tip.category),
                            const Spacer(),
                            Container(
                              width: compact ? 36 : 42,
                              height: compact ? 36 : 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _categoryIcon(tip.category),
                                color: Colors.white,
                                size: compact ? 18 : 21,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 13 : 18),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tip.title,
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        color: Colors.white,
                                        fontSize: compact ? 27 : 32,
                                        height: 1.04,
                                        letterSpacing: -0.7,
                                      ),
                                ),
                                SizedBox(height: compact ? 13 : 17),
                                _FrontTakeaway(text: tip.flash),
                                if (!compact && tip.details.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    tip.details.first,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.76),
                                          height: 1.45,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 9 : 12),
                        Container(
                          height: compact ? 42 : 46,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: palette.accent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.flip_rounded, color: Colors.white, size: 15),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Turn card',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
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

class _FrontCategoryBadge extends StatelessWidget {
  const _FrontCategoryBadge({required this.category});

  final TipCategory category;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          _categoryName(category).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.4,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
      );
}

class _FrontTakeaway extends StatelessWidget {
  const _FrontTakeaway({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THE TAKEAWAY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 9.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ],
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
            Container(height: 7, color: palette.accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 12, 3),
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
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 27),
                    ),
                    const SizedBox(height: 15),
                    _Takeaway(text: tip.flash, accent: palette.accent),
                    const SizedBox(height: 20),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink),
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
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 27),
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
                            Text(source.organization, style: Theme.of(context).textTheme.titleMedium),
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
    final glow = Paint()
      ..color = accent.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(size.width * 0.87, size.height * 0.2), size.width * 0.26, glow);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.045);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.91, size.height * 0.17),
        radius: size.width * 0.28,
      ),
      -0.8,
      2.5,
      false,
      paint,
    );
    paint
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.96, size.height * 0.22),
        radius: size.width * 0.18,
      ),
      1.0,
      3.0,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CardMotifPainter oldDelegate) => oldDelegate.accent != accent;
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => NylaPaperSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NylaInlineNote(
              icon: Icons.search_off_rounded,
              title: 'Nothing matched that search',
              body: 'Try a shorter phrase, or return to the full deck.',
              accent: NylaColors.violet,
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onReset, child: const Text('Show all cards')),
          ],
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
