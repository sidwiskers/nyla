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
  final PageController _deckController = PageController(viewportFraction: 0.93);
  TipCategory? selected;
  String query = '';
  int currentIndex = 0;

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = healthTips
        .where((tip) => selected == null || tip.category == selected)
        .where((tip) => tip.matches(query))
        .toList(growable: false);
    final safeIndex = cards.isEmpty ? 0 : currentIndex.clamp(0, cards.length - 1);
    final deckHeight = (MediaQuery.sizeOf(context).height * 0.53).clamp(390.0, 500.0);

    return NylaPage(
      title: 'Learn',
      subtitle: 'Small cards worth remembering. Swipe, reveal, move on.',
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
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) => _chooseCategory(null),
                ),
                const SizedBox(width: 7),
                for (final category in TipCategory.values) ...[
                  ChoiceChip(
                    label: Text(_categoryName(category)),
                    selected: selected == category,
                    onSelected: (_) => _chooseCategory(category),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (cards.isEmpty)
            const _EmptySearch()
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                children: [
                  Text(
                    '${safeIndex + 1} / ${cards.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.swipe_rounded, size: 17, color: NylaColors.mutedInk),
                      const SizedBox(width: 6),
                      Text('Swipe the deck', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: deckHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 18,
                    left: 26,
                    right: 26,
                    bottom: 0,
                    child: Transform.rotate(
                      angle: -0.018,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: NylaColors.lavenderSoft,
                          borderRadius: BorderRadius.circular(34),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 23,
                    right: 23,
                    bottom: 8,
                    child: Transform.rotate(
                      angle: 0.012,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: NylaColors.peachSoft,
                          borderRadius: BorderRadius.circular(34),
                        ),
                      ),
                    ),
                  ),
                  PageView.builder(
                    controller: _deckController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: cards.length,
                    onPageChanged: (value) {
                      NylaHaptics.select();
                      setState(() => currentIndex = value);
                    },
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.fromLTRB(5, 0, 5, 16),
                      child: _FlashCard(
                        key: ValueKey(cards[index].id),
                        tip: cards[index],
                        index: index,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DeckProgress(value: (safeIndex + 1) / cards.length),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NylaColors.sageSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_rounded, size: 20, color: NylaColors.wine),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Every card is reviewed and sourced. Sources stay inside the full guide so the deck itself stays calm and readable.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 82),
        ],
      ),
    );
  }

  void _chooseCategory(TipCategory? value) {
    NylaHaptics.select();
    setState(() {
      selected = value;
      currentIndex = 0;
    });
    _resetDeck();
  }

  void _resetDeck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_deckController.hasClients) _deckController.jumpToPage(0);
    });
  }
}

class _FlashCard extends StatefulWidget {
  const _FlashCard({required this.tip, required this.index, super.key});

  final HealthTip tip;
  final int index;

  @override
  State<_FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<_FlashCard> {
  bool revealed = false;

  @override
  Widget build(BuildContext context) {
    final palette = _categoryPalette(widget.tip.category, widget.index);
    return Material(
      color: Colors.transparent,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.965, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: revealed
            ? _CardBack(
                key: const ValueKey('back'),
                tip: widget.tip,
                palette: palette,
                onHide: _toggle,
                onOpen: () => _openGuide(context),
              )
            : _CardFront(
                key: const ValueKey('front'),
                tip: widget.tip,
                palette: palette,
                onReveal: _toggle,
              ),
      ),
    );
  }

  void _toggle() {
    NylaHaptics.select();
    setState(() => revealed = !revealed);
  }

  void _openGuide(BuildContext context) {
    NylaHaptics.confirm();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TipSheet(tip: widget.tip),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.tip, required this.palette, required this.onReveal, super.key});

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onReveal,
      borderRadius: BorderRadius.circular(34),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.start, palette.end],
          ),
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [
            BoxShadow(color: Color(0x18542B3C), blurRadius: 28, offset: Offset(0, 13)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 25, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryPill(category: tip.category, dark: palette.dark),
                  const Spacer(),
                  Icon(_categoryIcon(tip.category), color: palette.ink.withValues(alpha: 0.78), size: 25),
                ],
              ),
              const Spacer(),
              Text(
                tip.title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: palette.ink,
                      fontSize: 35,
                      height: 1.04,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.ink.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.touch_app_rounded, size: 18, color: palette.ink.withValues(alpha: 0.72)),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to reveal',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: palette.ink),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.tip,
    required this.palette,
    required this.onHide,
    required this.onOpen,
    super.key,
  });

  final HealthTip tip;
  final _CardPalette palette;
  final VoidCallback onHide;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final detail = tip.details.isEmpty ? null : tip.details.first;
    return Container(
      decoration: BoxDecoration(
        color: NylaColors.cream,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(color: Color(0x18542B3C), blurRadius: 28, offset: Offset(0, 13)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(26, 25, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryPill(category: tip.category),
              const Spacer(),
              IconButton(
                tooltip: 'Show front',
                onPressed: onHide,
                icon: const Icon(Icons.flip_rounded),
                color: NylaColors.wine,
              ),
            ],
          ),
          const Spacer(),
          Text(
            tip.flash,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 27,
                  height: 1.14,
                ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 17),
            Text(
              detail,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: NylaColors.mutedInk),
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Open full guide'),
          ),
        ],
      ),
    );
  }
}

class _TipSheet extends StatelessWidget {
  const _TipSheet({required this.tip});

  final HealthTip tip;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.84,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 34),
        children: [
          _CategoryPill(category: tip.category),
          const SizedBox(height: 16),
          Text(tip.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            tip.flash,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: NylaColors.wine,
                ),
          ),
          const SizedBox(height: 22),
          for (final paragraph in tip.details) ...[
            Text(paragraph, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 14),
          ],
          if (tip.practical.isNotEmpty) ...[
            const SizedBox(height: 4),
            _GuideSection(
              icon: Icons.favorite_rounded,
              title: 'What can help',
              tint: NylaColors.sageSoft,
              items: tip.practical,
            ),
          ],
          if (tip.seekCare.isNotEmpty) ...[
            const SizedBox(height: 14),
            _GuideSection(
              icon: Icons.health_and_safety_rounded,
              title: 'When to seek care',
              tint: NylaColors.peachSoft,
              items: tip.seekCare,
            ),
          ],
          const SizedBox(height: 18),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_rounded, color: NylaColors.rose),
              title: const Text('Sources & review', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Content v${tip.version} · reviewed ${_reviewDate(tip.lastReviewed)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              children: [
                for (final source in tip.sources)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListTile(
                      title: Text(source.organization, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(source.title),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: () => launchUrl(Uri.parse(source.url), mode: LaunchMode.externalApplication),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.icon, required this.title, required this.tint, required this.items});

  final IconData icon;
  final String title;
  final Color tint;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: NylaColors.wine),
                const SizedBox(width: 9),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 5, color: NylaColors.rose),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
              const SizedBox(height: 9),
            ],
          ],
        ),
      );
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, this.dark = false});

  final TipCategory category;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.18) : NylaColors.roseWash,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _categoryName(category).toUpperCase(),
          style: TextStyle(
            color: dark ? Colors.white : NylaColors.rose,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _DeckProgress extends StatelessWidget {
  const _DeckProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 5,
          color: NylaColors.rose,
          backgroundColor: NylaColors.roseSoft.withValues(alpha: 0.5),
        ),
      );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 24),
        decoration: BoxDecoration(
          color: NylaColors.lavenderSoft,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 34, color: NylaColors.wine),
            const SizedBox(height: 13),
            Text('Nothing in this deck yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text('Try another word or category.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class _CardPalette {
  const _CardPalette({required this.start, required this.end, required this.ink, this.dark = false});

  final Color start;
  final Color end;
  final Color ink;
  final bool dark;
}

_CardPalette _categoryPalette(TipCategory category, int index) => switch (category) {
      TipCategory.cycle => const _CardPalette(
          start: NylaColors.wine,
          end: NylaColors.rose,
          ink: Colors.white,
          dark: true,
        ),
      TipCategory.understanding => const _CardPalette(
          start: NylaColors.sage,
          end: Color(0xFFE8E0B6),
          ink: NylaColors.ink,
        ),
      TipCategory.body => const _CardPalette(
          start: NylaColors.lavender,
          end: NylaColors.peach,
          ink: NylaColors.ink,
        ),
      TipCategory.care => _CardPalette(
          start: index.isEven ? NylaColors.peach : NylaColors.sage,
          end: index.isEven ? NylaColors.roseSoft : NylaColors.peachSoft,
          ink: NylaColors.ink,
        ),
      TipCategory.products => const _CardPalette(
          start: NylaColors.roseSoft,
          end: NylaColors.peachSoft,
          ink: NylaColors.ink,
        ),
      TipCategory.comfort => const _CardPalette(
          start: NylaColors.peach,
          end: NylaColors.butter,
          ink: NylaColors.ink,
        ),
      TipCategory.symptoms => const _CardPalette(
          start: NylaColors.lavender,
          end: NylaColors.roseSoft,
          ink: NylaColors.ink,
        ),
      TipCategory.seekCare => const _CardPalette(
          start: Color(0xFFFFC1B4),
          end: NylaColors.peach,
          ink: NylaColors.ink,
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
      TipCategory.seekCare => 'Seek care',
    };

String _reviewDate(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
