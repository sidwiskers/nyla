import 'models.dart';

final _reviewed = DateTime.utc(2026, 8, 14);

final _sleepDaily = MedicalSource(
  organization: 'Journal of Psychosomatic Research',
  title: 'Self-reported sleep across the menstrual cycle in young, healthy women',
  url: 'https://pubmed.ncbi.nlm.nih.gov/15016584/',
  reviewedOn: _reviewed,
);

final _sleepWearable = MedicalSource(
  organization: "International Journal of Women's Health",
  title: 'Tracking Sleep, Temperature, Heart Rate, and Daily Symptoms Across the Menstrual Cycle with the Oura Ring in Healthy Women',
  url: 'https://pubmed.ncbi.nlm.nih.gov/35422659/',
  reviewedOn: _reviewed,
);

final _breastProspective = MedicalSource(
  organization: 'PLOS ONE',
  title: 'Breast tenderness and swelling experiences related to menstrual cycles and ovulation in healthy premenopausal women',
  url: 'https://pubmed.ncbi.nlm.nih.gov/40354418/',
  reviewedOn: _reviewed,
);

final _giDaily = MedicalSource(
  organization: 'Research in Nursing & Health',
  title: 'Relationship between gastrointestinal and dysmenorrheic symptoms at menses',
  url: 'https://pubmed.ncbi.nlm.nih.gov/8552802/',
  reviewedOn: _reviewed,
);

final _giHealthy = MedicalSource(
  organization: "BMC Women's Health",
  title: 'Gastrointestinal symptoms before and during menses in healthy women',
  url: 'https://pubmed.ncbi.nlm.nih.gov/24450290/',
  reviewedOn: _reviewed,
);

final _acneQuantitative = MedicalSource(
  organization: 'Archives of Dermatology',
  title: 'Quantitative documentation of a premenstrual flare of facial acne in adult women',
  url: 'https://pubmed.ncbi.nlm.nih.gov/15096370/',
  reviewedOn: _reviewed,
);

final cycleBodyTips = <HealthTip>[
  HealthTip(
    id: 'cycle-body-sleep',
    category: TipCategory.body,
    title: 'Sleep can feel different without changing in one universal way',
    flash:
        'Some people report poorer sleep quality before or during a period, but objective sleep changes are often small or inconsistent.',
    details: [
      'Prospective daily ratings in healthy ovulating women found lower perceived sleep quality in the few days before menstruation and during bleeding, while sleep duration and continuity were largely unchanged.',
      'Wearable studies also find physiological cycle signals without a matching large change in sleep for everyone. Your repeated sleep logs are therefore more useful than assuming a phase should make you sleep badly.',
    ],
    practical: [
      'If poor sleep repeats in the same part of your cycle, Nyla can learn the timing without claiming the cycle is the only cause.',
    ],
    tags: ['cycle context', 'sleep', 'premenstrual', 'menstruation', 'personal patterns'],
    experiences: ['Poorer sleep quality', 'More tiredness', 'No obvious sleep change'],
    sources: [_sleepDaily, _sleepWearable],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-body-breast',
    category: TipCategory.body,
    title: 'Breast tenderness can have a real cycle pattern',
    flash:
        'Tenderness or swelling can rise before a period for some people and may repeat quite consistently within the same person.',
    details: [
      'Prospective daily data across hundreds of cycles show that breast tenderness and swelling can vary meaningfully with menstrual-cycle and ovulatory patterns.',
      'A recurring late-cycle pattern can be useful context, but a new lump, focal persistent pain, skin change or nipple change should not be explained away as “just hormones.”',
    ],
    tags: ['cycle context', 'breast tenderness', 'luteal phase', 'premenstrual', 'personal patterns'],
    experiences: ['Tender breasts', 'Fullness or swelling', 'No change'],
    sources: [_breastProspective],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-body-digestion',
    category: TipCategory.body,
    title: 'The gut can join the menstrual conversation',
    flash:
        'Abdominal discomfort, nausea or looser stools can cluster around menstruation, especially when cramps are also stronger.',
    details: [
      'Daily-diary studies found stomach pain and nausea tracking with uterine cramping around menses. Surveys of otherwise healthy women also find gastrointestinal symptoms are common before and during menstruation.',
      'Not every bowel change is menstrual. Persistent symptoms, blood in stool, significant weight change or severe pain deserve their own medical assessment.',
    ],
    tags: ['cycle context', 'digestion', 'nausea', 'loose stool', 'menstruation', 'cramps'],
    experiences: ['Abdominal discomfort', 'Nausea', 'Looser stools', 'Bloating'],
    sources: [_giDaily, _giHealthy],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-body-skin',
    category: TipCategory.body,
    title: 'Breakouts can repeat before a period for some people',
    flash:
        'Premenstrual acne flares are documented, but they are not universal and a single breakout says little about cycle phase.',
    details: [
      'Quantitative lesion counts across repeated cycles have documented a late-luteal increase in inflammatory acne lesions in many—but not all—adult women who experience premenstrual acne.',
      'Nyla should learn this only from your own repeated skin logs rather than treating acne as a phase detector.',
    ],
    tags: ['cycle context', 'skin', 'breakout', 'acne', 'premenstrual', 'personal patterns'],
    experiences: ['Breakouts', 'Oilier skin', 'No skin change'],
    sources: [_acneQuantitative],
    version: 1,
    lastReviewed: _reviewed,
  ),
];
