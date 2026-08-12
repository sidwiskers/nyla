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
  _TipFilter filter = _TipFilter.all;

  @override
  Widget build(BuildContext context) {
    final cards = healthTips.where(_matches).toList(growable: false);
    return NylaPage(
      title: 'Tips',
      trailing: NylaPressable(
        onTap: () {
          Navigator.maybePop(context);
        },
        semanticsLabel: 'Close tips',
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: NylaColors.paper,
            shape: BoxShape.circle,
            border: Border.all(color: NylaColors.outline),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.close_rounded, color: NylaColors.mutedInk, size: 19),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NylaPillTabs(
            labels: const ['All', 'Period', 'Wellness', 'Body'],
            selectedIndex: _TipFilter.values.indexOf(filter),
            onSelected: (index) {
              NylaHaptics.select();
              setState(() => filter = _TipFilter.values[index]);
            },
          ),
          const SizedBox(height: 15),
          for (var i = 0; i < cards.length; i++) ...[
            _TipCard(
              tip: cards[i],
              index: i,
              onTap: () => _openTip(cards[i]),
            ),
            if (i != cards.length - 1) const SizedBox(height: 11),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _matches(HealthTip tip) => switch (filter) {
        _TipFilter.all => tip.category != TipCategory.seekCare,
        _TipFilter.period => tip.category == TipCategory.cycle || tip.category == TipCategory.products,
        _TipFilter.wellness => tip.category == TipCategory.care || tip.category == TipCategory.comfort,
        _TipFilter.body => tip.category == TipCategory.body || tip.category == TipCategory.symptoms || tip.category == TipCategory.understanding,
      };

  void _openTip(HealthTip tip) {
    NylaHaptics.select();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TipSheet(tip: tip),
    );
  }
}

enum _TipFilter { all, period, wellness, body }

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip, required this.index, required this.onTap});

  final HealthTip tip;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(tip.category, index);
    return NylaPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: palette.accent.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryName(tip.category),
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tip.flash,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NylaColors.ink,
                          fontSize: 11.3,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(_categoryIcon(tip.category), color: palette.accent, size: 38),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipSheet extends StatelessWidget {
  const _TipSheet({required this.tip});

  final HealthTip tip;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
          children: [
            NylaOverline(_categoryName(tip.category)),
            const SizedBox(height: 7),
            Text(tip.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NylaColors.lavenderSoft,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                tip.flash,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 18),
            for (final paragraph in tip.details) ...[
              Text(paragraph, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 13),
            ],
            if (tip.practical.isNotEmpty) ...[
              const SizedBox(height: 4),
              _BulletSection(
                title: 'What may help',
                icon: Icons.favorite_outline_rounded,
                items: tip.practical,
                surface: NylaColors.sageSoft,
                accent: const Color(0xFF64805B),
              ),
            ],
            if (tip.seekCare.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BulletSection(
                title: 'When to seek care',
                icon: Icons.health_and_safety_outlined,
                items: tip.seekCare,
                surface: NylaColors.peachSoft,
                accent: NylaColors.warning,
              ),
            ],
            if (tip.sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Sources', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final source in tip.sources) ...[
                NylaPressable(
                  onTap: () => launchUrl(Uri.parse(source.url), mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                    decoration: BoxDecoration(
                      color: NylaColors.paper,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: NylaColors.outline),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new_rounded, color: NylaColors.violet, size: 17),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${source.organization} · ${source.title}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: NylaColors.ink,
                                  fontSize: 11.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ],
        ),
      );
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.surface,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final Color surface;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 19),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink))),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
}

class _Palette {
  const _Palette(this.surface, this.accent);

  final Color surface;
  final Color accent;
}

_Palette _palette(TipCategory category, int index) => switch (category) {
      TipCategory.cycle => const _Palette(NylaColors.roseWash, NylaColors.rose),
      TipCategory.understanding => const _Palette(NylaColors.lavenderSoft, NylaColors.violet),
      TipCategory.body => const _Palette(Color(0xFFF5EEE6), Color(0xFF8C664B)),
      TipCategory.care => const _Palette(NylaColors.sageSoft, Color(0xFF64805B)),
      TipCategory.products => const _Palette(NylaColors.peachSoft, Color(0xFF9A694B)),
      TipCategory.comfort => const _Palette(Color(0xFFF7F0D9), Color(0xFF927436)),
      TipCategory.symptoms => const _Palette(NylaColors.lavenderMist, NylaColors.iris),
      TipCategory.seekCare => const _Palette(Color(0xFFF8E8E5), NylaColors.warning),
    };

String _categoryName(TipCategory category) => switch (category) {
      TipCategory.cycle => 'Period',
      TipCategory.understanding => 'Understanding',
      TipCategory.body => 'Body',
      TipCategory.care => 'Wellness',
      TipCategory.products => 'Period care',
      TipCategory.comfort => 'Wellness',
      TipCategory.symptoms => 'Symptoms',
      TipCategory.seekCare => 'Care note',
    };

IconData _categoryIcon(TipCategory category) => switch (category) {
      TipCategory.cycle => Icons.water_drop_outlined,
      TipCategory.understanding => Icons.lightbulb_outline_rounded,
      TipCategory.body => Icons.spa_outlined,
      TipCategory.care => Icons.local_drink_outlined,
      TipCategory.products => Icons.inventory_2_outlined,
      TipCategory.comfort => Icons.self_improvement_rounded,
      TipCategory.symptoms => Icons.monitor_heart_outlined,
      TipCategory.seekCare => Icons.health_and_safety_outlined,
    };
