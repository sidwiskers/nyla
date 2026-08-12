import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics/nyla_haptics.dart';
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
      subtitle: 'Your history is solid. Predictions stay visibly uncertain.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(color: Color(0x12542B3C), blurRadius: 28, offset: Offset(0, 12)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 15),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [NylaColors.lavenderSoft, NylaColors.roseWash],
                    ),
                  ),
                  child: Row(
                    children: [
                      _MonthButton(
                        tooltip: 'Previous month',
                        icon: Icons.chevron_left_rounded,
                        onPressed: () {
                          NylaHaptics.select();
                          setState(() => month = DateTime(month.year, month.month - 1));
                        },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(monthYear(month), style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 3),
                            Text(
                              _monthContext(month),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      _MonthButton(
                        tooltip: 'Next month',
                        icon: Icons.chevron_right_rounded,
                        onPressed: () {
                          NylaHaptics.select();
                          setState(() => month = DateTime(month.year, month.month + 1));
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 17, 14, 18),
                  child: _MonthGrid(month: month, periods: periods, prediction: prediction),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _Legend(),
          if (prediction != null) ...[
            const SizedBox(height: 14),
            _PredictionNote(prediction: prediction),
          ],
          const SizedBox(height: 16),
          Material(
            color: NylaColors.wine,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                NylaHaptics.select();
                context.push('/periods');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Manage period history',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 82),
        ],
      ),
    );
  }

  String _monthContext(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year && value.month == now.month) return 'This month';
    if (value.isBefore(DateTime(now.year, now.month))) return 'Your recorded history';
    return 'Looking ahead';
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          color: NylaColors.wine,
        ),
      );
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
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: NylaColors.faintInk,
                        ),
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
                onTap: () {
                  NylaHaptics.select();
                  context.go('/log?day=${day.toIsoString()}');
                },
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: actual
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [NylaColors.rose, NylaColors.coral],
                            )
                          : null,
                      color: actual ? null : (predicted ? NylaColors.roseWash : Colors.transparent),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isToday
                            ? NylaColors.wine
                            : predicted
                                ? NylaColors.rose
                                : Colors.transparent,
                        width: isToday ? 1.7 : (predicted ? 1.0 : 0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: actual ? Colors.white : (isToday ? NylaColors.wine : NylaColors.mutedInk),
                        fontWeight: actual || isToday ? FontWeight.w800 : FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(color: NylaColors.rose, label: 'Recorded'),
          SizedBox(width: 20),
          _LegendItem(color: NylaColors.roseWash, outline: NylaColors.rose, label: 'Expected range'),
        ],
      ),
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
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: outline == null ? null : Border.all(color: outline!),
            ),
          ),
          const SizedBox(width: 7),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      );
}

class _PredictionNote extends StatelessWidget {
  const _PredictionNote({required this.prediction});

  final CyclePrediction prediction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [NylaColors.sageSoft, NylaColors.peachSoft]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.blur_on_rounded, color: NylaColors.wine, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'The outlined days are an uncertainty window, not a promise. Nyla widens it when your recent cycles vary more.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink),
              ),
            ),
          ],
        ),
      );
}
