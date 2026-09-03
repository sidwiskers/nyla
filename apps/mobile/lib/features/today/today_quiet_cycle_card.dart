import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nyla_theme.dart';
import '../../core/theme/nyla_typography.dart';
import '../../data/database/app_database.dart';

class TodayQuietCycleCard extends StatelessWidget {
  const TodayQuietCycleCard({
    required this.today,
    required this.periods,
    required this.prediction,
    required this.onStartPeriod,
    super.key,
  });

  final LocalDay today;
  final AsyncValue<List<PeriodEntry>> periods;
  final AsyncValue<PredictionResult> prediction;
  final Future<void> Function() onStartPeriod;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return periods.when(
      loading: () => Container(
        height: 128,
        decoration: BoxDecoration(
          color: palette.glass,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: palette.glassBorder),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      error: (_, _) => const _QuietMessage(
        icon: Icons.favorite_border_rounded,
        title: 'Cycle context is unavailable',
        body: 'Your saved history is unchanged. Try this view again in a moment.',
      ),
      data: (history) {
        if (history.isEmpty) {
          return _FirstCycleCard(onStartPeriod: onStartPeriod);
        }

        final day = _cycleDay(today, history);
        if (day == null) {
          return const _QuietMessage(
            icon: Icons.favorite_border_rounded,
            title: 'Your rhythm is taking shape',
            body: 'A little more history will make today’s cycle context more meaningful.',
          );
        }

        final estimate = prediction.value?.prediction;
        if (estimate == null || estimate.predictedCycleLength <= 0) {
          return _QuietRhythmCard(day: day);
        }

        final progress = (day / estimate.predictedCycleLength).clamp(0.04, 1.0).toDouble();
        return _QuietRhythmCard(
          day: day,
          progress: progress,
          cycleLength: estimate.predictedCycleLength,
        );
      },
    );
  }

  int? _cycleDay(LocalDay current, List<PeriodEntry> history) {
    final starts = history
        .where((entry) => entry.startDay <= current.epochDay)
        .map((entry) => entry.startDay)
        .toList(growable: false);
    if (starts.isEmpty) return null;
    final latest = starts.reduce((a, b) => a > b ? a : b);
    final day = LocalDay(latest).daysUntil(current) + 1;
    return day > 0 ? day : null;
  }
}

class _QuietRhythmCard extends StatelessWidget {
  const _QuietRhythmCard({
    required this.day,
    this.progress,
    this.cycleLength,
  });

  final int day;
  final double? progress;
  final int? cycleLength;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.lavenderSoft, palette.roseWash],
        ),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'YOUR RHYTHM',
                style: TextStyle(
                  color: palette.violet,
                  fontSize: 9.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.96,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.glass,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Day $day',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.wine,
                        fontSize: 10.5,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'A quieter point in your cycle',
            style: NylaTypography.companion(
              Theme.of(context).textTheme.titleLarge,
              size: 21,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'There may be nothing especially phase-specific to notice today. Your own pattern is still the better guide.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.42),
          ),
          if (progress != null && cycleLength != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: palette.glassStrong,
                valueColor: AlwaysStoppedAnimation<Color>(palette.rose),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '~$cycleLength day cycle',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.mutedInk,
                      fontSize: 10.2,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirstCycleCard extends StatelessWidget {
  const _FirstCycleCard({required this.onStartPeriod});

  final Future<void> Function() onStartPeriod;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.lavenderSoft, palette.roseWash, palette.peachSoft],
        ),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'START HERE',
            style: TextStyle(
              color: palette.violet,
              fontSize: 9.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.96,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your cycle begins with one date',
            style: NylaTypography.display(
              Theme.of(context).textTheme.headlineMedium,
              size: 26,
              opticalSize: 31,
              weight: FontWeight.w600,
              height: 1.05,
              letterSpacing: -0.22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When your period starts, mark that first day. A few cycles of history will make timing and patterns more personal.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.44),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartPeriod,
              icon: const Icon(Icons.water_drop_rounded, size: 17),
              label: const Text('My period started'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietMessage extends StatelessWidget {
  const _QuietMessage({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.glass,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.lavenderSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: palette.violet, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
