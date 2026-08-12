import 'models.dart';

final _reviewed = DateTime.utc(2026, 8, 12);

final whoMenstrualHealth = MedicalSource(
  organization: 'World Health Organization',
  title: 'Menstrual health',
  url: 'https://www.who.int/vietnam/news/fact-sheets/detail/menstrual-health',
  reviewedOn: _reviewed,
);
final cdcHygiene = MedicalSource(
  organization: 'U.S. Centers for Disease Control and Prevention',
  title: 'Healthy Habits: Menstrual Hygiene',
  url: 'https://www.cdc.gov/hygiene/about/menstrual-hygiene.html',
  reviewedOn: _reviewed,
);
final fdaProducts = MedicalSource(
  organization: 'U.S. Food and Drug Administration',
  title: 'Menstrual Product Options, Facts, and Safe Use',
  url: 'https://www.fda.gov/medical-devices/products-and-medical-procedures/menstrual-product-options-facts-and-safe-use',
  reviewedOn: _reviewed,
);
final fdaTampons = MedicalSource(
  organization: 'U.S. Food and Drug Administration',
  title: 'The Facts on Tampons—and How to Use Them Safely',
  url: 'https://www.fda.gov/consumers/consumer-updates/facts-tampons-and-how-use-them-safely',
  reviewedOn: _reviewed,
);
final nhsPeriods = MedicalSource(
  organization: 'NHS',
  title: 'Periods',
  url: 'https://www.nhs.uk/conditions/periods/',
  reviewedOn: _reviewed,
);
final nhsPain = MedicalSource(
  organization: 'NHS',
  title: 'Period pain',
  url: 'https://www.nhs.uk/symptoms/period-pain/',
  reviewedOn: _reviewed,
);
final nhsPms = MedicalSource(
  organization: 'NHS',
  title: 'PMS (premenstrual syndrome)',
  url: 'https://www.nhs.uk/conditions/pre-menstrual-syndrome/',
  reviewedOn: _reviewed,
);
final nhsPeriodProblems = MedicalSource(
  organization: 'NHS',
  title: 'Period problems',
  url: 'https://www.nhs.uk/conditions/periods/period-problems/',
  reviewedOn: _reviewed,
);
final nhsMigraine = MedicalSource(
  organization: 'NHS',
  title: 'Migraine',
  url: 'https://www.nhs.uk/conditions/migraine/',
  reviewedOn: _reviewed,
);
final owhIronDeficiency = MedicalSource(
  organization: "U.S. Office on Women's Health",
  title: 'Iron-deficiency anemia',
  url: 'https://womenshealth.gov/a-z-topics/iron-deficiency-anemia',
  reviewedOn: _reviewed,
);
final nhsDischarge = MedicalSource(
  organization: 'NHS',
  title: 'Vaginal discharge',
  url: 'https://www.nhs.uk/symptoms/vaginal-discharge/',
  reviewedOn: _reviewed,
);
final nhsHeavy = MedicalSource(
  organization: 'NHS',
  title: 'Heavy periods',
  url: 'https://www.nhs.uk/conditions/heavy-periods/',
  reviewedOn: _reviewed,
);
final acogPain = MedicalSource(
  organization: 'American College of Obstetricians and Gynecologists',
  title: 'Painful Periods',
  url: 'https://www.acog.org/womens-health/faqs/painful-periods',
  reviewedOn: _reviewed,
);
final acogHeavy = MedicalSource(
  organization: 'American College of Obstetricians and Gynecologists',
  title: 'Heavy Menstrual Bleeding',
  url: 'https://www.acog.org/womens-health/faqs/heavy-menstrual-bleeding',
  reviewedOn: _reviewed,
);
final acogVulva = MedicalSource(
  organization: 'American College of Obstetricians and Gynecologists',
  title: 'Vulvovaginal Health',
  url: 'https://www.acog.org/womens-health/faqs/vulvovaginal-health',
  reviewedOn: _reviewed,
);
final acogEndometriosis = MedicalSource(
  organization: 'American College of Obstetricians and Gynecologists',
  title: 'Endometriosis',
  url: 'https://www.acog.org/womens-health/faqs/endometriosis',
  reviewedOn: _reviewed,
);
final whoPcos = MedicalSource(
  organization: 'World Health Organization',
  title: 'Polycystic ovary syndrome',
  url: 'https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome',
  reviewedOn: _reviewed,
);

final healthTips = <HealthTip>[
  HealthTip(
    id: 'period-is-shedding',
    category: TipCategory.cycle,
    title: 'What a period actually is',
    flash: 'A period is blood and tissue leaving as the lining of the uterus is shed.',
    details: [
      'Menstruation is a natural biological process and experiences vary from person to person.',
      'The bleeding is part of the menstrual cycle, not a cleansing or detox process.',
    ],
    tags: ['period', 'uterus', 'lining', 'basics'],
    sources: [whoMenstrualHealth, nhsPeriods],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cycle-not-stopwatch',
    category: TipCategory.cycle,
    title: 'A cycle is not a stopwatch',
    flash: 'Real cycles can vary. A prediction should be a range, not a promise.',
    details: [
      'A 28-day cycle is common shorthand, not a rule that every body follows.',
      'Tracking several cycles is more useful than judging one month in isolation because your own pattern and variation matter.',
    ],
    tags: ['cycle length', 'variation', 'prediction'],
    sources: [whoMenstrualHealth, nhsPeriods],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'flow-colour-can-change',
    category: TipCategory.cycle,
    title: 'Flow can change colour',
    flash: 'Period blood may look red on heavier days and pink or brown on lighter days.',
    details: [
      'Colour alone does not tell you how healthy a period is. The amount, duration, symptoms and changes from your usual pattern give more context.',
    ],
    tags: ['blood', 'brown', 'pink', 'flow'],
    sources: [nhsPeriods],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'track-for-patterns',
    category: TipCategory.cycle,
    title: 'Your history is useful evidence',
    flash: 'Dates, flow and symptoms can reveal patterns that memory easily blurs.',
    details: [
      'A menstrual record can help you notice changes in timing, bleeding or symptoms and can also give a clinician clearer information if you seek care.',
      'Nyla describes what you logged; it does not turn a pattern into a diagnosis.',
    ],
    tags: ['tracking', 'history', 'symptoms'],
    sources: [cdcHygiene, nhsHeavy],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'vulva-vagina-difference',
    category: TipCategory.body,
    title: 'Vulva and vagina are not the same thing',
    flash: 'The vulva is external. The vagina is the internal canal.',
    details: [
      'That distinction matters for care: routine cleaning is about the external skin, not washing inside the vagina.',
    ],
    tags: ['vulva', 'vagina', 'anatomy', 'cleaning'],
    sources: [acogVulva, cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'vagina-self-cleans',
    category: TipCategory.care,
    title: 'Your vagina cleans itself',
    flash: 'Routine washing belongs on the outside. The vagina does not need internal cleaning.',
    details: [
      'The vagina maintains its own environment. Douching or putting cleansing chemicals inside can disturb protective bacteria and cause irritation or other problems.',
    ],
    practical: [
      'Wash the vulva gently with water; if you use soap, keep it mild and fragrance-free and use it externally.',
      'Pat dry rather than scrubbing irritated skin.',
    ],
    tags: ['cleaning', 'douching', 'vagina', 'vulva'],
    sources: [cdcHygiene, acogVulva, nhsDischarge],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'skip-scented-hygiene',
    category: TipCategory.care,
    title: 'Fresh does not need fragrance',
    flash: 'Perfumed washes, sprays, wipes and scented menstrual products can irritate sensitive skin.',
    details: [
      'Odour-covering products do not make the vagina cleaner. Fragrance and deodorizing products can irritate the vulva or disturb the vaginal environment.',
    ],
    practical: ['Choose unscented products when possible, especially if your skin is easily irritated.'],
    tags: ['fragrance', 'scented', 'irritation', 'hygiene'],
    sources: [cdcHygiene, acogVulva, nhsDischarge],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'hands-before-after-products',
    category: TipCategory.care,
    title: 'Clean hands count too',
    flash: 'Wash your hands before and after changing a menstrual product.',
    details: [
      'Handwashing helps reduce transfer of germs while inserting, removing or changing period products.',
    ],
    tags: ['hands', 'hygiene', 'products'],
    sources: [cdcHygiene, fdaProducts, fdaTampons],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'dispose-dont-flush',
    category: TipCategory.care,
    title: 'Bin disposables, do not flush them',
    flash: 'Disposable pads and tampons belong in the trash, not the toilet.',
    details: [
      'Wrapping a used disposable product before placing it in a bin is a simple, hygienic way to dispose of it.',
    ],
    tags: ['disposal', 'pads', 'tampons'],
    sources: [cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'pads-change-regularly',
    category: TipCategory.products,
    title: 'Change pads regularly',
    flash: 'A pad should not stay on all day just because flow is light.',
    details: [
      'CDC guidance recommends changing sanitary pads every few hours, and more often when flow is heavy.',
      'Regular changes help with comfort and reduce prolonged moisture against the skin.',
    ],
    tags: ['pads', 'changing', 'flow'],
    sources: [cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'tampon-four-eight-hours',
    category: TipCategory.products,
    title: 'Tampons have a time limit',
    flash: 'Change a tampon every 4–8 hours and never leave one in for more than 8 hours.',
    details: [
      'Use tampons only during a period and follow the product instructions even if you have used tampons before.',
    ],
    practical: ['Choose the lowest absorbency that manages your flow.'],
    tags: ['tampon', 'hours', 'safety'],
    sources: [fdaTampons, cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'tampon-lowest-absorbency',
    category: TipCategory.products,
    title: 'More absorbent is not automatically better',
    flash: 'Use the lowest tampon absorbency that works for your flow.',
    details: [
      'FDA guidance notes that if one tampon can remain in place for the full eight hours without needing a change, its absorbency may be higher than you need.',
    ],
    tags: ['tampon', 'absorbency', 'safety'],
    sources: [fdaTampons],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'tss-rare-urgent',
    category: TipCategory.seekCare,
    title: 'Toxic shock syndrome is rare—but urgent',
    flash: 'Know the warning signs if you use tampons.',
    details: [
      'Toxic shock syndrome (TSS) is rare but can become life-threatening quickly.',
    ],
    seekCare: [
      'If sudden fever, vomiting or diarrhoea, dizziness or fainting, or a sunburn-like rash appears during or soon after a period while using a tampon, remove it and seek urgent medical care.',
    ],
    tags: ['tampon', 'TSS', 'fever', 'urgent'],
    sources: [fdaTampons],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'cups-follow-care-instructions',
    category: TipCategory.products,
    title: 'Reusable cups need regular cleaning',
    flash: 'Clean a menstrual cup during use and sanitize it between cycles as directed.',
    details: [
      'CDC guidance recommends cleaning cups daily during use and sanitizing them after the period. Product-specific instructions still matter because materials and designs differ.',
    ],
    tags: ['cup', 'cleaning', 'reusable'],
    sources: [cdcHygiene, fdaProducts],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'period-underwear-care',
    category: TipCategory.products,
    title: 'Period underwear is reusable, not maintenance-free',
    flash: 'Wash reusable period underwear according to its care instructions.',
    details: [
      'Different fabrics and products have different washing instructions. Following the manufacturer’s directions helps keep the garment clean and functional.',
    ],
    tags: ['period underwear', 'washing', 'reusable'],
    sources: [cdcHygiene],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'product-choice-personal',
    category: TipCategory.products,
    title: 'There is no single “best” period product',
    flash: 'Pads, tampons, cups and period underwear work differently; comfort and fit matter.',
    details: [
      'Some products absorb flow outside the body while others collect or absorb it internally. The safest choice is one you can use correctly and comfortably according to its instructions.',
    ],
    tags: ['products', 'pads', 'tampons', 'cups', 'underwear'],
    sources: [fdaProducts],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'tampon-metals-2026',
    category: TipCategory.products,
    title: 'What the current evidence says about metals in tampons',
    flash: 'FDA testing published in 2026 found released metal levels far below amounts considered harmful.',
    details: [
      'Trace metals can be detected in tampon materials, but detection is not the same as harmful exposure.',
      'FDA laboratory testing designed to simulate use found that the amounts released were too low to be expected to cause harm, while the agency continues menstrual-product safety work.',
    ],
    tags: ['tampon', 'metals', 'safety', 'evidence'],
    sources: [fdaProducts],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'why-cramps-happen',
    category: TipCategory.comfort,
    title: 'Why period cramps happen',
    flash: 'The uterus contracts during a period, and prostaglandins help drive those contractions.',
    details: [
      'Prostaglandins are natural chemicals made in the uterine lining. Higher levels around the start of bleeding can contribute to cramping.',
      'Pain can also have other causes, especially when it is severe, progressively worsening or different from your usual pattern.',
    ],
    tags: ['cramps', 'uterus', 'prostaglandins', 'pain'],
    sources: [acogPain, nhsPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'heat-for-cramps',
    category: TipCategory.comfort,
    title: 'Heat can be simple and useful',
    flash: 'A warm bath, heating pad or hot-water bottle may soothe period cramps.',
    details: [
      'Heat is included in clinical self-care guidance for menstrual pain and can be used on the lower abdomen or back for comfort.',
    ],
    tags: ['heat', 'cramps', 'comfort'],
    sources: [acogPain, nhsPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'movement-for-cramps',
    category: TipCategory.comfort,
    title: 'Gentle movement may help',
    flash: 'Walking, swimming, cycling or other comfortable exercise can help some people with period pain.',
    details: [
      'Exercise is part of self-care guidance for period pain. It does not need to be intense; choose movement that feels manageable for your body that day.',
    ],
    tags: ['exercise', 'movement', 'cramps'],
    sources: [acogPain, nhsPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'sleep-and-discomfort',
    category: TipCategory.comfort,
    title: 'Sleep deserves a place in period care',
    flash: 'Being well rested may make menstrual discomfort easier to cope with.',
    details: [
      'Clinical guidance includes adequate sleep among practical measures that can support people dealing with period pain and premenstrual symptoms.',
    ],
    tags: ['sleep', 'pain', 'PMS'],
    sources: [acogPain, nhsPms],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'pms-can-change',
    category: TipCategory.symptoms,
    title: 'PMS does not look identical every month',
    flash: 'Premenstrual symptoms can be physical, emotional or both—and can vary from cycle to cycle.',
    details: [
      'Commonly reported symptoms include mood changes, irritability or anxiety, tiredness or sleep changes, bloating or cramps, breast tenderness, headaches, skin changes and appetite or craving changes.',
      'The pattern matters more than forcing every symptom into a hormonal explanation.',
    ],
    tags: ['PMS', 'mood', 'bloating', 'headache', 'appetite'],
    sources: [nhsPms],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'normal-discharge',
    category: TipCategory.body,
    title: 'Discharge is part of a healthy vagina',
    flash: 'Clear or white discharge without a strong unpleasant smell is commonly normal.',
    details: [
      'The amount and texture can change over time. What is usual for you is useful context when deciding whether something has changed.',
    ],
    tags: ['discharge', 'vagina', 'body'],
    sources: [nhsDischarge, acogVulva],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'discharge-changes-care',
    category: TipCategory.seekCare,
    title: 'A clear change in discharge is worth noticing',
    flash: 'New colour, smell, texture, itching, soreness or pelvic pain can deserve medical assessment.',
    details: [
      'Discharge varies naturally, but a marked change from your usual pattern—especially with irritation or pain—can be a sign that something needs attention.',
    ],
    seekCare: [
      'Seek medical advice for a notable change in colour, smell or texture, new itching or soreness, pain when urinating, pelvic pain, or bleeding outside your expected period pattern.',
    ],
    tags: ['discharge', 'itching', 'odor', 'pelvic pain'],
    sources: [nhsDischarge],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'heavy-bleeding-signs',
    category: TipCategory.seekCare,
    title: 'Heavy bleeding is about impact, not toughness',
    flash: 'Repeatedly soaking products very quickly or bleeding for more than a week deserves attention.',
    details: [
      'Heavy menstrual bleeding can disrupt daily life and can contribute to iron-deficiency anaemia.',
      'Useful details to track include how often you change products, whether you need two products together, nighttime changes, duration and large clots.',
    ],
    seekCare: [
      'Talk with a healthcare professional if heavy bleeding is affecting your life, has persisted, or is accompanied by severe pain, dizziness, fainting or other concerning symptoms.',
    ],
    tags: ['heavy', 'bleeding', 'flow', 'anaemia'],
    sources: [acogHeavy, nhsHeavy, whoMenstrualHealth],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'pain-disrupting-life',
    category: TipCategory.seekCare,
    title: 'Pain that stops your day is not something to dismiss',
    flash: 'Severe, worsening or activity-stopping period pain is a reason to seek medical help.',
    details: [
      'Period pain is common, but intensity and impact matter. Some medical conditions can also cause painful periods.',
    ],
    seekCare: [
      'Seek medical assessment if pain is severe, worse than usual, progressively worsening, not helped by your usual measures, or repeatedly stops school, work, sleep or ordinary activities.',
    ],
    tags: ['pain', 'cramps', 'severe', 'doctor'],
    sources: [nhsPain, acogPain],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'endometriosis-awareness',
    category: TipCategory.symptoms,
    title: 'Severe period pain can have a cause',
    flash: 'Endometriosis is one condition associated with persistent pelvic pain and painful periods.',
    details: [
      'Endometriosis involves tissue similar to the uterine lining growing outside the uterus. Symptoms vary and some people have no symptoms.',
      'A tracker cannot diagnose endometriosis. Its useful role is preserving a clear history of pain, bleeding and how symptoms affect daily life.',
    ],
    seekCare: ['Discuss persistent or severe pelvic/period pain with a healthcare professional rather than relying on an app to identify the cause.'],
    tags: ['endometriosis', 'pelvic pain', 'period pain'],
    sources: [acogEndometriosis],
    version: 1,
    lastReviewed: _reviewed,
  ),
  HealthTip(
    id: 'pcos-awareness',
    category: TipCategory.symptoms,
    title: 'Irregular periods can have many explanations',
    flash: 'PCOS is one possible cause of irregular or infrequent periods, but irregularity alone does not diagnose it.',
    details: [
      'PCOS can involve irregular or absent periods alongside signs such as acne, oily skin or excess facial/body hair, but diagnosis requires clinical assessment and exclusion of other causes.',
      'Nyla should show a changing pattern clearly without assigning a condition to it.',
    ],
    seekCare: ['If your cycle pattern changes substantially or irregular periods concern you, bring the history to a healthcare professional.'],
    tags: ['PCOS', 'irregular', 'acne', 'cycle'],
    sources: [whoPcos],
    version: 1,
    lastReviewed: _reviewed,
  ),
];
