import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/model/date_text.dart';
import '../../core/theme/nyla_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers.dart';
import '../../widgets/nyla_page.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final periods = ref.watch(periodHistoryProvider).value ?? const <PeriodEntry>[];
    final prediction = ref.watch(cyclePredictionProvider).value?.prediction;

    return NylaPage(
      title: 'Calendar',
      subtitle: 'History first. Predictions stay visibly uncertain.',
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          monthYear(month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _MonthGrid(month: month, periods: periods, prediction: prediction),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Legend(),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.periods, required this.prediction});

  final DateTime month;
  final List<PeriodEntry> periods;
  final CyclePrediction? prediction;

  @override
  Widget build(BuildContext context) {
    const weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final cells = ((leading + days + 6) ~/ 7) * 7;
    final today = LocalDay.fromDateTime(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekday)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemBuilder: (context, index) {
            final number = index - leading + 1;
            if (number < 1 || number > days) return const SizedBox.shrink();
            final day = LocalDay.fromDateTime(DateTime(month.year, month.month, number));
            final actual = _isRecordedPeriod(day);
            final predicted = _isPredicted(day);
            final isToday = day == today;
            return Semantics(
              button: true,
              label: '${friendlyDay(day)}${actual ? ', recorded period' : ''}${predicted ? ', predicted range' : ''}',
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.go('/log?day=${day.toIsoString()}'),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: actual ? NylaColors.roseSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: predicted
                            ? NylaColors.rose
                            : isToday
                                ? NylaColors.ink
                                : Colors.transparent,
                        width: predicted || isToday ? 1.2 : 0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: actual ? NylaColors.ink : NylaColors.mutedInk,
                        fontWeight: isToday || actual ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isRecordedPeriod(LocalDay day) {
    for (final period in periods) {
      final end = period.endDay ?? period.startDay;
      if (day.epochDay >= period.startDay && day.epochDay <= end) return true;
    }
    return false;
  }

  bool _isPredicted(LocalDay day) {
    final value = prediction;
    if (value == null) return false;
    return day.epochDay >= value.earliestStart.epochDay && day.epochDay <= value.latestStart.epochDay;
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _LegendItem(color: NylaColors.roseSoft, label: 'Recorded'),
        SizedBox(width: 18),
        _LegendItem(color: Colors.transparent, outline: NylaColors.rose, label: 'Expected range'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.outline});

  final Color color;
  final Color? outline;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: outline == null ? null : Border.all(color: outline!),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
        ],
      );
}
