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
import '../../widgets/nyla_ui.dart';

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
      subtitle: 'History is certain. Predictions are allowed to be uncertain.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthHeader(
            month: month,
            contextLabel: _monthContext(month),
            onPrevious: () {
              NylaHaptics.select();
              setState(() => month = DateTime(month.year, month.month - 1));
            },
            onNext: () {
              NylaHaptics.select();
              setState(() => month = DateTime(month.year, month.month + 1));
            },
          ),
          const SizedBox(height: 15),
          _CalendarBoard(
            month: month,
            periods: periods,
            prediction: prediction,
          ),
          const SizedBox(height: 14),
          const _Legend(),
          if (prediction != null) ...[
            const SizedBox(height: 22),
            _PredictionStory(prediction: prediction),
          ],
          const SizedBox(height: 24),
          _HistoryAction(
            onTap: () {
              NylaHaptics.select();
              context.push('/periods');
            },
          ),
          const SizedBox(height: 92),
        ],
      ),
    );
  }

  String _monthContext(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year && value.month == now.month) return 'This month';
    if (value.isBefore(DateTime(now.year, now.month))) {
      return 'Recorded history';
    }
    return 'Looking ahead';
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.contextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final String contextLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _RoundArrow(
            tooltip: 'Previous month',
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthYear(month),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 27),
                ),
                const SizedBox(height: 3),
                Text(
                  contextLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          _RoundArrow(
            tooltip: 'Next month',
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      );
}

class _RoundArrow extends StatelessWidget {
  const _RoundArrow({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        semanticsLabel: tooltip,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: NylaColors.paper,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D2A111E),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: NylaColors.wine),
        ),
      );
}

class _CalendarBoard extends StatelessWidget {
  const _CalendarBoard({
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

    return NylaPaperSurface(
      padding: const EdgeInsets.fromLTRB(9, 18, 9, 15),
      radius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in weekdays)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: NylaColors.faintInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
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
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final number = index - leading + 1;
              if (number < 1 || number > days) {
                return const SizedBox.shrink();
              }

              final day =
                  LocalDay.fromDateTime(DateTime(month.year, month.month, number));
              final actual = _isRecordedPeriod(day);
              final predicted = _isPredicted(day);
              final previousInWeek = index % 7 != 0;
              final nextInWeek = index % 7 != 6;
              final actualBefore =
                  previousInWeek && _isRecordedPeriod(day.addDays(-1));
              final actualAfter =
                  nextInWeek && _isRecordedPeriod(day.addDays(1));
              final predictedBefore =
                  previousInWeek && _isPredicted(day.addDays(-1));
              final predictedAfter =
                  nextInWeek && _isPredicted(day.addDays(1));

              return _DayCell(
                number: number,
                recorded: actual,
                expected: predicted,
                recordedBefore: actualBefore,
                recordedAfter: actualAfter,
                expectedBefore: predictedBefore,
                expectedAfter: predictedAfter,
                today: day == today,
                semanticsLabel:
                    '${friendlyDay(day)}${actual ? ', recorded period' : ''}${predicted ? ', expected range' : ''}',
                onTap: () {
                  NylaHaptics.select();
                  context.go('/log?day=${day.toIsoString()}');
                },
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isRecordedPeriod(LocalDay day) {
    for (final period in periods) {
      final end = period.endDay ?? period.startDay;
      if (day.epochDay >= period.startDay && day.epochDay <= end) {
        return true;
      }
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
    required this.recorded,
    required this.expected,
    required this.recordedBefore,
    required this.recordedAfter,
    required this.expectedBefore,
    required this.expectedAfter,
    required this.today,
    required this.semanticsLabel,
    required this.onTap,
  });

  final int number;
  final bool recorded;
  final bool expected;
  final bool recordedBefore;
  final bool recordedAfter;
  final bool expectedBefore;
  final bool expectedAfter;
  final bool today;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticsLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (expected && !recorded)
                Positioned(
                  left: expectedBefore ? 0 : 6,
                  right: expectedAfter ? 0 : 6,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: NylaColors.roseWash,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(expectedBefore ? 2 : 99),
                        right: Radius.circular(expectedAfter ? 2 : 99),
                      ),
                      border: Border.all(
                        color: NylaColors.rose.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                ),
              if (recorded)
                Positioned(
                  left: recordedBefore ? 0 : 5,
                  right: recordedAfter ? 0 : 5,
                  height: 33,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [NylaColors.rose, NylaColors.coral],
                      ),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(recordedBefore ? 2 : 99),
                        right: Radius.circular(recordedAfter ? 2 : 99),
                      ),
                    ),
                  ),
                ),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: today
                      ? Border.all(
                          color: recorded ? Colors.white : NylaColors.wine,
                          width: 1.7,
                        )
                      : null,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: recorded ? Colors.white : NylaColors.ink,
                    fontSize: 13,
                    fontWeight:
                        recorded || today ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (today && !recorded)
                const Positioned(
                  bottom: 4,
                  child: SizedBox.square(
                    dimension: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: NylaColors.rose,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _LegendItem(
            recorded: true,
            label: 'Recorded',
          ),
          const SizedBox(width: 22),
          const _LegendItem(
            recorded: false,
            label: 'Expected range',
          ),
        ],
      );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.recorded, required this.label});

  final bool recorded;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 24,
            height: 12,
            decoration: BoxDecoration(
              gradient: recorded
                  ? const LinearGradient(
                      colors: [NylaColors.rose, NylaColors.coral],
                    )
                  : null,
              color: recorded ? null : NylaColors.roseWash,
              borderRadius: BorderRadius.circular(99),
              border: recorded
                  ? null
                  : Border.all(
                      color: NylaColors.rose.withValues(alpha: 0.5),
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      );
}

class _PredictionStory extends StatelessWidget {
  const _PredictionStory({required this.prediction});

  final CyclePrediction prediction;

  @override
  Widget build(BuildContext context) => NylaInlineNote(
        icon: Icons.blur_on_rounded,
        title:
            'Expected ${rangeText(prediction.earliestStart, prediction.latestStart)}',
        body:
            'This is a window, not a promise. Recent variation is about ${prediction.variabilityDays.toStringAsFixed(1)} days, so Nyla leaves room for uncertainty.',
        accent: NylaColors.violet,
      );
}

class _HistoryAction extends StatelessWidget {
  const _HistoryAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 15, 15, 15),
          decoration: BoxDecoration(
            color: NylaColors.wine,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E2A111E),
                blurRadius: 24,
                offset: Offset(0, 11),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.edit_calendar_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Manage period history',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.86),
                size: 19,
              ),
            ],
          ),
        ),
      );
}
