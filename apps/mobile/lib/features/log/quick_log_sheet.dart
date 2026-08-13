import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/model/log_catalog.dart';
import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';

Future<void> showQuickLogEditor({
  required BuildContext context,
  required WidgetRef ref,
  required LocalDay day,
  required LogDefinition definition,
  required List<DayValueEntry> values,
}) async {
  await NylaHaptics.select();
  final byKey = {for (final value in values) value.key: value};

  if (definition.kind == LogKind.choice) {
    final selected = byKey[definition.key]?.value;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _ChoiceSheet(
        definition: definition,
        selected: selected,
      ),
    );
    if (chosen == null) return;
    await NylaHaptics.confirm();
    await ref.read(dayLogRepositoryProvider).setValue(
          epochDay: day.epochDay,
          key: definition.key,
          value: chosen,
        );
    return;
  }

  if (definition.kind == LogKind.multiChoice) {
    final before = <String>{
      for (final choice in definition.choices)
        if (byKey.containsKey('${definition.key}.${choice.id}')) choice.id,
    };
    final chosen = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MultiChoiceSheet(
        definition: definition,
        initial: before,
      ),
    );
    if (chosen == null) return;
    await NylaHaptics.confirm();
    final repository = ref.read(dayLogRepositoryProvider);
    for (final choice in definition.choices) {
      final key = '${definition.key}.${choice.id}';
      if (chosen.contains(choice.id) && !before.contains(choice.id)) {
        await repository.setValue(
          epochDay: day.epochDay,
          key: key,
          value: choice.id,
        );
      } else if (!chosen.contains(choice.id) && before.contains(choice.id)) {
        await repository.clearValue(epochDay: day.epochDay, key: key);
      }
    }
    return;
  }

  final current = byKey[definition.key];
  final chosen = await showModalBottomSheet<int>(
    context: context,
    builder: (context) => _SeveritySheet(
      definition: definition,
      selected: current?.severity,
    ),
  );
  if (chosen == null) return;
  await NylaHaptics.confirm();
  await ref.read(dayLogRepositoryProvider).setValue(
        epochDay: day.epochDay,
        key: definition.key,
        value: severityChoices[chosen].id,
        severity: chosen,
      );
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.definition, required this.selected});

  final LogDefinition definition;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeading(
              icon: definition.icon,
              title: definition.label,
              subtitle: 'Choose what fits today.',
            ),
            const SizedBox(height: 15),
            for (final choice in definition.choices) ...[
              Material(
                color: choice.id == selected ? palette.lavenderSoft : palette.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(choice.id),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            choice.label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        if (choice.id == selected)
                          Icon(Icons.check_rounded, color: palette.violet, size: 19),
                      ],
                    ),
                  ),
                ),
              ),
              if (choice != definition.choices.last) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeveritySheet extends StatelessWidget {
  const _SeveritySheet({required this.definition, required this.selected});

  final LogDefinition definition;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeading(
              icon: definition.icon,
              title: definition.label,
              subtitle: 'Only as much detail as feels useful.',
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                for (var index = 0; index < severityChoices.length; index++) ...[
                  if (index > 0) const SizedBox(width: 7),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(index),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 82,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected == index ? palette.lavenderSoft : palette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected == index
                                ? palette.violet.withValues(alpha: 0.34)
                                : palette.outline,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24 + index * 2.2,
                              height: 24 + index * 2.2,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? palette.outlineStrong
                                    : palette.rose.withValues(alpha: 0.28 + index * 0.09),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              severityChoices[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: selected == index ? palette.wine : palette.mutedInk,
                                    fontSize: 9.5,
                                    fontWeight: selected == index
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiChoiceSheet extends StatefulWidget {
  const _MultiChoiceSheet({required this.definition, required this.initial});

  final LogDefinition definition;
  final Set<String> initial;

  @override
  State<_MultiChoiceSheet> createState() => _MultiChoiceSheetState();
}

class _MultiChoiceSheetState extends State<_MultiChoiceSheet> {
  late final Set<String> selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeading(
              icon: widget.definition.icon,
              title: widget.definition.label,
              subtitle: 'Choose one, a few, or none.',
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in widget.definition.choices)
                  FilterChip(
                    selected: selected.contains(choice.id),
                    label: Text(choice.label),
                    onSelected: (value) {
                      NylaHaptics.select();
                      setState(() {
                        if (value) {
                          selected.add(choice.id);
                        } else {
                          selected.remove(choice.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({...selected}),
              child: Text(selected.isEmpty ? 'Save as none' : 'Save ${widget.definition.label.toLowerCase()}'),
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 5),
              TextButton(
                onPressed: () => setState(selected.clear),
                child: Text(
                  'Clear selection',
                  style: TextStyle(color: palette.mutedInk),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.lavenderSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: palette.violet, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
