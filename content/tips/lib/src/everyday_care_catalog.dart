import 'catalog.dart';
import 'models.dart';

final _reviewed = DateTime.utc(2026, 9, 2);

final _nhsPelvicPain = MedicalSource(
  organization: 'NHS',
  title: 'Pelvic pain',
  url: 'https://www.nhs.uk/symptoms/pelvic-pain/',
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
    id: 'everyday-pain-pattern-changed',
    category: TipCategory.seekCare,
    title: 'A change in period pain is useful information',
    flash:
        'Pain becoming much stronger, lasting differently or interfering with everyday life is worth taking seriously.',
    details: [
      'Period pain is common, but a noticeable change from your usual pattern can be a reason to talk with a clinician.',
      'Pain with urination, bowel movements, sex, bleeding between periods, or increasingly heavy or irregular periods adds useful context for a medical assessment.',
    ],
    practical: [
      'Keep a short record of when the pain happens, how strong it feels, what else happens with it, and whether usual comfort measures help.',
    ],
    seekCare: [
      'Pain is severe or worse than usual and usual pain relief has not helped.',
      'Pain repeatedly prevents normal daily activities.',
    ],
    tags: ['period pain', 'worsening pain', 'pelvic pain', 'doctor'],
    sources: [nhsPain, acogPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-pms-whole-body',
    category: TipCategory.body,
    title: 'PMS can show up in more than mood',
    flash:
        'Sleep, tiredness, bloating, cramps, breast tenderness, headaches and appetite can all be part of a premenstrual pattern.',
    details: [
      'PMS varies a lot between people and can also vary from month to month. Emotional symptoms are only one part of the picture.',
      'A recurring personal pattern matters more than expecting a fixed list of symptoms every cycle.',
    ],
    practical: [
      'If something repeats before several periods, logging it prospectively can make the pattern much easier to see.',
    ],
    tags: ['pms', 'sleep', 'bloating', 'headache', 'appetite', 'breast tenderness'],
    sources: [nhsPms, nhsPeriodProblems],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-pms-two-cycle-diary',
    category: TipCategory.understanding,
    title: 'Two cycles can tell you more than one rough week',
    flash:
        'A symptom diary across at least two menstrual cycles can help show whether a premenstrual pattern actually repeats.',
    details: [
      'Memory tends to compress difficult days together. Daily notes make it easier to see whether symptoms reliably appear before a period and then ease afterwards.',
      'That pattern can also give a clinician more useful information if symptoms are affecting daily life.',
    ],
    practical: [
      'Log the symptom when it happens rather than trying to reconstruct the whole month later.',
    ],
    tags: ['pms', 'tracking', 'symptom diary', 'patterns'],
    sources: [nhsPms],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-menstrual-migraine-timing',
    category: TipCategory.symptoms,
    title: 'Some migraines cluster around a period',
    flash:
        'Menstrual migraine often appears around the couple of days before a period or during its first few days.',
    details: [
      'Hormone changes around menstruation can be linked with migraine in some people. That does not mean every period-related headache is a migraine.',
      'Timing, severity, associated symptoms and whether the pattern repeats can help distinguish a recurring menstrual pattern from an occasional headache.',
    ],
    practical: [
      'If headaches repeat around periods, logging their timing and severity can make the pattern easier to discuss with a clinician.',
    ],
    seekCare: [
      'A headache is sudden and extremely severe, has new neurological symptoms, or is very different from your usual headaches.',
    ],
    tags: ['migraine', 'headache', 'period headache', 'menstrual migraine'],
    sources: [nhsMigraine, nhsPeriodProblems],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-heavy-flow-iron',
    category: TipCategory.symptoms,
    title: 'Heavy periods can gradually drain iron',
    flash:
        'Repeated heavy menstrual bleeding can contribute to iron-deficiency anaemia over time.',
    details: [
      'Iron helps red blood cells carry oxygen. Losing more blood than usual over repeated periods can reduce iron stores.',
      'Tiredness, weakness, dizziness, shortness of breath or looking paler than usual can have many causes, but they are worth mentioning if heavy periods are also part of the picture.',
    ],
    practical: [
      'If heavy periods and persistent tiredness occur together, bring both parts of the pattern to a clinician rather than treating them as unrelated.',
    ],
    tags: ['heavy period', 'iron', 'anaemia', 'tiredness', 'dizziness'],
    sources: [acogHeavy, nhsHeavy, owhIronDeficiency],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-heavy-flow-faint',
    category: TipCategory.seekCare,
    title: 'Heavy bleeding plus faintness deserves attention',
    flash:
        'Very heavy bleeding together with faintness, marked dizziness or feeling very unwell should not be brushed off as an ordinary period day.',
    details: [
      'Heavy flow can be disruptive even when you otherwise feel well. Feeling faint or significantly unwell adds a different level of concern.',
    ],
    seekCare: [
      'Bleeding feels unusually heavy and you feel faint, very dizzy or weak.',
      'Pelvic pain is severe or rapidly worsening alongside heavy bleeding.',
    ],
    tags: ['heavy bleeding', 'faint', 'dizziness', 'urgent care'],
    sources: [acogHeavy, nhsHeavy, _nhsPelvicPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-discharge-can-change',
    category: TipCategory.body,
    title: 'Discharge is allowed to change',
    flash:
        'Amount and texture of vaginal discharge can change through the menstrual cycle without meaning something is wrong.',
    details: [
      'Normal discharge helps keep the vagina moist and protected. It can become wetter, clearer or stretchier at some points in a cycle and drier or creamier at others.',
      'What matters most is the combination of appearance, smell, irritation, pain and whether the change is unusual for you.',
    ],
    tags: ['discharge', 'vaginal discharge', 'texture', 'cycle changes'],
    sources: [nhsDischarge],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-discharge-warning-signs',
    category: TipCategory.seekCare,
    title: 'Discharge symptoms matter more than colour alone',
    flash:
        'A new discharge change with a strong smell, itching, soreness, pelvic pain or bleeding can deserve medical advice.',
    details: [
      'Discharge naturally varies, so one colour or texture by itself is not a diagnosis.',
      'A change that is clearly unusual for you becomes more meaningful when it comes with irritation, pain, bleeding or a strong unpleasant smell.',
    ],
    seekCare: [
      'There is pelvic pain, bleeding, significant irritation or a strong unusual smell.',
      'The change persists or keeps returning and you are concerned about it.',
    ],
    tags: ['discharge', 'itching', 'smell', 'pelvic pain', 'infection'],
    sources: [nhsDischarge, acogVulva],
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
    sources: [_nhsPelvicPain],
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
      'The FDA advises stopping tampon use and contacting a health care provider if insertion or wear causes unexpected pain, discomfort, unusual discharge or an allergic reaction.',
    ],
    practical: [
      'Use the lowest absorbency that meets your flow needs and follow the product instructions.',
    ],
    seekCare: [
      'Pain, fever, unusual discharge or another unexpected symptom appears with tampon use.',
    ],
    tags: ['tampon', 'pain', 'discomfort', 'product safety'],
    sources: [fdaTampons],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-tampon-clean-hands',
    category: TipCategory.care,
    title: 'Clean hands are part of tampon care',
    flash:
        'Washing your hands before and after inserting or removing a tampon helps reduce the spread of bacteria.',
    details: [
      'It is a small step, but it is part of the FDA safety advice for tampon use.',
      'Tampons are single-use products and should be changed according to their instructions rather than left in longer for convenience.',
    ],
    tags: ['tampon', 'hands', 'hygiene', 'product safety'],
    sources: [fdaTampons, cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-product-choice-personal',
    category: TipCategory.products,
    title: 'The best period product is the one that works for your day',
    flash:
        'Pads, tampons, cups and other menstrual products solve different practical problems; there is no prize for choosing one type.',
    details: [
      'Comfort, flow, activity, access to changing or washing facilities, skin sensitivity and personal preference can all affect what works best.',
      'Safe use matters more than treating one product as universally better. Follow the instructions for the product you use and change or clean it as directed.',
    ],
    tags: ['products', 'pads', 'tampons', 'cup', 'comfort', 'choice'],
    sources: [fdaProducts, cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-endometriosis-clues',
    category: TipCategory.seekCare,
    title: 'Very painful periods are not a pain-tolerance contest',
    flash:
        'Period pain that repeatedly disrupts normal life or comes with other pelvic symptoms deserves assessment.',
    details: [
      'Conditions such as endometriosis can cause significant period or pelvic pain, but symptoms alone cannot diagnose the cause.',
      'Pain during sex, urination or bowel movements, bleeding between periods, or pain that is becoming worse can be useful details to mention to a clinician.',
    ],
    practical: [
      'A simple record of timing, severity and what the pain stops you doing can make an appointment more informative.',
    ],
    seekCare: [
      'Pain repeatedly interferes with school, work, sleep or usual activities.',
      'Pelvic pain is severe, worsening or appears outside your usual period pattern.',
    ],
    tags: ['endometriosis', 'severe cramps', 'pelvic pain', 'painful periods'],
    sources: [acogEndometriosis, nhsPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'everyday-pcos-patterns',
    category: TipCategory.understanding,
    title: 'Irregular periods can be one part of PCOS, not the whole diagnosis',
    flash:
        'PCOS can involve irregular or infrequent periods alongside signs such as acne or increased facial or body hair.',
    details: [
      'There is no single symptom that proves PCOS. A clinician considers the wider pattern and may use medical history, examination or tests when appropriate.',
      'One unusual cycle is different from a persistent pattern, so repeated tracking can be useful context without turning the app into a diagnostic tool.',
    ],
    tags: ['pcos', 'irregular periods', 'acne', 'body hair', 'cycle pattern'],
    sources: [whoPcos],
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
