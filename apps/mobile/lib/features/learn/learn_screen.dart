import 'package:flutter/material.dart';

import '../../core/theme/nyla_theme.dart';
import '../../widgets/nyla_page.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  String selected = 'All';

  static const categories = ['All', 'Body', 'Care', 'Periods', 'Symptoms'];
  static const previewCards = <_PreviewCard>[
    _PreviewCard('Body', 'Your vagina cleans itself', 'Gentle external care is enough for routine washing.', NylaColors.sage),
    _PreviewCard('Care', 'Changing period products', 'Comfort, flow and the product you use all affect timing.', NylaColors.roseSoft),
    _PreviewCard('Symptoms', 'Why cramps can hurt', 'Period pain is common, but pain that disrupts daily life deserves attention.', NylaColors.peach),
    _PreviewCard('Periods', 'A cycle is not a stopwatch', 'Variation happens. Good tracking shows uncertainty instead of hiding it.', NylaColors.lavender),
  ];

  @override
  Widget build(BuildContext context) {
    final cards = selected == 'All' ? previewCards : previewCards.where((card) => card.category == selected).toList();
    return NylaPage(
      title: 'Learn',
      subtitle: 'Useful, sourced menstrual-health guidance. No paywall.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories) ...[
                  ChoiceChip(
                    label: Text(category),
                    selected: selected == category,
                    onSelected: (_) => setState(() => selected = category),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final card in cards) ...[
            _LearnCard(card: card),
            const SizedBox(height: 11),
          ],
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
                      'Each published card carries its medical sources, content version and review date. Nyla does not turn educational content into a diagnosis.',
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
  const _LearnCard({required this.card});

  final _PreviewCard card;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => _PreviewSheet(card: card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: card.tint, borderRadius: BorderRadius.circular(18)),
                  child: Text(card.category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 22),
                Text(card.title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(card.summary, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text('Read the card', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.card});

  final _PreviewCard card;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(card.summary),
              const SizedBox(height: 18),
              Text(
                'The complete, medically reviewed content library is loaded from Nyla’s versioned health-content corpus rather than being embedded as UI copy.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}

class _PreviewCard {
  const _PreviewCard(this.category, this.title, this.summary, this.tint);

  final String category;
  final String title;
  final String summary;
  final Color tint;
}
