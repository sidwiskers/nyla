import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_content/health_content.dart';

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
  int selectedQuickFind = 0;
  String query = '';
  int currentIndex = 0;

  static const quickFinds = <_QuickFind>[
    _QuickFind('Explore', []),
    _QuickFind('Cramps', ['cramp', 'pain']),
    _QuickFind('Flow', ['flow', 'bleeding', 'blood']),
    _QuickFind('Hygiene', ['hygiene', 'cleaning', 'wash']),
    _QuickFind('Products', ['pad', 'tampon', 'cup', 'product']),
    _QuickFind('Discharge', ['discharge']),
    _QuickFind('PMS', ['pms', 'mood', 'bloating']),
    _QuickFind('Heavy periods', ['heavy', 'iron']),
    _QuickFind('Get care', ['seek care', 'warning', 'doctor', 'clinician']),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickFind = quickFinds[selectedQuickFind];
    final cards = healthTips.where((tip) {
      if (!tip.matches(query)) return false;
      if (quickFind.terms.isEmpty) return true;
      return quickFind.terms.any(tip.matches);
    }).toList(growable: false);
    final index = cards.isEmpty ? 0 : currentIndex.clamp(0, cards.length - 1);
    final deckHeight = (MediaQuery.sizeOf(context).height * 0.62)
        .clamp(440.0, 620.0)
        .toDouble();
    final nyla = context.nyla;

    return NylaPage(
      title: 'Learn',
      subtitle: 'Period and cycle guidance.',
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
          _QuickFindStrip(
            items: quickFinds,
            selected: selectedQuickFind,
            onSelected: (value) {
              NylaHaptics.select();
              setState(() {
                selectedQuickFind = value;
                currentIndex = 0;
              });
              _resetDeck();
            },
          ),
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
                        color: nyla.lavenderSoft,
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(color: nyla.glassBorder),
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
                        color: nyla.roseWash,
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(color: nyla.glassBorder),
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
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  void _resetDeck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(0);
    });
  }
}

class _QuickFind {
  const _QuickFind(this.label, this.terms);

  final String label;
  final List<String> terms;
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
          decoration: InputDecoration(
            hintText: 'Search cramps, flow, products…',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: context.nyla.violet,
              size: 20,
            ),
          ),
        ),
      );
}

class _QuickFindStrip extends StatelessWidget {
  const _QuickFindStrip({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<_QuickFind> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              ChoiceChip(
                label: Text(items[i].label),
                selected: selected == i,
                onSelected: (_) => onSelected(i),
              ),
              if (i != items.length - 1) const SizedBox(width: 7),
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
                    color: context.nyla.wine,
                    fontSize: 13.5,
                  ),
            ),
            const Spacer(),
            Icon(
              Icons.swipe_rounded,
              size: 17,
              color: context.nyla.violet,
            ),
            const SizedBox(width: 5),
            Text(
              'Swipe',
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

class _KnowledgeCardState extends State<_KnowledgeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    NylaHaptics.select();
    if (_flip.status == AnimationStatus.completed || _flip.value >= 0.5) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(context, widget.tip.category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('learn-card-tap-${widget.tip.id}'),
        onTap: _toggle,
        borderRadius: BorderRadius.circular(30),
        splashColor: palette.ink.withValues(alpha: 0.035),
        highlightColor: palette.ink.withValues(alpha: 0.025),
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = _flip.value * math.pi;
            final back = angle >= math.pi / 2;
            final face = back
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _BackCard(tip: widget.tip, palette: palette),
                  )
                : _FrontCard(tip: widget.tip, palette: palette);
            return Semantics(
              label: back
                  ? 'Card details. Tap to flip back.'
                  : 'Tap for card details.',
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
                  ..rotateY(angle),
                child: face,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({required this.tip, required this.palette});

  final HealthTip tip;
  final _CardPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.start, palette.end],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: context.nyla.glassBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: context.nyla.shadow,
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 470;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 19 : 23,
                compact ? 18 : 22,
                compact ? 19 : 23,
                compact ? 17 : 21,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CardLabel(text: _cardLabel(tip.category), palette: palette),
                      const Spacer(),
                      Container(
                        width: compact ? 37 : 42,
                        height: compact ? 37 : 42,
                        decoration: BoxDecoration(
                          color: context.nyla.glass.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _categoryIcon(tip.category),
                          color: palette.ink,
                          size: compact ? 18 : 20,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 14 : 21),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, available) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: available.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip.title,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'sans-serif-rounded',
                                  fontFamilyFallback: const ['sans-serif', 'Roboto'],
                                  color: palette.ink,
                                  fontSize: compact ? 27 : 31,
                                  height: 1.06,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.35,
                                ),
                              ),
                              SizedBox(height: compact ? 14 : 19),
                              Text(
                                tip.flash,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: palette.ink,
                                      fontSize: compact ? 15 : 16,
                                      fontWeight: FontWeight.w500,
                                      height: 1.43,
                                    ),
                              ),
                              if (!compact && tip.details.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  tip.details.first,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: palette.ink.withValues(alpha: 0.76),
                                        height: 1.42,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: palette.ink.withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.flip_rounded, color: palette.ink, size: 16),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Tap to flip',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.w600,
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
      );
}

class _BackCard extends StatelessWidget {
  const _BackCard({required this.tip, required this.palette});

  final HealthTip tip;
  final _CardPalette palette;

  @override
  Widget build(BuildContext context) {
    final contentLength = tip.flash.length +
        tip.details.fold<int>(0, (sum, item) => sum + item.length) +
        tip.practical.fold<int>(0, (sum, item) => sum + item.length) +
        tip.seekCare.fold<int>(0, (sum, item) => sum + item.length);
    final bodySize = contentLength > 1050
        ? 12.7
        : contentLength > 760
            ? 13.3
            : contentLength > 520
                ? 14.0
                : 14.7;
    final spacing = contentLength > 900 ? 10.0 : 13.0;
    final nyla = context.nyla;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.end, nyla.cream],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: nyla.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: nyla.shadow,
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(21, 19, 21, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CardLabel(text: _cardLabel(tip.category), palette: palette),
                const Spacer(),
                Icon(Icons.flip_rounded, color: palette.ink, size: 18),
                const SizedBox(width: 5),
                Text(
                  'Flip back',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.ink.withValues(alpha: 0.72),
                        fontSize: 11.5,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              tip.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'sans-serif-rounded',
                fontFamilyFallback: const ['sans-serif', 'Roboto'],
                color: palette.ink,
                fontSize: 22,
                height: 1.08,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.flash,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: palette.ink,
                            fontSize: bodySize + 0.6,
                            fontWeight: FontWeight.w600,
                            height: 1.43,
                          ),
                    ),
                    SizedBox(height: spacing),
                    for (final paragraph in tip.details) ...[
                      Text(
                        paragraph,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: palette.ink,
                              fontSize: bodySize,
                              height: 1.5,
                            ),
                      ),
                      SizedBox(height: spacing),
                    ],
                    if (tip.practical.isNotEmpty) ...[
                      _InlineHeading(text: 'Try', color: palette.ink),
                      const SizedBox(height: 7),
                      for (final item in tip.practical)
                        _Bullet(
                          text: item,
                          color: palette.ink,
                          fontSize: bodySize,
                        ),
                      SizedBox(height: spacing),
                    ],
                    if (tip.seekCare.isNotEmpty) ...[
                      _InlineHeading(text: 'Get medical advice if', color: nyla.warning),
                      const SizedBox(height: 7),
                      for (final item in tip.seekCare)
                        _Bullet(
                          text: item,
                          color: nyla.warning,
                          fontSize: bodySize,
                        ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineHeading extends StatelessWidget {
  const _InlineHeading({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontSize: 13.5,
            ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.color, required this.fontSize});

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontSize: fontSize,
                      height: 1.48,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.text, required this.palette});

  final String text;
  final _CardPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.nyla.glass.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: palette.ink,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
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
    final selected = visible == 0 ? 0 : index % visible;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < visible; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: i == selected ? 24 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == selected ? context.nyla.violet : context.nyla.lavender,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (i != visible - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.nyla.lavenderMist,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.nyla.outline),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: context.nyla.violet, size: 28),
            const SizedBox(height: 9),
            Text('No cards found', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Try another search.', style: Theme.of(context).textTheme.bodyMedium),
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

_CardPalette _paletteFor(BuildContext context, TipCategory category) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final p = context.nyla;
  if (dark) {
    return switch (category) {
      TipCategory.cycle => _CardPalette(
          start: p.roseSoft,
          end: const Color(0xFF352635),
          ink: p.ink,
        ),
      TipCategory.understanding => _CardPalette(
          start: p.lavender,
          end: p.lavenderSoft,
          ink: p.ink,
        ),
      TipCategory.body => _CardPalette(
          start: const Color(0xFF3B3328),
          end: const Color(0xFF29231F),
          ink: p.ink,
        ),
      TipCategory.care => _CardPalette(
          start: p.sage,
          end: p.sageSoft,
          ink: p.ink,
        ),
      TipCategory.products => _CardPalette(
          start: p.peach,
          end: p.peachSoft,
          ink: p.ink,
        ),
      TipCategory.comfort => _CardPalette(
          start: p.butter,
          end: const Color(0xFF342F22),
          ink: p.ink,
        ),
      TipCategory.symptoms => _CardPalette(
          start: const Color(0xFF423653),
          end: p.lavenderSoft,
          ink: p.ink,
        ),
      TipCategory.seekCare => _CardPalette(
          start: const Color(0xFF49302E),
          end: p.roseWash,
          ink: p.ink,
        ),
    };
  }

  return switch (category) {
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
}

String _cardLabel(TipCategory category) => switch (category) {
      TipCategory.cycle => 'Cycle',
      TipCategory.understanding => 'Basics',
      TipCategory.body => 'Anatomy',
      TipCategory.care => 'Hygiene',
      TipCategory.products => 'Products',
      TipCategory.comfort => 'Relief',
      TipCategory.symptoms => 'Symptoms',
      TipCategory.seekCare => 'Get care',
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
