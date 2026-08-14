import 'models.dart';

final _reviewed = DateTime.utc(2026, 8, 14);

final _owhCycle = MedicalSource(
  organization: "U.S. Office on Women's Health",
  title: 'Your menstrual cycle',
  url: 'https://womenshealth.gov/menstrual-cycle/your-menstrual-cycle',
  reviewedOn: _reviewed,
);

final _owhPms = MedicalSource(
  organization: "U.S. Office on Women's Health",
  title: 'Premenstrual syndrome (PMS)',
  url: 'https://womenshealth.gov/menstrual-cycle/premenstrual-syndrome',
  reviewedOn: _reviewed,
);

final _endotextCycle = MedicalSource(
  organization: 'National Library of Medicine / Endotext',
  title: 'The Normal Menstrual Cycle and the Control of Ovulation',
  url: 'https://www.ncbi.nlm.nih.gov/books/NBK279054/',
  reviewedOn: _reviewed,
);

final _bullCycles = MedicalSource(
  organization: 'npj Digital Medicine',
  title: 'Real-world menstrual cycle characteristics of more than 600,000 menstrual cycles',
  url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC6710244/',
  reviewedOn: _reviewed,
);

final _fehringPhases = MedicalSource(
  organization: 'Journal of Obstetric, Gynecologic & Neonatal Nursing',
  title: 'Variability in the phases of the menstrual cycle',
  url: 'https://pubmed.ncbi.nlm.nih.gov/16700687/',
  reviewedOn: _reviewed,
);

final _mucusPatterns = MedicalSource(
  organization: 'Human Reproduction',
  title: 'Cervical mucus patterns and the fertile window in women without known subfertility',
  url: 'https://pubmed.ncbi.nlm.nih.gov/33990841/',
  reviewedOn: _reviewed,
);

final _appCohort = MedicalSource(
  organization: 'Fertility and Sterility',
  title: 'Findings from a mobile application-based cohort are consistent with established knowledge of the menstrual cycle',
  url: 'https://pubmed.ncbi.nlm.nih.gov/31272722/',
  reviewedOn: _reviewed,
);

final _moodProspective = MedicalSource(
  organization: 'Psychotherapy and Psychosomatics',
  title: 'Mood and the menstrual cycle',
  url: 'https://pubmed.ncbi.nlm.nih.gov/23147261/',
  reviewedOn: _reviewed,
);

final _moodHormoneVerified = MedicalSource(
  organization: 'Journal of Psychosomatic Obstetrics & Gynecology',
  title: 'Associations between menstrual cycle phases and sexuality, well-being and mood in young healthy women',
  url: 'https://pubmed.ncbi.nlm.nih.gov/40976232/',
  reviewedOn: _reviewed,
);

final _normalSymptoms = MedicalSource(
  organization: 'Psychoneuroendocrinology',
  title: 'Mood changes and physical complaints during the normal menstrual cycle in healthy young women',
  url: 'https://pubmed.ncbi.nlm.nih.gov/2359810/',
  reviewedOn: _reviewed,
);

final _pmsProspective = MedicalSource(
  organization: "Journal of Women's Health",
  title: 'Core symptoms that discriminate premenstrual syndrome',
  url: 'https://pubmed.ncbi.nlm.nih.gov/21128818/',
  reviewedOn: _reviewed,
);

final _prostaglandins = MedicalSource(
  organization: 'American Journal of Obstetrics and Gynecology',
  title: 'Relief of dysmenorrhea with ibuprofen: effect on prostaglandin levels in menstrual fluid',
  url: 'https://pubmed.ncbi.nlm.nih.gov/474640/',
  reviewedOn: _reviewed,
);

final cycleCompanionTips = <HealthTip>[
  HealthTip(
    id: 'cycle-now-period-start',
    category: TipCategory.cycle,
    title: 'The first days can carry the most physical noise',
    flash:
        'Cramps, heaviness, headache, tiredness or bowel changes can cluster around the start of bleeding.',
    details: [
      'Estrogen and progesterone are low around menstruation, while prostaglandins help the uterus contract and shed its lining. Higher prostaglandin activity is one reason cramps and some digestive changes can travel together.',
      'Symptoms often peak around the day before or the first days of bleeding, but the pattern and intensity vary widely between people and between cycles.',
    ],
    practical: [
      'Repeated daily observations are more useful than assuming every period will feel the same.',
    ],
    seekCare: [
      'Pain that is severe, progressively worsening, or regularly disrupts normal activity deserves medical assessment.',
    ],
    tags: ['cycle context', 'menstruation', 'cramps', 'bowel changes', 'prostaglandins'],
    experiences: ['Cramps', 'Lower energy', 'Headache', 'Bowel changes'],
    sources: [_endotextCycle, _prostaglandins, _owhCycle],
    version: 3,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-now-early',
    category: TipCategory.cycle,
    title: 'Early follicular days',
    flash:
        'Bleeding may be settling while ovarian follicles continue developing and estrogen begins to rise again.',
    details: [
      'The follicular phase starts on the first day of a period and is the most variable part of the cycle. Its length changes much more than a textbook calendar suggests.',
      'There is no reliable evidence that everyone should feel more focused, social or energetic here. Your own repeated pattern is more informative than a phase stereotype.',
    ],
    practical: ['Notice what actually changes for you as bleeding and period symptoms settle.'],
    tags: ['cycle context', 'follicular phase', 'estrogen', 'cycle variability'],
    experiences: ['Symptoms may settle', 'Energy may feel steadier', 'Discharge may change'],
    sources: [_bullCycles, _fehringPhases, _moodHormoneVerified, _endotextCycle],
    version: 3,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-now-middle',
    category: TipCategory.cycle,
    title: 'Around the peri-ovulatory part of the cycle',
    flash:
        'Clearer, wetter or stretchier cervical fluid can appear as estrogen rises before ovulation.',
    details: [
      'Estrogen supports more abundant, slippery cervical mucus before ovulation. Some people also report pelvic twinges, breast tenderness, cramps or appetite changes around this part of the cycle.',
      'Calendar timing alone cannot confirm whether or when ovulation happened. A broad estimated window is more honest, while a mucus log can add context without proving a date.',
    ],
    practical: ['Treat the phase label as context rather than a precise biological measurement.'],
    tags: ['cycle context', 'peri-ovulatory', 'cervical mucus', 'estrogen', 'discharge'],
    experiences: ['Wetter discharge', 'Stretchier mucus', 'Pelvic twinges', 'Appetite change'],
    sources: [_mucusPatterns, _appCohort, _bullCycles, _endotextCycle],
    version: 3,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-now-before-period',
    category: TipCategory.cycle,
    title: 'Late luteal days can be more noticeable for some people',
    flash:
        'Bloating, breast tenderness, headache, appetite or sleep changes, and mood symptoms can rise before a period.',
    details: [
      'Premenstrual symptoms are linked to sensitivity to normal ovarian-hormone changes rather than one universally abnormal hormone level. Physical symptoms are often more consistently phase-linked than global mood in healthy populations.',
      'Not everyone gets PMS, and even when a symptom is common it is more useful to compare it with your own daily pattern across cycles.',
    ],
    practical: ['Repeated daily logs can show whether a symptom is truly late-cycle for you.'],
    seekCare: ['If premenstrual symptoms repeatedly interfere with daily life, discuss them with a clinician.'],
    tags: ['cycle context', 'luteal phase', 'PMS', 'bloating', 'sleep', 'appetite', 'mood'],
    experiences: ['Bloating', 'Breast tenderness', 'Cravings', 'Sleep changes', 'Mood changes'],
    sources: [_pmsProspective, _normalSymptoms, _moodProspective, _owhPms],
    version: 3,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-phase-menstruation',
    category: TipCategory.cycle,
    title: 'Menstruation · early follicular phase',
    flash:
        'The uterine lining is being shed while ovarian hormone levels are near their cycle low and a new follicular phase is already beginning.',
    details: [
      'Menstruation is a bleeding event and overlaps biologically with the early follicular phase. Calling it a separate “phase” is useful for everyday tracking, but the ovarian cycle is already moving forward.',
      'Flow, pain and energy can differ from day to day, so your actual pattern matters more than a phase stereotype.',
    ],
    tags: ['cycle context', 'phase', 'menstruation', 'follicular phase'],
    experiences: ['Bleeding', 'Cramps', 'Fatigue', 'Digestive changes'],
    sources: [_endotextCycle, _owhCycle, _prostaglandins],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-phase-follicular',
    category: TipCategory.cycle,
    title: 'Follicular phase · the variable half',
    flash:
        'Follicles are developing and estrogen generally rises, but the timing of this phase is highly individual.',
    details: [
      'Most cycle-length variation comes from the follicular phase and the timing of ovulation. Longer cycles usually do not mean every phase simply stretched equally.',
      'Many people have few distinctive symptoms here. That absence of a dramatic “phase feeling” is normal too.',
    ],
    tags: ['cycle context', 'phase', 'follicular phase', 'estrogen', 'cycle variability'],
    experiences: ['Often fewer period symptoms', 'Changing discharge', 'No special feeling at all'],
    sources: [_bullCycles, _fehringPhases, _endotextCycle],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-phase-periovulatory',
    category: TipCategory.cycle,
    title: 'Around the peri-ovulatory window',
    flash:
        'Recent cycle timing places you around the ovulatory part of this cycle; the window is intentionally broad.',
    details: [
      'Ovulation timing moves from cycle to cycle. Estimating backward from the next expected period can give useful broad context because the luteal phase is usually less variable than the follicular phase.',
      'Watery or stretchy cervical fluid can make this timing more biologically plausible, but it cannot prove an exact ovulation day.',
    ],
    tags: ['cycle context', 'phase', 'peri-ovulatory', 'cervical mucus', 'uncertainty'],
    experiences: ['Wetter mucus', 'Stretchier discharge', 'Possible pelvic twinges', 'No obvious change'],
    sources: [_bullCycles, _fehringPhases, _mucusPatterns, _appCohort],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-phase-luteal',
    category: TipCategory.cycle,
    title: 'The luteal phase',
    flash:
        'After ovulation, progesterone normally rises and the uterine lining is maintained while the cycle moves toward its next period.',
    details: [
      'The luteal phase varies less than the follicular phase on average, but it is not a fixed 14 days. Without current-cycle hormone or temperature markers, its timing remains an estimate rather than a measurement.',
      'Some people notice breast tenderness, bloating or appetite changes later in this phase; others notice very little until bleeding starts.',
    ],
    tags: ['cycle context', 'phase', 'luteal phase', 'progesterone', 'cycle variability'],
    experiences: ['Breast tenderness', 'Bloating', 'Appetite changes', 'No obvious change'],
    sources: [_bullCycles, _fehringPhases, _normalSymptoms, _endotextCycle],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-phase-uncertain',
    category: TipCategory.cycle,
    title: 'Some cycle days are harder to place',
    flash:
        'Cycle timing can shift enough that some days do not fit a phase label confidently.',
    details: [
      'Cycle and ovulation timing can move meaningfully even within the same person. When history is sparse or an expected period has passed, the current phase becomes less certain.',
      'The next recorded period and daily observations add useful context without changing what was already logged.',
    ],
    tags: ['cycle context', 'phase', 'uncertainty', 'cycle variability'],
    experiences: ['Your own logs matter most'],
    sources: [_bullCycles, _fehringPhases],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-body-prostaglandins',
    category: TipCategory.body,
    title: 'Why cramps and bowel changes can arrive together',
    flash:
        'Prostaglandins that help the uterus contract can also be part of the wider physical picture around menstruation.',
    details: [
      'Menstrual-fluid prostaglandin levels have been linked with primary dysmenorrhea, and reducing prostaglandin synthesis reduces pain in controlled studies.',
      'Nausea, loose stools and back or abdominal discomfort can cluster with painful periods, but persistent or severe symptoms should not automatically be blamed on the cycle.',
    ],
    tags: ['cycle context', 'cramps', 'digestion', 'prostaglandins', 'menstruation'],
    experiences: ['Cramps', 'Loose stools', 'Nausea', 'Back pain'],
    sources: [_prostaglandins, _owhCycle],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-body-mucus',
    category: TipCategory.body,
    title: 'Cervical fluid is a real biological signal—but still a noisy one',
    flash:
        'Estrogenic mucus commonly becomes wetter, clearer or stretchier before ovulation and decreases after progesterone rises.',
    details: [
      'Prospective cohorts show several days of estrogenic-quality mucus are common, so one watery day is not a timestamp for ovulation.',
      'Repeated watery or stretchy observations can strengthen peri-ovulatory context without turning a single day into an exact ovulation claim.',
    ],
    tags: ['cycle context', 'cervical mucus', 'discharge', 'estrogen', 'peri-ovulatory'],
    experiences: ['Watery discharge', 'Stretchy mucus', 'More noticeable fluid'],
    sources: [_mucusPatterns, _appCohort],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-body-mood-is-personal',
    category: TipCategory.understanding,
    title: 'A phase does not prescribe your mood',
    flash:
        'Large prospective and hormone-verified studies do not support a universal emotional script for every menstrual phase.',
    details: [
      'Mood can be affected by sleep, stress, health, relationships and many other factors alongside ovarian hormone sensitivity.',
      'If your mood does repeat around the same cycle window, prospective daily logs are the right way to discover that personal pattern.',
    ],
    tags: ['cycle context', 'mood', 'personal patterns', 'hormones'],
    experiences: ['Your mood may not change', 'Personal patterns can still be real'],
    sources: [_moodProspective, _moodHormoneVerified, _pmsProspective],
    version: 2,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-body-appetite',
    category: TipCategory.body,
    title: 'Appetite can move, but not on one universal schedule',
    flash:
        'Some prospective studies find appetite changes around peri-ovulatory or premenstrual days, while individual patterns differ.',
    details: [
      'A higher appetite or cravings can appear late in the cycle for some people, but one day is not enough to call it hormone-driven.',
      'Repeated logs are what distinguish a personal recurring pattern from a generic phase assumption.',
    ],
    tags: ['cycle context', 'appetite', 'cravings', 'personal patterns'],
    experiences: ['Higher appetite', 'Cravings', 'No change'],
    sources: [_normalSymptoms, _pmsProspective],
    version: 2,
    lastReviewed: _reviewed,
  ),
];