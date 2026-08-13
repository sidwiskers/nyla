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
        .expand((tip) => [tip.id, tip.title, tip.flash, ...tip.details, ...tip.tags])
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

  test('cycle companion cards stay contextual and non-deterministic', () {
    expect(cycleCompanionTips, hasLength(4));
    expect(
      cycleCompanionTips.map((tip) => tip.id).toSet(),
      {
        'cycle-now-period-start',
        'cycle-now-early',
        'cycle-now-middle',
        'cycle-now-before-period',
      },
    );

    for (final tip in cycleCompanionTips) {
      expect(tip.tags, contains('cycle context'));
      expect(tip.sources, isNotEmpty);
    }

    final middle = cycleCompanionTips.singleWhere(
      (tip) => tip.id == 'cycle-now-middle',
    );
    expect(
      middle.details.join(' ').toLowerCase(),
      contains('cannot confirm'),
      reason: 'Calendar context must not claim to identify ovulation.',
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

  test('search covers titles, body and tags', () {
    expect(healthTips.where((tip) => tip.matches('tampon')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cramps')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cleaning')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cycle context')), hasLength(4));
  });
}
