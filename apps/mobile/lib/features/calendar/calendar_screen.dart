import 'dart:math' as math;

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
      subtitle: 'Recorded days stay clear. Predictions stay visibly uncertain.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalendarCanvas(
            month: month,
            periods: periods,
            prediction: prediction,
            onPrevious: () {
              NylaHaptics.select();
              setState(() => month = DateTime(month.year, month.month - 1));
            },
            onNext: () {
              NylaHaptics.select();
              setState(() => month = DateTime(month.year, month.month + 1));
            },
          ),
          if (prediction != null) ...[
            const SizedBox(height: 16),
            _PredictionStory(prediction: prediction),
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
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4EEF9), NylaColors.cream, Color(0xFFFFF2ED)],
            stops: [0, 0.56, 1],
          ),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x1833203E), blurRadius: 30, offset: Offset(0, 13)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -72,
              top: -64,
              child: CustomPaint(
                size: const Size.square(190),
                painter: const _MonthHaloPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _MonthButton(icon: Icons.chevron_left_rounded, tooltip: 'Previous month', onTap: onPrevious),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              monthYear(month),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26),
                            ),
                            const SizedBox(height: 3),
                            Text(_monthContext(month), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      _MonthButton(icon: Icons.chevron_right_rounded, tooltip: 'Next month', onTap: onNext),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _MonthGrid(month: month, periods: periods, prediction: prediction),
                  const SizedBox(height: 17),
                  const _Legend(),
                ],
              ),
            ),
          ],
        ),
      );

  String _monthContext(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year && value.month == now.month) return 'This month';
    if (value.isBefore(DateTime(now.year, now.month))) return 'Recorded history';
    return 'Looking ahead';
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.72),
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
  const _MonthGrid({required this.month, required this.periods, required this.prediction});

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
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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
            return _DayCell(
              number: number,
              actual: actual,
              predicted: predicted,
              today: isToday,
              semanticsLabel: '${friendlyDay(day)}${actual ? ', recorded period' : ''}${predicted ? ', expected range' : ''}',
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
    return day.epochDay >= value.earliestStart.epochDay && day.epochDay <= value.latestStart.epochDay;
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

  final int number;
  final bool actual;
  final bool predicted;
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
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: actual
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [NylaColors.violet, NylaColors.rose],
                          )
                        : null,
                    color: actual ? null : (predicted ? NylaColors.lavenderSoft : Colors.transparent),
                    shape: BoxShape.circle,
                    border: predicted && !actual ? Border.all(color: NylaColors.violet.withValues(alpha: 0.7), width: 1.15) : null,
                    boxShadow: actual
                        ? const [BoxShadow(color: Color(0x277056A3), blurRadius: 10, offset: Offset(0, 4))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: actual ? Colors.white : (predicted ? NylaColors.wine : NylaColors.mutedInk),
                      fontSize: 13,
                      fontWeight: actual || today ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (today && !actual)
                  const Positioned(
                    bottom: 2,
                    child: SizedBox(
                      width: 4,
                      height: 4,
                      child: DecoratedBox(decoration: BoxDecoration(color: NylaColors.rose, shape: BoxShape.circle)),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(19),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(kind: _LegendKind.recorded, label: 'Recorded'),
            SizedBox(width: 20),
            _LegendItem(kind: _LegendKind.expected, label: 'Expected range'),
          ],
        ),
      );
}

enum _LegendKind { recorded, expected }

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.kind, required this.label});

  final _LegendKind kind;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              gradient: kind == _LegendKind.recorded
                  ? const LinearGradient(colors: [NylaColors.violet, NylaColors.rose])
                  : null,
              color: kind == _LegendKind.expected ? NylaColors.lavenderSoft : null,
              shape: BoxShape.circle,
              border: kind == _LegendKind.expected ? Border.all(color: NylaColors.violet, width: 1) : null,
            ),
          ),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: NylaColors.mutedInk, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      );
}

class _PredictionStory extends StatelessWidget {
  const _PredictionStory({required this.prediction});

  final CyclePrediction prediction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(19, 18, 19, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [NylaColors.lavenderSoft, NylaColors.sageSoft]),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CustomPaint(painter: const _PredictionGlyphPainter()),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expected ${rangeText(prediction.earliestStart, prediction.latestStart)}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(
                    'The outlined days are a window, not a promise. Your recent cycle variation is about ${prediction.variabilityDays.toStringAsFixed(1)} days, so Nyla leaves room for uncertainty.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: NylaColors.ink, fontSize: 12.2),
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
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: NylaColors.roseWash, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.edit_calendar_rounded, color: NylaColors.violet, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Period history', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Correct or add past dates', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.2)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: NylaColors.faintInk),
              ],
            ),
          ),
        ),
      );
}

class _MonthHaloPainter extends CustomPainter {
  const _MonthHaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = NylaColors.lavender.withValues(alpha: 0.16);
    canvas.drawArc(Rect.fromCircle(center: center, radius: size.width * 0.33), -math.pi * 0.85, math.pi * 1.35, false, paint);
    paint
      ..strokeWidth = 5
      ..color = NylaColors.rose.withValues(alpha: 0.12);
    canvas.drawArc(Rect.fromCircle(center: center, radius: size.width * 0.44), -math.pi * 0.3, math.pi * 0.92, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PredictionGlyphPainter extends CustomPainter {
  const _PredictionGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = NylaColors.violet.withValues(alpha: 0.22);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = NylaColors.violet;
    canvas.drawArc(Rect.fromCircle(center: center, radius: 17), -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(Rect.fromCircle(center: center, radius: 17), -math.pi / 2, math.pi * 1.18, false, active);
    canvas.drawCircle(center, 4, Paint()..color = NylaColors.rose);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
