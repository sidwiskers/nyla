enum TipCategory { cycle, body, care, products, comfort, symptoms, seekCare }

final class MedicalSource {
  const MedicalSource({
    required this.organization,
    required this.title,
    required this.url,
    required this.reviewedOn,
  });

  final String organization;
  final String title;
  final String url;
  final DateTime reviewedOn;
}

final class HealthTip {
  const HealthTip({
    required this.id,
    required this.category,
    required this.title,
    required this.flash,
    required this.details,
    required this.sources,
    required this.version,
    required this.lastReviewed,
    this.practical = const [],
    this.seekCare = const [],
    this.tags = const [],
  });

  final String id;
  final TipCategory category;
  final String title;
  final String flash;
  final List<String> details;
  final List<String> practical;
  final List<String> seekCare;
  final List<String> tags;
  final List<MedicalSource> sources;
  final int version;
  final DateTime lastReviewed;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return <String>[title, flash, ...details, ...practical, ...seekCare, ...tags]
        .any((value) => value.toLowerCase().contains(needle));
  }
}
