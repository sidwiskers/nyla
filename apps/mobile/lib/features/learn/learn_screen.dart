import 'package:flutter/material.dart';
import 'package:health_content/health_content.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/nyla_theme.dart';
import '../../widgets/nyla_page.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  TipCategory? selected;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final cards = healthTips
        .where((tip) => selected == null || tip.category == selected)
        .where((tip) => tip.matches(query))
        .toList(growable: false);

    return NylaPage(
      title: 'Learn',
      subtitle: 'Useful menstrual-health guidance, sourced and never paywalled.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (value) => setState(() => query = value),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search cramps, tampons, cleaning…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) => setState(() => selected = null),
                ),
                const SizedBox(width: 7),
                for (final category in TipCategory.values) ...[
                  ChoiceChip(
                    label: Text(_categoryName(category)),
                    selected: selected == category,
                    onSelected: (_) => setState(() => selected = category),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 15),
          if (cards.isEmpty)
            const _EmptySearch()
          else
            for (var index = 0; index < cards.length; index++) ...[
              _LearnCard(tip: cards[index], index: index),
              if (index != cards.length - 1) const SizedBox(height: 11),
            ],
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_outlined, size: 20, color: NylaColors.rose),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Every published card carries its medical sources, version and review date. These cards educate; they do not diagnose.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard({required this.tip, required this.index});

  final HealthTip tip;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tint = _categoryTint(tip.category, index);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => _TipSheet(tip: tip, tint: tint),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18)),
                    child: Text(
                      _categoryName(tip.category),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 20),
              Text(tip.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(tip.flash, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipSheet extends StatelessWidget {
  const _TipSheet({required this.tip, required this.tint});

  final HealthTip tip;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 2, 24, 34),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18)),
              child: Text(
                _categoryName(tip.category),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(tip.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            tip.flash,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          for (final paragraph in tip.details) ...[
            Text(paragraph, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
          ],
          if (tip.practical.isNotEmpty) ...[
            const SizedBox(height: 4),
            _Section(
              icon: Icons.favorite_outline_rounded,
              title: 'What can help',
              tint: NylaColors.sage,
              items: tip.practical,
            ),
          ],
          if (tip.seekCare.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              icon: Icons.medical_information_outlined,
              title: 'When to seek care',
              tint: NylaColors.peach,
              items: tip.seekCare,
            ),
          ],
          const SizedBox(height: 22),
          Text('Sources', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final source in tip.sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new_rounded, size: 19),
              title: Text(source.organization),
              subtitle: Text(source.title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => launchUrl(Uri.parse(source.url), mode: LaunchMode.externalApplication),
            ),
          const SizedBox(height: 8),
          Text(
            'Content v${tip.version} · reviewed ${_reviewDate(tip.lastReviewed)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.tint, required this.items});

  final IconData icon;
  final String title;
  final Color tint;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tint.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: SizedBox(
                      width: 5,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: NylaColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(item)),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 42),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 34, color: NylaColors.mutedInk),
            const SizedBox(height: 12),
            Text('No card matches that yet.', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Try a broader word.', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

String _categoryName(TipCategory category) => switch (category) {
      TipCategory.cycle => 'Cycle',
      TipCategory.understanding => 'Understanding',
      TipCategory.body => 'Body',
      TipCategory.care => 'Care',
      TipCategory.products => 'Products',
      TipCategory.comfort => 'Comfort',
      TipCategory.symptoms => 'Symptoms',
      TipCategory.seekCare => 'When to seek care',
    };

Color _categoryTint(TipCategory category, int index) => switch (category) {
      TipCategory.cycle => NylaColors.lavender,
      TipCategory.understanding => NylaColors.sage,
      TipCategory.body => NylaColors.sage,
      TipCategory.care => index.isEven ? NylaColors.sage : NylaColors.peach,
      TipCategory.products => NylaColors.roseSoft,
      TipCategory.comfort => NylaColors.peach,
      TipCategory.symptoms => NylaColors.lavender,
      TipCategory.seekCare => NylaColors.peach,
    };

String _reviewDate(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}