import 'catalog.dart';
import 'models.dart';

final _reviewed = DateTime.utc(2026, 9, 2);

final _nhsPelvicPain = MedicalSource(
  organization: 'NHS',
  title: 'Pelvic pain',
  url: 'https://www.nhs.uk/symptoms/pelvic-pain/',
  reviewedOn: _reviewed,
);

final _nhsBloating = MedicalSource(
  organization: 'NHS',
  title: 'Bloating',
  url: 'https://www.nhs.uk/symptoms/bloating/',
  reviewedOn: _reviewed,
);

final everydayCareTips = <HealthTip>[
  HealthTip(
    id: 'everyday-cramps-can-travel',
    category: TipCategory.symptoms,
    title: 'Cramps can spread beyond your lower tummy',
    flash:
        'Period cramps can be felt in the lower abdomen and may spread into the lower back or thighs.',
    details: [
      'The uterus contracts during menstruation, and period pain does not always stay in one small spot.',
      'A familiar ache that spreads into the back or thighs can still fit ordinary period pain. A new, severe or rapidly worsening pain pattern deserves medical attention.',
    ],
    practical: [
      'Warmth on the lower abdomen or back, massage, or gentle movement can feel soothing for some people.',
    ],
    seekCare: [
      'Pain is severe, much worse than usual, or stops you doing your normal activities.',
    ],
    tags: ['cramps', 'back pain', 'thigh pain', 'period pain'],
    sources: [nhsPain, acogPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-period-clots-context',
    category: TipCategory.body,
    title: 'Clots need context, not instant panic',
    flash:
        'Passing some clotted blood can happen during a period; repeated large clots can be one sign that bleeding is heavy.',
    details: [
      'Blood can clot before it leaves the body, especially when flow is heavier. A clot by itself does not explain whether a period is healthy or unhealthy.',
      'The bigger picture matters: how large the clots are, how often they happen, how quickly products are soaked, how long bleeding lasts and how you feel.',
    ],
    seekCare: [
      'You repeatedly pass clots larger than about 2.5 cm along with other signs of heavy bleeding.',
      'Heavy bleeding is affecting daily life or comes with faintness, marked dizziness, severe pain or breathlessness.',
    ],
    tags: ['clots', 'blood clots', 'heavy flow', 'bleeding'],
    sources: [nhsHeavy],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-cycle-day-one',
    category: TipCategory.cycle,
    title: 'Cycle day 1 starts with your period',
    flash:
        'The first day of menstrual bleeding is counted as day 1 of a new menstrual cycle.',
    details: [
      'Cycle-day counting runs from the first day of one period to the day before the next period begins.',
      'That simple anchor is useful even when the rest of the cycle varies, because ovulation and total cycle length do not follow one fixed calendar for everyone.',
    ],
    tags: ['cycle day', 'day 1', 'period start', 'cycle basics'],
    sources: [nhsPeriods],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-period-duration-pattern',
    category: TipCategory.understanding,
    title: 'How long you bleed is a pattern worth knowing',
    flash:
        'Periods often last around 2 to 7 days, but your own usual duration and changes from it are useful context.',
    details: [
      'One period can be a little shorter or longer than another. Looking across several cycles gives a clearer picture than judging one month by itself.',
      'Bleeding that repeatedly lasts more than 7 days can be one sign of heavy periods, especially when it also means frequent product changes or affects daily life.',
    ],
    tags: ['period length', 'duration', 'bleeding days', 'pattern'],
    sources: [nhsPeriods, nhsHeavy],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-bloating-persistent',
    category: TipCategory.seekCare,
    title: 'Period bloating should still have boundaries',
    flash:
        'Bloating can happen around a period, but frequent or persistent bloating deserves its own attention.',
    details: [
      'A temporary full or uncomfortable feeling around menstruation can be common. Bloating that keeps returning outside that pattern, does not settle, or comes with other concerning symptoms should not automatically be blamed on the cycle.',
    ],
    seekCare: [
      'Bloating is frequent or does not go away.',
      'It comes with unintentional weight loss, blood in stool, a persistent change in bowel habits or significant pain.',
    ],
    tags: ['bloating', 'persistent bloating', 'digestion', 'pelvic symptoms'],
    sources: [_nhsBloating, _nhsPelvicPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-moisture-irritation',
    category: TipCategory.care,
    title: 'A damp period product can irritate skin',
    flash:
        'Pads or period underwear left on too long can trap moisture and contribute to irritation, rash or infection.',
    details: [
      'Regular product changes are about comfort as well as cleanliness. Moisture and heat held against the skin for a long time can make irritation more likely.',
      'Lightweight, breathable clothing can also help reduce trapped heat and moisture during a period.',
    ],
    practical: [
      'Change pads regularly even on lighter-flow days, and follow the washing and changing instructions for reusable products.',
      'If your skin is easily irritated, unscented products and breathable underwear may feel more comfortable.',
    ],
    tags: ['rash', 'irritation', 'pads', 'period underwear', 'moisture'],
    sources: [cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-tampon-pain-stop',
    category: TipCategory.products,
    title: 'A tampon should not be something you force through pain',
    flash:
        'Unexpected pain, discomfort or unusual discharge while inserting or wearing a tampon is a reason to stop and check what is going on.',
    details: [
      'FDA guidance says to stop using a menstrual product and contact a healthcare professional if it causes pain, fever or other unusual symptoms.',
      'For tampons, use the lowest absorbency that meets your flow needs and follow the product instructions rather than forcing a fit that hurts.',
    ],
    seekCare: [
      'Pain, fever, unusual discharge or another unexpected symptom appears with tampon use.',
    ],
    tags: ['tampon', 'pain', 'discomfort', 'product safety'],
    sources: [fdaProducts, fdaTampons],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-pelvic-pain-between-periods',
    category: TipCategory.seekCare,
    title: 'Pelvic pain does not have to belong to a period',
    flash:
        'Pelvic pain that keeps returning, persists between periods or comes with unusual bleeding or discharge deserves its own assessment.',
    details: [
      'A menstrual cycle can explain some timing patterns, but it should not become a catch-all explanation for persistent pelvic symptoms.',
      'Where the pain happens, how long it lasts, what makes it worse, and whether bowel, bladder, discharge or bleeding symptoms occur with it are all useful details.',
    ],
    seekCare: [
      'Pain keeps returning or does not go away.',
      'Pain comes with unusual bleeding, unusual discharge, difficulty urinating or passing stool, fever, faintness or marked dizziness.',
    ],
    tags: ['pelvic pain', 'between periods', 'discharge', 'bleeding', 'seek care'],
    sources: [_nhsPelvicPain, nhsPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
];
