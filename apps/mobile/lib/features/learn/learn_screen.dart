import 'dart:math' as math;

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
  final PageController _controller = PageController(viewportFraction: 0.94);
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
        (MediaQuery.sizeOf(context).height * 0.61).clamp(440.0, 610.0).toDouble();

    return NylaPage(
      title: 'Learn',
      subtitle: 'Small cards for questions that deserve clear answers.',
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
          const SizedBox(height: 11),
          _CategoryStrip(selected: selected, onSelected: _chooseCategory),
          const SizedBox(height: 18),
          if (cards.isEmpty)
            const _EmptyDeck()
          else ...[
            _DeckHeader(index: index, total: cards.length),
            const SizedBox(height: 10),
            SizedBox(
              height: deckHeight,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 13,
                    bottom: 11,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: NylaColors.lavenderSoft,
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 17,
                    right: 17,
                    top: 7,
                    bottom: 17,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: NylaColors.roseWash,
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(color: Colors.white),
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
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 22),
                      child: _KnowledgeCard(
                        key: ValueKey(cards[cardIndex].id),
                        tip: cards[cardIndex],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _DeckProgress(index: index, total: cards.length),
          ],
          const SizedBox(height: 24),
          const _EditorialNote(),
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
  Widget build(BuildContext context) => SizedBox(
        height: 49,
        child: TextField(
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search cramps, flow, products…',
            prefixIcon: Icon(Icons.search_rounded, color: NylaColors.violet, size: 20),
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
              '${index + 1} of $total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: NylaColors.wine,
                    fontSize: 13.5,
                  ),
            ),
            const Spacer(),
            const Icon(Icons.swipe_rounded, size: 17, color: NylaColors.violet),
            const SizedBox(width: 5),
            Text(
              'Swipe for another',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
            ),
          ],
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
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
  const _QuickCard({
    required this.tip,
    required this.palette,
    required this.onOpen,
    super.key,
  });

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.start, palette.end],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x162B2231),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 450;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 20 : 24,
                    compact ? 19 : 23,
                    compact ? 20 : 24,
                    compact ? 18 : 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CategoryBadge(category: tip.category, palette: palette),
                          const Spacer(),
                          Container(
                            width: compact ? 39 : 44,
                            height: compact ? 39 : 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _categoryIcon(tip.category),
                              color: palette.ink,
                              size: compact ? 19 : 21,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 16 : 23),
                      Text(
                        tip.title,
                        maxLines: compact ? 3 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: palette.ink,
                              fontSize: compact ? 27 : 31,
                              height: 1.05,
                            ),
                      ),
                      SizedBox(height: compact ? 14 : 19),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                          compact ? 14 : 16,
                          compact ? 13 : 15,
                          compact ? 14 : 16,
                          compact ? 14 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.64),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE TAKEAWAY',
                              style: TextStyle(
                                color: palette.ink.withValues(alpha: 0.64),
                                fontSize: 9.2,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tip.flash,
                              maxLines: compact ? 4 : 5,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: palette.ink,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact && tip.details.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        Text(
                          tip.details.first,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: palette.ink.withValues(alpha: 0.74),
                              ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: palette.ink.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: palette.ink,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Read the full card',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: palette.ink,
                                  ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, color: palette.ink, size: 18),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
}

class _DetailedCard extends StatelessWidget {
  const _DetailedCard({
    required this.tip,
    required this.palette,
    required this.onClose,
    super.key,
  });

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: NylaColors.cream,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x162B2231),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
              color: palette.start,
              child: Row(
                children: [
                  _CategoryBadge(category: tip.category, palette: palette),
                  const Spacer(),
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
                padding: const EdgeInsets.fromLTRB(21, 18, 21, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25),
                    ),
                    const SizedBox(height: 13),
                    _LeadTakeaway(text: tip.flash, palette: palette),
                    const SizedBox(height: 20),
                    for (final paragraph in tip.details) ...[
                      Text(paragraph, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 14),
                    ],
                    if (tip.practical.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _GuidanceBlock(
                        icon: Icons.favorite_rounded,
                        title: 'What can help',
                        tint: NylaColors.sageSoft,
                        iconColor: const Color(0xFF688E7A),
                        items: tip.practical,
                      ),
                    ],
                    if (tip.seekCare.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      _GuidanceBlock(
                        icon: Icons.health_and_safety_rounded,
                        title: 'When to check in',
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
  const _LeadTakeaway({required this.text, required this.palette});

  final String text;
  final _CardPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        decoration: BoxDecoration(
          color: palette.start.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'In one sentence',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.ink.withValues(alpha: 0.68),
                    fontSize: 11.5,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
}

class _GuidanceBlock extends StatelessWidget {
  const _GuidanceBlock({
    required this.icon,
    required this.title,
    required this.tint,
    required this.iconColor,
    required this.items,
  });

  final IconData icon;
  final String title;
  final Color tint;
  final Color iconColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: NylaColors.ink,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
}

class _SourceFooter extends StatelessWidget {
  const _SourceFooter({required this.tip});

  final HealthTip tip;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () {
          NylaHaptics.select();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => _SourcesSheet(tip: tip),
          );
        },
        icon: const Icon(Icons.verified_outlined, size: 17),
        label: Text('Reviewed sources · ${_reviewDate(tip.lastReviewed)}'),
      );
}

class _SourcesSheet extends StatelessWidget {
  const _SourcesSheet({required this.tip});

  final HealthTip tip;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            Text('Reviewed sources', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'These references support the card. You do not need to leave Nyla to read the guidance.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            for (final source in tip.sources) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => launchUrl(
                    Uri.parse(source.url),
                    mode: LaunchMode.externalApplication,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: NylaColors.lavenderMist,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NylaColors.outline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.open_in_new_rounded,
                            color: NylaColors.violet,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 11),
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
              ),
              const SizedBox(height: 9),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _categoryName(category),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.ink,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
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
    final visible = math.min(total, 7);
    final selected = index.clamp(0, visible - 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < visible; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: i == selected ? 24 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == selected ? NylaColors.violet : NylaColors.lavender,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (i != visible - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _EditorialNote extends StatelessWidget {
  const _EditorialNote();

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: NylaColors.violet, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Every card is written for Nyla and reviewed against trusted medical sources. Sources stay available without taking over the experience.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: NylaColors.lavenderMist,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NylaColors.outline),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, color: NylaColors.violet, size: 28),
            const SizedBox(height: 9),
            Text('Nothing matched that search', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Try a shorter phrase or switch back to All.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class _CardPalette {
  const _CardPalette({required this.start, required this.end, required this.ink});

  final Color start;
  final Color end;
  final Color ink;
}

_CardPalette _paletteFor(TipCategory category) => switch (category) {
      TipCategory.cycle => const _CardPalette(
          start: Color(0xFFF8DCE5),
          end: Color(0xFFF7EAF3),
          ink: Color(0xFF6E4357),
        ),
      TipCategory.understanding => const _CardPalette(
          start: Color(0xFFECE4F7),
          end: Color(0xFFF6F1FA),
          ink: Color(0xFF58456D),
        ),
      TipCategory.body => const _CardPalette(
          start: Color(0xFFF5ECDC),
          end: Color(0xFFFBF6ED),
          ink: Color(0xFF665745),
        ),
      TipCategory.care => const _CardPalette(
          start: Color(0xFFE1F0E8),
          end: Color(0xFFF0F6F2),
          ink: Color(0xFF49695B),
        ),
      TipCategory.products => const _CardPalette(
          start: Color(0xFFF9E4D9),
          end: Color(0xFFFCF1EA),
          ink: Color(0xFF765343),
        ),
      TipCategory.comfort => const _CardPalette(
          start: Color(0xFFF8EED2),
          end: Color(0xFFFCF7EA),
          ink: Color(0xFF725E3B),
        ),
      TipCategory.symptoms => const _CardPalette(
          start: Color(0xFFE8E4F5),
          end: Color(0xFFF4F1FA),
          ink: Color(0xFF5F5274),
        ),
      TipCategory.seekCare => const _CardPalette(
          start: Color(0xFFF6E2DF),
          end: Color(0xFFFBF0ED),
          ink: Color(0xFF79554C),
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
