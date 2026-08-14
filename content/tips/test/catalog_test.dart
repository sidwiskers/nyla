import 'package:health_content/health_content.dart';
import 'package:test/test.dart';

void main() {
  test('catalog IDs are unique and publication metadata is complete', () {
    final ids = <String>{};
    for (final tip in healthTips) {
      expect(ids.add(tip.id), isTrue, reason: 'Duplicate tip ID: ${tip.id}');
      expect(tip.title.trim(), isNotEmpty);
      expect(tip.flash.trim(), isNotEmpty);
      expect(tip.details, isNotEmpty);
      expect(tip.sources, isNotEmpty);
      expect(tip.version, greaterThan(0));
      for (final source in tip.sources) {
        expect(source.organization.trim(), isNotEmpty);
        expect(source.title.trim(), isNotEmpty);
        expect(Uri.tryParse(source.url)?.hasScheme, isTrue);
        expect(source.reviewedOn.isAfter(DateTime.utc(2026, 1, 1)), isTrue);
      }
    }
  });

  test('catalog contains no excluded product modules', () {
    final corpus = healthTips
        .expand(
          (tip) => [
            tip.id,
            tip.title,
            tip.flash,
            ...tip.details,
            ...tip.tags,
            ...tip.experiences,
          ],
        )
        .join(' ')
        .toLowerCase();
    for (final excluded in [
      'pregnancy',
      'pregnant',
      'trying to conceive',
      'conception',
      'fertility probability',
      'fertile window',
      'ovulation prediction',
      'masturbation',
      'sexual coaching',
    ]) {
      expect(corpus.contains(excluded), isFalse);
    }
  });

  test('cycle companion catalog covers the whole cycle without pretending certainty', () {
    expect(cycleCompanionTips, hasLength(13));
    expect(
      cycleCompanionTips.map((tip) => tip.id).toSet(),
      {
        'cycle-now-period-start',
        'cycle-now-early',
        'cycle-now-middle',
        'cycle-now-before-period',
        'cycle-phase-menstruation',
        'cycle-phase-follicular',
        'cycle-phase-periovulatory',
        'cycle-phase-luteal',
        'cycle-phase-uncertain',
        'cycle-body-prostaglandins',
        'cycle-body-mucus',
        'cycle-body-mood-is-personal',
        'cycle-body-appetite',
      },
    );

    for (final tip in cycleCompanionTips) {
      expect(tip.tags, contains('cycle context'));
      expect(tip.sources, isNotEmpty);
    }

    for (final id in [
      'cycle-phase-menstruation',
      'cycle-phase-follicular',
      'cycle-phase-periovulatory',
      'cycle-phase-luteal',
      'cycle-phase-uncertain',
    ]) {
      final phase = cycleCompanionTips.singleWhere((tip) => tip.id == id);
      expect(phase.experiences, isNotEmpty, reason: '$id should have gentle experience cues.');
    }

    final middle = cycleCompanionTips.singleWhere(
      (tip) => tip.id == 'cycle-now-middle',
    );
    expect(
      middle.details.join(' ').toLowerCase(),
      contains('cannot confirm'),
      reason: 'Calendar context must not claim to identify ovulation.',
    );

    final peri = cycleCompanionTips.singleWhere(
      (tip) => tip.id == 'cycle-phase-periovulatory',
    );
    expect(
      peri.details.join(' ').toLowerCase(),
      contains('cannot prove'),
      reason: 'A mucus observation can support context but must not establish an exact day.',
    );

    final premenstrual = cycleCompanionTips.singleWhere(
      (tip) => tip.id == 'cycle-now-before-period',
    );
    expect(
      premenstrual.details.join(' ').toLowerCase(),
      contains('not everyone'),
      reason: 'Premenstrual copy must describe possibility, not destiny.',
    );
  });

  test('search covers titles, body, tags and experience cues', () {
    expect(healthTips.where((tip) => tip.matches('tampon')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cramps')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cleaning')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cycle context')), hasLength(13));
    expect(healthTips.where((tip) => tip.matches('stretchier mucus')), isNotEmpty);
  });
}
