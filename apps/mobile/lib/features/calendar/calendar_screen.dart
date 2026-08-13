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
    final periods =
        ref.watch(periodHistoryProvider).value ?? const <PeriodEntry>[];
    final prediction = ref.watch(cyclePredictionProvider).value?.prediction;

    return NylaPage(
      title: 'Calendar',
      subtitle: 'Period history and expected dates.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalendarCanvas(
            month: month,
            periods: periods,
            prediction: prediction,
            onPrevious: () {
              NylaHaptics.select();
              setState(
                () => month = DateTime(month.year, month.month - 1),
              );
            },
            onNext: () {
              NylaHaptics.select();
              setState(
                () => month = DateTime(month.year, month.month + 1),
              );
            },
          ),
          if (prediction != null) ...[
            const SizedBox(height: 16),
            _PredictionCard(prediction: prediction),
          ],
          const SizedBox(height: 15),
          _HistoryAction(
            onTap: () {
              NylaHaptics.select();
              context.push('/periods');
            },
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _CalendarCanvas extends StatelessWidget {
  const _CalendarCanvas({
    required this.month,
    required this.periods,
    required this.prediction,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final List<PeriodEntry> periods;
  final CyclePrediction? prediction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4EEF9), NylaColors.cream, Color(0xFFFFF2ED)],
            stops: [0, 0.56, 1],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142B2231),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _MonthButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous month',
                  onTap: onPrevious,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        monthYear(month),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontSize: 25),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _monthContext(month),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                _MonthButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next month',
                  onTap: onNext,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MonthGrid(
              month: month,
              periods: periods,
              prediction: prediction,
            ),
            const SizedBox(height: 16),
            const _Legend(),
          ],
        ),
      );

  String _monthContext(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year && value.month == now.month) return 'This month';
    if (value.isBefore(DateTime(now.year, now.month))) return 'History';
    return 'Upcoming';
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.76),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon),
          color: NylaColors.violet,
        ),
      );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.periods,
    required this.prediction,
  });

  final DateTime month;
  final List<PeriodEntry> periods;
  final CyclePrediction? prediction;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final cells = ((leading + days + 6) ~/ 7) * 7;
    final today = LocalDay.fromDateTime(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: NylaColors.faintInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemBuilder: (context, index) {
            final number = index - leading + 1;
            if (number < 1 || number > days) return const SizedBox.shrink();
            final day = LocalDay.fromDateTime(
              DateTime(month.year, month.month, number),
            );
            final actual = _isRecordedPeriod(day);
            final predicted = _isPredicted(day);
            return _DayCell(
              number: number,
              actual: actual,
              predicted: predicted,
              today: day == today,
              semanticsLabel:
                  '${friendlyDay(day)}${actual ? ', period' : ''}${predicted && !actual ? ', expected period range' : ''}',
              onTap: () {
                NylaHaptics.select();
                context.go('/log?day=${day.toIsoString()}');
              },
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
    return day.epochDay >= value.earliestStart.epochDay &&
        day.epochDay <= value.latestStart.epochDay;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.number,
    required this.actual,
    required this.predicted,
    required this.today,
    required this.semanticsLabel,
    required this.onTap,
  });

  static const expectedGreen = Color(0xFF6F9B82);
  static const expectedFill = Color(0xFFE8F2EC);

  final int number;
  final bool actual;
  final bool predicted;
  final bool today;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final expectedOnly = predicted && !actual;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: actual
                      ? NylaColors.rose
                      : expectedOnly
                          ? expectedFill
                          : Colors.transparent,
                  shape: BoxShape.circle,
                  border: expectedOnly
                      ? Border.all(color: expectedGreen, width: 1.2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: actual
                        ? Colors.white
                        : expectedOnly
                            ? const Color(0xFF4D715D)
                            : NylaColors.mutedInk,
                    fontSize: 13,
                    fontWeight:
                        actual || today ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (today && !actual && !expectedOnly)
                const Positioned(
                  bottom: 2,
                  child: SizedBox(
                    width: 4,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: NylaColors.violet,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: NylaColors.rose, label: 'Period'),
            SizedBox(width: 22),
            _LegendDot(color: Color(0xFF6F9B82), label: 'Expected'),
          ],
        ),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: NylaColors.mutedInk,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction});

  final CyclePrediction prediction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [NylaColors.lavenderSoft, NylaColors.sageSoft],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF6F9B82),
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected ${rangeText(prediction.earliestStart, prediction.latestStart)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on your recent cycles. This range can shift.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HistoryAction extends StatelessWidget {
  const _HistoryAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 15, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NylaColors.roseWash,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.edit_calendar_rounded,
                    color: NylaColors.violet,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Period history',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add or correct dates',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 11.2),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NylaColors.faintInk,
                ),
              ],
            ),
          ),
        ),
      );
}
