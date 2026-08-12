import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/date_text.dart';
import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';

class PeriodHistoryScreen extends ConsumerWidget {
  const PeriodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(periodHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Period history'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Add period',
            onPressed: () => _editPeriod(context, ref, null),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        error: (_, _) => const Center(child: Text('Your period history could not be loaded.')),
        data: (periods) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: NylaColors.roseSoft, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.edit_calendar_rounded, color: NylaColors.rose),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Correct dates whenever you need to. Excluding an unusual cycle keeps it visible in your history while stopping it from influencing predictions.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (periods.isEmpty)
              _EmptyHistory(onAdd: () => _editPeriod(context, ref, null))
            else
              for (var index = 0; index < periods.length; index++) ...[
                _PeriodCard(
                  period: periods[index],
                  onTap: () => _editPeriod(context, ref, periods[index]),
                ),
                if (index != periods.length - 1) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
      floatingActionButton: history.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => _editPeriod(context, ref, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add period'),
            )
          : null,
    );
  }

  Future<void> _editPeriod(BuildContext context, WidgetRef ref, PeriodEntry? existing) async {
    final initial = existing == null
        ? null
        : _PeriodDraft(
            start: LocalDay(existing.startDay),
            end: existing.endDay == null ? null : LocalDay(existing.endDay!),
            excluded: existing.excludeFromPrediction,
          );
    final result = await showModalBottomSheet<_PeriodEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _PeriodEditor(initial: initial, allowDelete: existing != null),
    );
    if (result == null || !context.mounted) return;

    final repository = ref.read(cycleRepositoryProvider);
    try {
      if (result.delete) {
        await repository.deletePeriod(existing!.id);
        return;
      }
      final draft = result.draft!;
      if (existing == null) {
        final id = await repository.recordPeriod(start: draft.start, end: draft.end);
        if (draft.excluded) await repository.setPredictionExcluded(id, true);
      } else {
        await repository.updatePeriod(id: existing.id, start: draft.start, end: draft.end);
        await repository.setPredictionExcluded(existing.id, draft.excluded);
      }
    } on ArgumentError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message?.toString() ?? 'Those dates are not valid.')));
      }
    } on StateError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That period changed on another screen. Try again.')));
      }
    }
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.period, required this.onTap});

  final PeriodEntry period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = LocalDay(period.startDay);
    final end = period.endDay == null ? null : LocalDay(period.endDay!);
    final duration = end == null ? null : start.daysUntil(end) + 1;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: NylaColors.roseSoft, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.water_drop_rounded, color: NylaColors.rose, size: 20),
        ),
        title: Text(end == null ? friendlyDay(start) : '${friendlyDay(start)} – ${friendlyDay(end)}'),
        subtitle: Text(
          [
            if (duration != null) '$duration day${duration == 1 ? '' : 's'}',
            period.excludeFromPrediction ? 'excluded from predictions' : 'used for predictions',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 46),
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 36, color: NylaColors.mutedInk),
            const SizedBox(height: 12),
            Text('No periods recorded yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Add a past or current period when you are ready.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add period')),
          ],
        ),
      );
}

class _PeriodEditor extends StatefulWidget {
  const _PeriodEditor({required this.initial, required this.allowDelete});

  final _PeriodDraft? initial;
  final bool allowDelete;

  @override
  State<_PeriodEditor> createState() => _PeriodEditorState();
}

class _PeriodEditorState extends State<_PeriodEditor> {
  late LocalDay start = widget.initial?.start ?? LocalDay.fromDateTime(DateTime.now());
  late LocalDay? end = widget.initial?.end;
  late bool excluded = widget.initial?.excluded ?? false;

  Future<LocalDay?> _pick(LocalDay initial, {LocalDay? first, LocalDay? last}) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.utcDate,
      firstDate: first?.utcDate ?? DateTime(1900),
      lastDate: last?.utcDate ?? DateTime(today.year, today.month, today.day),
    );
    return picked == null ? null : LocalDay.fromDateTime(picked);
  }

  Future<void> _pickStart() async {
    final picked = await _pick(start);
    if (picked == null) return;
    setState(() {
      start = picked;
      if (end != null && end!.epochDay < start.epochDay) end = null;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pick(end ?? start, first: start);
    if (picked != null) setState(() => end = picked);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete this period?'),
            content: const Text('This removes the period record from this device and your encrypted sync history. Daily symptom logs are left untouched.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) Navigator.pop(context, const _PeriodEditResult.delete());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.allowDelete ? 'Edit period' : 'Add period', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          _DateTile(label: 'Started', value: friendlyDay(start), onTap: _pickStart),
          const SizedBox(height: 9),
          _DateTile(label: 'Ended', value: end == null ? 'Not recorded' : friendlyDay(end!), onTap: _pickEnd),
          if (end != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => setState(() => end = null), child: const Text('Clear end date')),
            ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exclude from predictions'),
            subtitle: const Text('Keep the record visible, but do not let this cycle influence future estimates.'),
            value: excluded,
            onChanged: (value) => setState(() => excluded = value),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _PeriodEditResult.save(_PeriodDraft(start: start, end: end, excluded: excluded)),
            ),
            child: const Text('Save'),
          ),
          if (widget.allowDelete) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete period'),
              style: TextButton.styleFrom(foregroundColor: NylaColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(label),
          subtitle: Text(value),
          trailing: const Icon(Icons.calendar_month_rounded),
          onTap: onTap,
        ),
      );
}

class _PeriodDraft {
  const _PeriodDraft({required this.start, required this.end, required this.excluded});

  final LocalDay start;
  final LocalDay? end;
  final bool excluded;
}

class _PeriodEditResult {
  const _PeriodEditResult.save(this.draft) : delete = false;
  const _PeriodEditResult.delete()
      : draft = null,
        delete = true;

  final _PeriodDraft? draft;
  final bool delete;
}
