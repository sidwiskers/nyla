import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/features/today/today_companion_card.dart';

void main() {
  const emptyValues = <dynamic>[];

  CyclePhaseContext context(
    CyclePhase phase, {
    PhaseConfidence confidence = PhaseConfidence.supported,
    int cycleDay = 9,
    int? daysUntilLikelyPeriod,
  }) =>
      CyclePhaseContext(
        phase: phase,
        confidence: confidence,
        cycleDay: cycleDay,
        daysUntilLikelyPeriod: daysUntilLikelyPeriod,
      );

  test('limited early-cycle context still shows a useful follicular identity', () {
    final phase = context(
      CyclePhase.follicular,
      confidence: PhaseConfidence.limited,
      cycleDay: 9,
    );

    expect(companionPhaseLabelFor(phase), 'LIKELY FOLLICULAR');
    expect(
      companionMessageFor(phase, emptyValues.cast()).body.toLowerCase(),
      contains('follicular'),
    );
  });

  test('uncertain timing stays useful without narrating product uncertainty', () {
    final phase = context(
      CyclePhase.uncertain,
      confidence: PhaseConfidence.limited,
      cycleDay: 16,
    );
    final message = companionMessageFor(phase, emptyValues.cast());

    expect(companionPhaseLabelFor(phase), 'YOUR CYCLE');
    expect(message.title, 'How is your body feeling today?');
    expect(message.body.toLowerCase(), isNot(contains('phase label')));
    expect(message.body.toLowerCase(), isNot(contains('nyla')));
    expect(message.body.toLowerCase(), isNot(contains('not sure')));
  });

  test('phase copy never repeats internal product-design language', () {
    const banned = [
      'phase label',
      'textbook',
      'not a verdict',
      'nyla will learn',
      'keep the context in the background',
      'scientific explanation',
      'rather say',
    ];

    final phases = [
      context(CyclePhase.menstruation, cycleDay: 2),
      context(CyclePhase.follicular, cycleDay: 9),
      context(CyclePhase.periOvulatory, cycleDay: 15),
      context(CyclePhase.luteal, cycleDay: 22, daysUntilLikelyPeriod: 5),
      context(
        CyclePhase.uncertain,
        confidence: PhaseConfidence.limited,
        cycleDay: 18,
      ),
    ];

    for (final phase in phases) {
      final message = companionMessageFor(phase, emptyValues.cast());
      final explanation = companionExplanationFor(phase, emptyValues.cast());
      final copy = '${message.title} ${message.body} ${message.tip ?? ''} '
              '${explanation.title} ${explanation.body} ${explanation.note}'
          .toLowerCase();
      for (final phrase in banned) {
        expect(copy, isNot(contains(phrase)), reason: 'Found "$phrase" in $copy');
      }
    }
  });
}
