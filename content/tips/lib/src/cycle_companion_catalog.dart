import 'models.dart';

final _reviewed = DateTime.utc(2026, 8, 13);

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

final _owhPeriodProblems = MedicalSource(
  organization: "U.S. Office on Women's Health",
  title: 'Period problems',
  url: 'https://womenshealth.gov/menstrual-cycle/period-problems',
  reviewedOn: _reviewed,
);

final _endotextCycle = MedicalSource(
  organization: 'National Library of Medicine / Endotext',
  title: 'The Normal Menstrual Cycle and the Control of Ovulation',
  url: 'https://www.ncbi.nlm.nih.gov/books/NBK279054/',
  reviewedOn: _reviewed,
);

final _nhsDischarge = MedicalSource(
  organization: 'NHS',
  title: 'Vaginal discharge',
  url: 'https://www.nhs.uk/symptoms/vaginal-discharge/',
  reviewedOn: _reviewed,
);

final cycleCompanionTips = <HealthTip>[
  HealthTip(
    id: 'cycle-now-period-start',
    category: TipCategory.cycle,
    title: 'Why the first days can feel different',
    flash:
        'Cramps, heaviness, headache, tiredness or bowel changes can cluster around the start of a period.',
    details: [
      'As estrogen and progesterone fall, the uterine lining breaks down and is shed. Prostaglandins help the uterus contract, which is one reason cramps can happen.',
      'The same point in the cycle does not feel identical for everyone or every month. What you actually notice matters more than a generic checklist.',
    ],
    practical: [
      'If you log symptoms during these first days, Nyla can compare them across later cycles instead of assuming they always happen.',
    ],
    seekCare: [
      'Pain that is severe, keeps getting worse, or interferes with work, school or normal activities deserves medical attention.',
    ],
    tags: [
      'cycle context',
      'period start',
      'cramps',
      'headache',
      'tiredness',
      'bowel changes',
      'hormones',
    ],
    sources: [_owhCycle, _owhPeriodProblems, _endotextCycle],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-now-early',
    category: TipCategory.cycle,
    title: 'The early cycle is a transition, not a switch',
    flash:
        'Bleeding and period symptoms may be settling while hormone levels begin changing again.',
    details: [
      'The first part of the cycle begins on day one of a period. After the low hormone levels around menstruation, estrogen generally rises through the follicular phase.',
      'That biology does not guarantee a particular mood, energy level or symptom. Your own repeated logs are more useful than phase stereotypes.',
    ],
    practical: [
      'Notice what is true for you without trying to match a prescribed “phase personality.”',
    ],
    tags: [
      'cycle context',
      'early cycle',
      'estrogen',
      'hormones',
      'period symptoms',
    ],
    sources: [_owhCycle, _endotextCycle],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-now-middle',
    category: TipCategory.cycle,
    title: 'Why discharge can change around the middle',
    flash:
        'Some people notice clearer, wetter or more slippery discharge around the middle of a cycle.',
    details: [
      'Rising estrogen changes cervical mucus. Later in the first part of a cycle it can become clearer, more abundant and more elastic.',
      'Bodies do not follow a fixed calendar, and this timing alone cannot confirm whether or when ovulation happened. Nyla uses it only as gentle cycle context.',
    ],
    practical: [
      'Log discharge only if it is useful to you. A repeated personal pattern is more informative than one isolated day.',
    ],
    seekCare: [
      'Discharge that is unusual for you and comes with a strong smell, itching, soreness, pain when peeing or pelvic pain should be assessed.',
    ],
    tags: [
      'cycle context',
      'middle cycle',
      'discharge',
      'cervical mucus',
      'estrogen',
      'hormones',
    ],
    sources: [_owhCycle, _endotextCycle, _nhsDischarge],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-now-before-period',
    category: TipCategory.cycle,
    title: 'Why the days before a period can feel different',
    flash:
        'Bloating, breast tenderness, headache, tiredness, sleep or appetite changes, and mood shifts can happen before a period.',
    details: [
      'Premenstrual symptoms can appear in the week or two before menstruation. Changing estrogen and progesterone levels are thought to play a role, but researchers do not have one single explanation.',
      'Not everyone gets PMS, and the same person can have different symptoms from one cycle to the next.',
    ],
    practical: [
      'Logging what you actually feel over several cycles lets Nyla compare your own pattern instead of assuming.',
    ],
    seekCare: [
      'If premenstrual symptoms are severe enough to disrupt everyday life, talk with a clinician.',
    ],
    tags: [
      'cycle context',
      'before period',
      'PMS',
      'bloating',
      'breast tenderness',
      'headache',
      'sleep',
      'appetite',
      'mood',
      'hormones',
    ],
    sources: [_owhPms, _owhCycle],
    version: 1,
    lastReviewed: _reviewed,
  ),
];
