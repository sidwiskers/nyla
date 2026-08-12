import 'package:flutter/material.dart';
import 'package:health_content/health_content.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/theme/nyla_theme.dart';
import '../../widgets/nyla_page.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final PageController _controller = PageController(viewportFraction: 0.92);
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
    final deckHeight = (screenHeight * 0.64).clamp(520.0, 680.0).toDouble();

    return NylaPage(
      title: 'Learn',
      subtitle: 'One useful thing at a time.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            onChanged: (value) {
              setState(() {
                query = value;
                currentIndex = 0;
              });
              _resetDeck();
            },
          ),
          const SizedBox(height: 12),
          _CategoryStrip(selected: selected, onSelected: _chooseCategory),
          const SizedBox(height: 20),
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
                  Positioned(
                    left: 32,
                    right: 32,
                    top: 20,
                    bottom: 3,
                    child: Transform.rotate(
                      angle: -0.014,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: NylaColors.lavender.withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 26,
                    right: 26,
                    top: 11,
                    bottom: 11,
                    child: Transform.rotate(
                      angle: 0.011,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: NylaColors.peachSoft,
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
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
                      padding: const EdgeInsets.fromLTRB(5, 0, 5, 18),
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
          const SizedBox(height: 26),
          _EditorialNote(),
          const SizedBox(height: 88),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Find cramps, flow, products…',
          prefixIcon: const Icon(Icons.search_rounded, color: NylaColors.violet),
          suffixIcon: Container(
            margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: NylaColors.lavenderSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 17, color: NylaColors.wine),
          ),
        ),
      );
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
              'Card ${index + 1}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: NylaColors.wine),
            ),
            Text(
              '  of $total',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            const Icon(Icons.swipe_rounded, size: 18, color: NylaColors.violet),
            const SizedBox(width: 6),
            Text('Swipe', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
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
    final palette = _paletteFor(widget.tip.category, widget.index);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.975, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: detailed
          ? _DetailedCard(
              key: const ValueKey('detail'),
              tip: widget.tip,
              palette: palette,
              onClose: _toggle,
            )
          : _QuickCard(
              key: const ValueKey('quick'),
              tip: widget.tip,
              palette: palette,
              onOpen: _toggle,
            ),
    );
  }

  void _toggle() {
    NylaHaptics.select();
    setState(() => detailed = !detailed);
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.tip, required this.palette, required this.onOpen, super.key});

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(38),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.start, palette.end],
              ),
              borderRadius: BorderRadius.circular(38),
              boxShadow: const [
                BoxShadow(color: Color(0x2A33203E), blurRadius: 34, offset: Offset(0, 16)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -48,
                  top: -34,
                  child: Container(
                    width: 156,
                    height: 156,
                    decoration: BoxDecoration(
                      color: palette.ink.withValues(alpha: 0.065),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(27, 27, 27, 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CategoryBadge(category: tip.category, palette: palette),
                          const Spacer(),
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: palette.ink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(_categoryIcon(tip.category), color: palette.ink, size: 23),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        tip.title,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: palette.ink,
                              fontSize: 34,
                              height: 1.04,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
                        decoration: BoxDecoration(
                          color: palette.panel,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE TAKEAWAY',
                              style: TextStyle(
                                color: palette.ink.withValues(alpha: 0.62),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.05,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              tip.flash,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: palette.ink,
                                    fontSize: 16.5,
                                    height: 1.42,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: palette.ink,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.menu_book_rounded, color: palette.start, size: 18),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Read the full card',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: palette.ink),
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, color: palette.ink, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DetailedCard extends StatelessWidget {
  const _DetailedCard({required this.tip, required this.palette, required this.onClose, super.key});

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: NylaColors.cream,
          borderRadius: BorderRadius.circular(38),
          border: Border.all(color: Colors.white, width: 1.4),
          boxShadow: const [
            BoxShadow(color: Color(0x2433203E), blurRadius: 34, offset: Offset(0, 16)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(23, 19, 17, 17),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [palette.start, palette.end]),
              ),
              child: Row(
                children: [
                  Expanded(child: _CategoryBadge(category: tip.category, palette: palette)),
                  IconButton(
                    tooltip: 'Back to takeaway',
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, color: palette.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 23, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28)),
                    const SizedBox(height: 14),
                    _LeadTakeaway(text: tip.flash),
                    const SizedBox(height: 22),
                    for (final paragraph in tip.details) ...[
                      Text(paragraph, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 15),
                    ],
                    if (tip.practical.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _GuidanceBlock(
                        icon: Icons.favorite_rounded,
                        eyebrow: 'PRACTICAL',
                        title: 'What can help',
                        tint: NylaColors.sageSoft,
                        iconColor: NylaColors.violet,
                        items: tip.practical,
                      ),
                    ],
                    if (tip.seekCare.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _GuidanceBlock(
                        icon: Icons.health_and_safety_rounded,
                        eyebrow: 'CARE NOTE',
                        title: 'When it is worth checking in',
                        tint: NylaColors.peachSoft,
                        iconColor: NylaColors.warning,
                        items: tip.seekCare,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SourceFooter(tip: tip),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _LeadTakeaway extends StatelessWidget {
  const _LeadTakeaway({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [NylaColors.lavenderSoft, NylaColors.roseWash],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.auto_awesome_rounded, color: NylaColors.violet, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NylaColors.wine,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _GuidanceBlock extends StatelessWidget {
  const _GuidanceBlock({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.tint,
    required this.iconColor,
    required this.items,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final Color tint;
  final Color iconColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(25)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                      decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink))),
                ],
              ),
              const SizedBox(height: 9),
            ],
          ],
        ),
      );
}

class _SourceFooter extends StatelessWidget {
  const _SourceFooter({required this.tip});

  final HealthTip tip;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            NylaHaptics.select();
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => _SourcesSheet(tip: tip),
            );
          },
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: NylaColors.lavenderMist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: NylaColors.violet, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviewed ${_reviewDate(tip.lastReviewed)}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tip.sources.length} trusted source${tip.sources.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: NylaColors.mutedInk),
              ],
            ),
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
        initialChildSize: 0.58,
        minChildSize: 0.42,
        maxChildSize: 0.88,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
          children: [
            Text('Reviewed sources', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 27)),
            const SizedBox(height: 7),
            Text(
              'These support the card. You never need to open them to read the guidance.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final source in tip.sources) ...[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => launchUrl(Uri.parse(source.url), mode: LaunchMode.externalApplication),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 39,
                          height: 39,
                          decoration: BoxDecoration(color: NylaColors.lavenderSoft, borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.open_in_new_rounded, color: NylaColors.violet, size: 18),
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
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Text(
              'Content v${tip.version}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
            ),
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
          color: palette.panel,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _categoryName(category).toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.ink,
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
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < total.clamp(1, 9); i++) ...[
            Expanded(
              flex: i == (index % total.clamp(1, 9)) ? 2 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 5,
                decoration: BoxDecoration(
                  color: i == (index % total.clamp(1, 9)) ? NylaColors.violet : NylaColors.lavender.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            if (i != total.clamp(1, 9) - 1) const SizedBox(width: 5),
          ],
        ],
      );
}

class _EditorialNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bookmark_rounded, size: 20, color: NylaColors.violet),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'Nyla keeps the medical reading inside each card. Sources are there for trust and verification, not as homework.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink),
              ),
            ),
          ],
        ),
      );
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [NylaColors.lavenderSoft, NylaColors.roseWash]),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 35, color: NylaColors.violet),
            const SizedBox(height: 13),
            Text('No card found', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text('Try another word or category.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class _CardPalette {
  const _CardPalette({required this.start, required this.end, required this.ink, required this.panel});

  final Color start;
  final Color end;
  final Color ink;
  final Color panel;
}

_CardPalette _paletteFor(TipCategory category, int index) => switch (category) {
      TipCategory.cycle => const _CardPalette(
          start: NylaColors.night,
          end: NylaColors.violet,
          ink: Colors.white,
          panel: Color(0x28FFFFFF),
        ),
      TipCategory.understanding => const _CardPalette(
          start: Color(0xFFCBDBCA),
          end: Color(0xFFE8D9B1),
          ink: NylaColors.ink,
          panel: Color(0xAFFFFFFF),
        ),
      TipCategory.body => const _CardPalette(
          start: NylaColors.lavender,
          end: Color(0xFFE7C3D5),
          ink: NylaColors.ink,
          panel: Color(0xAFFFFFFF),
        ),
      TipCategory.care => _CardPalette(
          start: index.isEven ? NylaColors.peach : NylaColors.sage,
          end: index.isEven ? NylaColors.roseSoft : NylaColors.lavender,
          ink: NylaColors.ink,
          panel: const Color(0xAFFFFFFF),
        ),
      TipCategory.products => const _CardPalette(
          start: Color(0xFFE6B6CE),
          end: Color(0xFFF4D7C5),
          ink: NylaColors.ink,
          panel: Color(0xAFFFFFFF),
        ),
      TipCategory.comfort => const _CardPalette(
          start: NylaColors.peach,
          end: NylaColors.butter,
          ink: NylaColors.ink,
          panel: Color(0xAFFFFFFF),
        ),
      TipCategory.symptoms => const _CardPalette(
          start: Color(0xFFBDA9DE),
          end: Color(0xFFE6B9C9),
          ink: NylaColors.ink,
          panel: Color(0xAFFFFFFF),
        ),
      TipCategory.seekCare => const _CardPalette(
          start: Color(0xFFF0B19F),
          end: Color(0xFFEEC89F),
          ink: NylaColors.ink,
          panel: Color(0xAFFFFFFF),
        ),
    };

IconData _categoryIcon(TipCategory category) => switch (category) {
      TipCategory.cycle => Icons.loop_rounded,
      TipCategory.understanding => Icons.lightbulb_rounded,
      TipCategory.body => Icons.spa_rounded,
      TipCategory.care => Icons.favorite_rounded,
      TipCategory.products => Icons.inventory_2_rounded,
      TipCategory.comfort => Icons.self_improvement_rounded,
      TipCategory.symptoms => Icons.monitor_heart_rounded,
      TipCategory.seekCare => Icons.health_and_safety_rounded,
    };

String _categoryName(TipCategory category) => switch (category) {
      TipCategory.cycle => 'Cycle',
      TipCategory.understanding => 'Understanding',
      TipCategory.body => 'Body',
      TipCategory.care => 'Care',
      TipCategory.products => 'Products',
      TipCategory.comfort => 'Comfort',
      TipCategory.symptoms => 'Symptoms',
      TipCategory.seekCare => 'Care guidance',
    };

String _reviewDate(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
