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

  test('search covers titles, body and tags', () {
    expect(healthTips.where((tip) => tip.matches('tampon')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cramps')), isNotEmpty);
    expect(healthTips.where((tip) => tip.matches('cleaning')), isNotEmpty);
  });
}
