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
    final periods = ref.watch(periodHistoryProvider).value ?? const <PeriodEntry>[];
    final prediction = ref.watch(cyclePredictionProvider).value?.prediction;
    final today = LocalDay.fromDateTime(DateTime.now());
    final todayValues = ref.watch(dayValuesProvider(today.epochDay));

    return NylaPage(
      title: 'Calendar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthHeader(
            month: month,
            onPrevious: () {
              NylaHaptics.select();
              setState(() => month = DateTime(month.year, month.month - 1));
            },
            onNext: () {
              NylaHaptics.select();
              setState(() => month = DateTime(month.year, month.month + 1));
            },
          ),
          const SizedBox(height: 14),
          _CalendarBoard(month: month, periods: periods, prediction: prediction),
          const SizedBox(height: 13),
          const _Legend(),
          const SizedBox(height: 22),
          NylaSectionHeader(
            title: 'Today',
            actionLabel: 'Open log',
            onAction: () {
              NylaHaptics.select();
              context.go('/log?day=${today.toIsoString()}');
            },
          ),
          const SizedBox(height: 10),
          _TodaySummary(values: todayValues.value ?? const <DayValueEntry>[]),
          const SizedBox(height: 18),
          NylaPressable(
            onTap: () {
              NylaHaptics.select();
              context.push('/periods');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: NylaColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NylaColors.outline),
              ),
              child: const Row(
                children: [
                  Icon(Icons.history_rounded, color: NylaColors.violet, size: 19),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Period history',
                      style: TextStyle(color: NylaColors.ink, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: NylaColors.faintInk),
                ],
              ),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.onPrevious, required this.onNext});

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              monthYear(month),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
            ),
          ),
          _Arrow(icon: Icons.chevron_left_rounded, label: 'Previous month', onTap: onPrevious),
          const SizedBox(width: 5),
          _Arrow(icon: Icons.chevron_right_rounded, label: 'Next month', onTap: onNext),
        ],
      );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        semanticsLabel: label,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: NylaColors.paper,
            shape: BoxShape.circle,
            border: Border.all(color: NylaColors.outline),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: NylaColors.mutedInk, size: 18),
        ),
      );
}

class _CalendarBoard extends StatelessWidget {
  const _CalendarBoard({required this.month, required this.periods, required this.prediction});

  final DateTime month;
  final List<PeriodEntry> periods;
  final CyclePrediction? prediction;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final cells = ((leading + days + 6) ~/ 7) * 7;
    final today = LocalDay.fromDateTime(DateTime.now());

    return NylaPaperSurface(
      padding: const EdgeInsets.fromLTRB(9, 15, 9, 10),
      radius: BorderRadius.circular(20),
      shadow: false,
      child: Column(
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
                        fontSize: 7.7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
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
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final number = index - leading + 1;
              if (number < 1 || number > days) return const SizedBox.shrink();
              final day = LocalDay.fromDateTime(DateTime(month.year, month.month, number));
              final recorded = _isRecordedPeriod(day);
              final expected = _isPredicted(day);
              return _DayCell(
                number: number,
                recorded: recorded,
                expected: expected,
                today: day == today,
                semanticsLabel:
                    '${friendlyDay(day)}${recorded ? ', recorded period' : ''}${expected ? ', expected range' : ''}${day == today ? ', today' : ''}',
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.number,
    required this.recorded,
    required this.expected,
    required this.today,
    required this.semanticsLabel,
    required this.onTap,
  });

  final int number;
  final bool recorded;
  final bool expected;
  final bool today;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticsLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: recorded
                        ? NylaColors.roseSoft
                        : expected
                            ? NylaColors.sageSoft
                            : Colors.transparent,
                    shape: BoxShape.circle,
                    border: today
                        ? Border.all(color: NylaColors.violet, width: 1.4)
                        : expected
                            ? Border.all(color: NylaColors.sage, width: 1)
                            : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: recorded ? NylaColors.wine : NylaColors.ink,
                      fontSize: 11.5,
                      fontWeight: recorded || today ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (today && !recorded && !expected)
                  const Positioned(
                    bottom: 1,
                    child: SizedBox.square(
                      dimension: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: NylaColors.violet, shape: BoxShape.circle),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Wrap(
        alignment: WrapAlignment.center,
        spacing: 17,
        runSpacing: 8,
        children: [
          _LegendItem(color: NylaColors.roseSoft, label: 'Period'),
          _LegendItem(color: NylaColors.sageSoft, label: 'Expected'),
          _LegendItem(color: NylaColors.lavenderSoft, label: 'Today'),
        ],
      );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: NylaColors.mutedInk, fontSize: 9.8, fontWeight: FontWeight.w600),
          ),
        ],
      );
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.values});

  final List<DayValueEntry> values;

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final item in values) item.key: item};
    final rows = <_SummaryValue>[
      _SummaryValue(
        icon: Icons.water_drop_outlined,
        tint: NylaColors.roseWash,
        label: 'Flow',
        value: _label(byKey['flow']?.value) ?? 'Not logged',
      ),
      _SummaryValue(
        icon: Icons.bolt_rounded,
        tint: NylaColors.lavenderSoft,
        label: 'Cramps',
        value: _severity(byKey['cramps']?.severity),
      ),
      _SummaryValue(
        icon: Icons.sentiment_satisfied_alt_rounded,
        tint: const Color(0xFFE8F2FA),
        label: 'Mood',
        value: _label(byKey['mood']?.value) ?? 'Not logged',
      ),
      _SummaryValue(
        icon: Icons.eco_outlined,
        tint: NylaColors.sageSoft,
        label: 'Energy',
        value: _label(byKey['energy']?.value) ?? 'Not logged',
      ),
    ];

    return NylaPaperSurface(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
      shadow: false,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _SummaryRow(value: rows[i]),
            if (i != rows.length - 1) const NylaHairline(margin: EdgeInsets.only(left: 48)),
          ],
        ],
      ),
    );
  }

  static String? _label(String? value) {
    if (value == null) return null;
    final words = value.replaceAll('_', ' ').split(' ');
    return words.map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }

  static String _severity(int? value) => switch (value) {
        null => 'Not logged',
        0 => 'None',
        1 => 'Mild',
        2 => 'Moderate',
        3 => 'Strong',
        _ => 'Logged',
      };
}

class _SummaryValue {
  const _SummaryValue({required this.icon, required this.tint, required this.label, required this.value});

  final IconData icon;
  final Color tint;
  final String label;
  final String value;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.value});

  final _SummaryValue value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            NylaIconToken(icon: value.icon, background: value.tint, size: 36),
            const SizedBox(width: 11),
            Expanded(
              child: Text(value.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
            ),
            Text(
              value.value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11.5,
                    color: NylaColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
}
