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
    expect(plan.careHour, 14);
  });

  test('strong cramps outside a period still keep safety context', () {
    final plan = companionNotificationPlan(
      context(severities: const {'cramps': 3}),
    );

    expect(plan.dailyBody.toLowerCase(), contains('cramp'));
    expect(
      plan.dailyBody.toLowerCase(),
      anyOf(contains('help'), contains('medical')),
    );
    expect(plan.careBody, isNotNull);
  });

  test('early period days are cared for even without a symptom log', () {
    final plan = companionNotificationPlan(
      context(phase: CyclePhase.menstruation, cycleDay: 2),
    );

    expect(plan.dailyBody.toLowerCase(), contains('period'));
    expect(plan.careBody, isNotNull);
  });

  test('poor sleep plus low energy gets an earlier daytime care moment', () {
    final plan = companionNotificationPlan(
      context(
        values: const {'sleep': 'poor', 'energy': 'very_low'},
      ),
    );

    expect(
      plan.dailyBody.toLowerCase(),
      anyOf(contains('sleep'), contains('tired'), contains('energy')),
    );
    expect(plan.careBody, isNotNull);
    expect(plan.careHour, 11);
    expect(plan.careMinute, 30);
  });

  test('an anxious mood gets support without automatically adding extra noise', () {
    final plan = companionNotificationPlan(
      context(moods: const {'anxious'}),
    );

    expect(
      plan.dailyBody.toLowerCase(),
      anyOf(
        contains('loud'),
        contains('noisy'),
        contains('anxious'),
        contains('racing'),
        contains('overwhelmed'),
        contains('urgent'),
      ),
    );
    expect(plan.careBody, isNull);
  });

  test('anxious plus exhausted can earn one later care check-in', () {
    final plan = companionNotificationPlan(
      context(
        moods: const {'anxious'},
        values: const {'energy': 'low'},
      ),
    );

    expect(plan.careBody, isNotNull);
    expect(plan.careHour, 16);
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

    expect(
      plan.dailyBody.toLowerCase(),
      anyOf(
        contains('lot'),
        contains('piling'),
        contains('several'),
        contains('rough'),
        contains('check-in'),
      ),
    );
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
    expect(
      plan.dailyBody.toLowerCase(),
      anyOf(contains('help'), contains('medical')),
    );
    expect(plan.careBody, isNotNull);
    expect(plan.careHour, 13);
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
    expect(
      plan.dailyBody.toLowerCase(),
      anyOf(contains('help'), contains('medical')),
    );
    expect(plan.careBody, isNotNull);
  });

  test('cravings are met without moralising food', () {
    final bodies = {
      for (var seed = 0; seed < 10; seed++)
        companionNotificationPlan(
          context(values: const {'appetite': 'cravings'}, seed: seed),
        ).dailyBody,
    };

    expect(bodies.length, greaterThanOrEqualTo(5));
    final corpus = bodies.join(' ').toLowerCase();
    expect(
      corpus,
      anyOf(contains('moral'), contains('guilt'), contains('discipline')),
    );
  });

  test('good mood or energy gets varied positive companion responses', () {
    final bodies = {
      for (var seed = 0; seed < 12; seed++)
        companionNotificationPlan(
          context(
            values: const {'energy': 'high'},
            moods: const {'happy'},
            seed: seed,
          ),
        ).dailyBody,
    };

    expect(bodies.length, greaterThanOrEqualTo(6));
    expect(bodies.every((body) => body.trim().isNotEmpty), isTrue);
  });

  test('nearby predicted period gets gentle preparation language', () {
    final plan = companionNotificationPlan(context(daysUntil: 2));

    expect(plan.dailyBody.toLowerCase(), contains('period'));
    expect(plan.careBody, isNull);
  });

  test('ordinary phase days are contextual without deterministic promises', () {
    final follicular = companionNotificationPlan(
      context(phase: CyclePhase.follicular, seed: 1),
    ).dailyBody.toLowerCase();
    final midCycle = companionNotificationPlan(
      context(phase: CyclePhase.periOvulatory, seed: 2),
    ).dailyBody.toLowerCase();
    final luteal = companionNotificationPlan(
      context(phase: CyclePhase.luteal, seed: 3),
    ).dailyBody.toLowerCase();

    expect(follicular, isNot(contains('will feel')));
    expect(midCycle, isNot(contains('ovulated')));
    expect(luteal, isNot(contains('will feel')));
  });

  test('generic future check-ins rotate widely instead of repeating one line', () {
    final bodies = {
      for (var seed = 21000; seed < 21024; seed++)
        genericCompanionBody(seed),
    };

    expect(bodies.length, greaterThanOrEqualTo(10));
  });

  test('period forecast reminder families also rotate', () {
    final approaching = {
      for (var seed = 21000; seed < 21010; seed++)
        periodApproachingCompanionBody(seed),
    };
    final window = {
      for (var seed = 21000; seed < 21010; seed++)
        expectedWindowCompanionBody(seed),
    };

    expect(approaching.length, greaterThanOrEqualTo(5));
    expect(window.length, greaterThanOrEqualTo(5));
    expect(approaching.every((body) => body.toLowerCase().contains('period')), isTrue);
    expect(window.every((body) => body.toLowerCase().contains('period')), isTrue);
  });

  test('same rough context does not use one sentence every day', () {
    final bodies = {
      for (var seed = 21000; seed < 21012; seed++)
        companionNotificationPlan(
          context(
            phase: CyclePhase.menstruation,
            cycleDay: 1,
            severities: const {'cramps': 3},
            seed: seed,
          ),
        ).dailyBody,
    };

    expect(bodies.length, greaterThanOrEqualTo(5));
  });

  test('private companion copy is varied and never exposes health context', () {
    final bodies = {
      for (var seed = 0; seed < 16; seed++) privateCompanionBody(seed),
    };
    expect(bodies.length, greaterThanOrEqualTo(8));

    for (final body in bodies) {
      final lower = body.toLowerCase();
      expect(lower, isNot(contains('period')));
      expect(lower, isNot(contains('cramp')));
      expect(lower, isNot(contains('mood')));
      expect(lower, isNot(contains('sleep')));
      expect(lower, isNot(contains('bleed')));
      expect(lower, isNot(contains('headache')));
      expect(lower, isNot(contains('dizz')));
    }
  });
}
