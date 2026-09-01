import 'package:cycle_engine/cycle_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyla/core/notifications/companion_notification.dart';

CompanionNotificationContext context({
  CyclePhase? phase,
  int? cycleDay,
  int? daysUntil,
  Map<String, String> values = const {},
  Map<String, int> severities = const {},
  Set<String> moods = const {},
  int seed = 21000,
}) =>
    CompanionNotificationContext(
      phase: phase,
      cycleDay: cycleDay,
      daysUntilLikelyPeriod: daysUntil,
      values: values,
      severities: severities,
      moods: moods,
      daySeed: seed,
    );

void main() {
  test('strong period cramps get both a caring daily note and care nudge', () {
    final plan = companionNotificationPlan(
      context(
        phase: CyclePhase.menstruation,
        cycleDay: 1,
        severities: const {'cramps': 3},
      ),
    );

    expect(plan.dailyBody.toLowerCase(), contains('cramp'));
    expect(plan.careBody, isNotNull);
  });

  test('strong cramps outside a period still keep safety context', () {
    final plan = companionNotificationPlan(
      context(severities: const {'cramps': 3}),
    );

    expect(plan.dailyBody.toLowerCase(), contains('cramp'));
    expect(plan.dailyBody.toLowerCase(), contains('help'));
    expect(plan.careBody, isNotNull);
  });

  test('early period days are cared for even without a symptom log', () {
    final plan = companionNotificationPlan(
      context(phase: CyclePhase.menstruation, cycleDay: 2),
    );

    expect(plan.dailyBody.toLowerCase(), contains('period'));
    expect(plan.careBody, isNotNull);
  });

  test('poor sleep plus low energy is treated as a rough day', () {
    final plan = companionNotificationPlan(
      context(
        values: const {'sleep': 'poor', 'energy': 'very_low'},
      ),
    );

    expect(plan.dailyBody.toLowerCase(), anyOf(contains('sleep'), contains('tired')));
    expect(plan.careBody, isNotNull);
  });

  test('an anxious mood gets support without automatically adding extra noise', () {
    final plan = companionNotificationPlan(
      context(moods: const {'anxious'}),
    );

    expect(plan.dailyBody.toLowerCase(), anyOf(contains('anxious'), contains('loud')));
    expect(plan.careBody, isNull);
  });

  test('several moderate rough signals collapse into one general care message', () {
    final plan = companionNotificationPlan(
      context(
        severities: const {
          'cramps': 2,
          'headache': 2,
          'bloating': 2,
        },
      ),
    );

    expect(plan.dailyBody.toLowerCase(), anyOf(contains('lot'), contains('piling')));
    expect(plan.careBody, isNotNull);
  });

  test('dizziness takes priority over other signals and includes escalation', () {
    final plan = companionNotificationPlan(
      context(
        values: const {'sleep': 'very_poor'},
        severities: const {'dizziness': 3, 'cramps': 3},
      ),
    );

    expect(plan.dailyBody.toLowerCase(), contains('dizz'));
    expect(plan.dailyBody.toLowerCase(), contains('help'));
    expect(plan.careBody, isNotNull);
  });

  test('strong headache stays specific even when other rough signals exist', () {
    final plan = companionNotificationPlan(
      context(
        severities: const {
          'headache': 3,
          'cramps': 2,
          'bloating': 2,
        },
      ),
    );

    expect(plan.dailyBody.toLowerCase(), contains('headache'));
    expect(plan.dailyBody.toLowerCase(), contains('help'));
    expect(plan.careBody, isNotNull);
  });

  test('cravings are met without moralising food', () {
    final plan = companionNotificationPlan(
      context(values: const {'appetite': 'cravings'}),
    );

    expect(plan.dailyBody.toLowerCase(), contains('moral'));
    expect(plan.careBody, isNull);
  });

  test('good mood or energy gets a positive companion response', () {
    final plan = companionNotificationPlan(
      context(
        values: const {'energy': 'high'},
        moods: const {'happy'},
      ),
    );

    expect(
      plan.dailyBody.toLowerCase(),
      anyOf(contains('lighter'), contains('ease'), contains('brighter')),
    );
    expect(plan.careBody, isNull);
  });

  test('nearby predicted period gets gentle preparation language', () {
    final plan = companionNotificationPlan(context(daysUntil: 2));

    expect(plan.dailyBody.toLowerCase(), contains('period'));
    expect(plan.careBody, isNull);
  });

  test('ordinary days keep a small human check-in instead of phase jargon', () {
    final plan = companionNotificationPlan(
      context(phase: CyclePhase.follicular),
    );

    expect(plan.dailyBody.toLowerCase(), contains('check'));
    expect(plan.dailyBody.toLowerCase(), isNot(contains('follicular')));
  });

  test('private companion copy never exposes a symptom or period', () {
    for (var seed = 0; seed < 8; seed++) {
      final body = privateCompanionBody(seed).toLowerCase();
      expect(body, isNot(contains('period')));
      expect(body, isNot(contains('cramp')));
      expect(body, isNot(contains('mood')));
      expect(body, isNot(contains('sleep')));
      expect(body, isNot(contains('bleed')));
    }
  });
}
