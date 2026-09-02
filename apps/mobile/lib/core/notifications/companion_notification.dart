import 'package:cycle_engine/cycle_engine.dart';

class CompanionNotificationContext {
  const CompanionNotificationContext({
    required this.phase,
    required this.cycleDay,
    required this.daysUntilLikelyPeriod,
    required this.values,
    required this.severities,
    required this.moods,
    required this.daySeed,
  });

  final CyclePhase? phase;
  final int? cycleDay;
  final int? daysUntilLikelyPeriod;
  final Map<String, String> values;
  final Map<String, int> severities;
  final Set<String> moods;
  final int daySeed;
}

class CompanionNotificationPlan {
  const CompanionNotificationPlan({
    required this.dailyBody,
    this.careBody,
    this.careHour = 14,
    this.careMinute = 0,
  });

  final String dailyBody;
  final String? careBody;
  final int careHour;
  final int careMinute;
}

CompanionNotificationPlan companionNotificationPlan(
  CompanionNotificationContext context,
) {
  final values = context.values;
  final severity = context.severities;
  final moods = context.moods;

  final cramps = severity['cramps'] ?? 0;
  final headache = severity['headache'] ?? 0;
  final bloating = severity['bloating'] ?? 0;
  final nausea = severity['nausea'] ?? 0;
  final dizziness = severity['dizziness'] ?? 0;
  final backPain = severity['back_pain'] ?? 0;
  final tenderness = severity['breast_tenderness'] ?? 0;
  final sleep = values['sleep'];
  final energy = values['energy'];
  final appetite = values['appetite'];
  final digestion = values['digestion'];
  final flow = values['flow'];

  final poorSleep = sleep == 'poor' || sleep == 'very_poor';
  final lowEnergy = energy == 'low' || energy == 'very_low';
  final brightEnergy = energy == 'high' || energy == 'very_high';
  final difficultMood = moods.intersection(const {
    'sensitive',
    'low',
    'irritable',
    'anxious',
    'overwhelmed',
  });
  final brightMood = moods.intersection(const {'good', 'happy', 'calm'});

  var roughSignals = 0;
  if (cramps >= 2) roughSignals++;
  if (headache >= 2) roughSignals++;
  if (bloating >= 2) roughSignals++;
  if (nausea >= 2) roughSignals++;
  if (dizziness >= 2) roughSignals++;
  if (backPain >= 2) roughSignals++;
  if (tenderness >= 2) roughSignals++;
  if (poorSleep) roughSignals++;
  if (lowEnergy) roughSignals++;
  if (difficultMood.isNotEmpty) roughSignals++;
  if (flow == 'heavy') roughSignals++;
  if (digestion != null && digestion != 'usual') roughSignals++;

  // High-signal observations stay ahead of general rough-day wording so
  // useful safety context never gets buried by several simultaneous logs.
  if (dizziness >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        "Feeling dizzy today? Move slowly and sit or lie down if you need to. If it feels severe or unusual, please get medical help.",
        "Dizzy day? Give yourself a moment before standing up and keep the pace gentle. Get medical help if it feels severe or worrying.",
        "Take the slow route today if dizziness is hanging around. Sit down when you need to, and please get help if it feels severe or unusual.",
        "Your balance feels off today. Keep yourself safe, move carefully, and get medical help if the dizziness is strong, new or worrying.",
      ]),
      careBody: _pick(context.daySeed + 17, const [
        "How is the dizziness now? Keep moving gently, and please get help if it still feels severe or unusual.",
        "A small check-in: if you are still dizzy, sit down when you need to and get medical help if it feels severe or worrying.",
        "Still feeling light-headed? Take it slowly and do not brush off severe or unusual dizziness.",
      ]),
      careHour: 13,
    );
  }

  if (headache >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 3, const [
        "Headache day? Lower the noise where you can and give yourself room to rest. If it is severe, unusual or worrying, please get medical help.",
        "That headache sounds rough. A quieter pace may help; if the pain is severe, new or unusual, please get medical help.",
        "Your head is having a hard day. Keep things gentle and do not push through a severe or unusual headache without getting help.",
        "If your headache is making the whole day harder, protect a little quiet and rest. Please get medical help if it is severe or worrying.",
      ]),
      careBody: _pick(context.daySeed + 11, const [
        "How is your head feeling now? If the headache is still severe or unusual, please get medical help.",
        "Checking back in on that headache. Rest if you can, and get help if it is still severe, unusual or worrying.",
        "Still a rough headache? You do not need to wait it out if something about it feels severe or unusual.",
      ]),
      careHour: 15,
    );
  }

  if (context.phase == CyclePhase.menstruation && cramps >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 5, const [
        "Crampy day? Warmth, rest and a comfortable position can be worth trying. Give yourself permission to slow down.",
        "Those cramps sound rough. Make the day easier where you can and get comfortable without feeling guilty about it.",
        "Strong cramps can take a lot out of you. Keep comfort close and let today be a little softer.",
        "If the cramps are stealing your attention today, comfort gets priority. Warmth or gentle movement may feel good.",
        "Rough cramp day. You do not have to move through it at full speed; choose the easier version of today where you can.",
      ]),
      careBody: _pick(context.daySeed + 19, const [
        "Still crampy? A little rest counts as taking care of things too.",
        "How are the cramps now? Keep the comfy option close and take the slower pace if you need it.",
        "Checking in on you. If the cramps are still rough, make room for comfort instead of pushing through.",
        "Still having a hard cramp day? Warmth, rest and a gentler pace are all valid choices.",
      ]),
      careHour: 14,
    );
  }

  if (cramps >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 7, const [
        "Strong cramps today? Take things gently and choose what feels comfortable. If the pain is severe or unusual, please get medical help.",
        "Those cramps deserve attention. Ease the pace where you can, and get medical help if the pain is severe, new or worrying.",
        "A strong cramp day is not something you have to prove you can ignore. Get comfortable and seek help if the pain feels severe or unusual.",
        "If the cramps are intense today, choose comfort over pushing through. Please get medical help if something feels severe or different from usual.",
      ]),
      careBody: _pick(context.daySeed + 23, const [
        "How are those cramps now? Please get help if the pain is still severe or unusual.",
        "Checking back on the cramps. Keep things gentle and do not brush off severe or unusual pain.",
        "Still hurting? You can keep the day soft, and please get medical help if the pain feels severe or worrying.",
      ]),
      careHour: 14,
    );
  }

  if (nausea >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 9, const [
        "Feeling nauseous today? Keep things gentle and go with whatever food, drink and pace feel manageable.",
        "Your stomach is having a rough day. Small, manageable choices are enough for now.",
        "Nausea can make everything feel like more effort. Keep the pace light and choose whatever feels easiest on your stomach.",
        "If your stomach is turning today, simplify things. Eat and drink what feels manageable and give yourself some room.",
      ]),
      careBody: _pick(context.daySeed + 29, const [
        "How is your stomach now? Keep today gentle if the nausea is still hanging around.",
        "A little check-in on that nausea: small and manageable is enough today.",
        "Still queasy? Keep the pace easy and listen to what your stomach tolerates.",
      ]),
      careHour: 13,
    );
  }

  if (backPain >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 13, const [
        "Your back is asking for some kindness today. Change position when you need to and do not force comfort.",
        "Rough back day? Let comfort win. Shift position, rest, or move gently if that feels better.",
        "If your back is making everything harder today, keep the day flexible and choose the positions that feel easiest.",
        "Strong back ache today? You can slow down, change position often and skip anything that makes it worse.",
      ]),
      careBody: _pick(context.daySeed + 31, const [
        "Still achy? Give yourself permission to choose the comfortable option today.",
        "How is your back now? Keep changing things up if one position is not helping.",
        "A small back check-in: do what feels comfortable, not what you think you should push through.",
      ]),
      careHour: 15,
    );
  }

  if (flow == 'heavy') {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 15, const [
        "Heavier-flow day? Keep what you need nearby and take a little extra care of yourself. If bleeding is unusually heavy or you feel faint, please get medical help.",
        "Your flow is heavier today. Keep supplies close and take it gently; get medical help if the bleeding feels unusually heavy or you feel faint.",
        "Heavy-flow day. Make the practical things easy on yourself, and please get medical help if the bleeding feels excessive or you become faint or very dizzy.",
        "If today means more frequent changes and a heavier flow, keep things close at hand. Feeling faint or unusually heavy bleeding deserves medical attention.",
      ]),
      careBody: _pick(context.daySeed + 37, const [
        "How is the flow now? Keep supplies nearby, and please get medical help if the bleeding feels unusually heavy or you feel faint.",
        "Checking in on a heavier-flow day. Take care of yourself and get help if you feel faint or the bleeding seems unusually heavy.",
        "A little care check: if the heavy flow is continuing and you feel faint or unwell, please get medical help.",
      ]),
      careHour: 13,
    );
  }

  if (roughSignals >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 21, const [
        "Your body has had a lot to say today. You do not have to deal with every bit of it at full speed.",
        "That sounds like a lot for one day. Keep things simple where you can and give yourself permission to do less.",
        "A few things seem to be piling up today. Be on your own side and make the day a little easier where you can.",
        "This looks like one of those days where several small things add up. Protect your energy and keep the plan simple.",
        "Your check-in has a lot going on today. Pick comfort, lower the pressure, and leave something non-essential for later.",
        "Not every rough signal needs its own solution right now. Make the next hour kinder and take the day in smaller pieces.",
      ]),
      careBody: _pick(context.daySeed + 41, const [
        "Just checking in. If today still feels like a lot, doing less is allowed.",
        "How are you holding up? Keep the rest of today gentle if your body is still having a hard time.",
        "A small check-in: you do not need to fix every uncomfortable thing at once.",
        "Still a lot going on? Keep the next part of the day simple and comfortable.",
      ]),
      careHour: 15,
    );
  }

  if (poorSleep && lowEnergy) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 25, const [
        "Poor sleep and low energy is a heavy combination. Lower the bar a little today.",
        "You sound tired today. Save your energy for what actually matters and let the rest be lighter.",
        "Running on poor sleep? Make today smaller. The important things can stay; the optional things can wait.",
        "Your battery is low today. Treat it like a real limit instead of something you have to argue with.",
        "Not much sleep and not much energy is enough reason to take the gentler route today.",
        "Today may need fewer expectations. Protect your energy and let rest be part of the plan.",
      ]),
      careBody: _pick(context.daySeed + 43, const [
        "A little reminder: you do not have to earn rest on a low-energy day.",
        "How is your energy now? If you are still wiped out, keep the rest of the day light.",
        "Still tired? Save something for yourself instead of spending every bit of energy you have.",
        "A quiet check-in: tired is a good enough reason to make the afternoon easier.",
      ]),
      careHour: 11,
      careMinute: 30,
    );
  }

  if (difficultMood.contains('overwhelmed') ||
      difficultMood.contains('anxious')) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 27, const [
        "If everything feels a little loud today, make the next thing small. One thing at a time is enough.",
        "Feeling overwhelmed or anxious deserves gentleness, not another task. Keep the next step tiny.",
        "If your mind is racing today, you do not have to solve the whole day at once. Just choose the next manageable thing.",
        "A noisy head can make a normal day feel much bigger. Shrink the plan and give yourself some room.",
        "You logged an anxious or overwhelmed kind of day. Keep the next hour simple and stay on your own side.",
        "If everything feels urgent, pick one thing that actually is. The rest can wait a little.",
      ]),
      careBody: lowEnergy || poorSleep
          ? _pick(context.daySeed + 47, const [
              "How is the day feeling now? Keep the next hour simple; you do not need to solve everything at once.",
              "A small check-in: if your head is still crowded, make the next step tiny.",
              "Still feeling stretched thin? Take one thing at a time and let something non-essential wait.",
            ])
          : null,
      careHour: 16,
    );
  }

  if (context.phase == CyclePhase.menstruation &&
      (context.cycleDay ?? 99) <= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 33, const [
        "Early period days can be a lot. Get comfortable and take today at your pace.",
        "Your period is here. Keep the practical things close and make a little room for yourself too.",
        "First couple of period days? Keep comfort nearby and let the day be softer if your body wants that.",
        "Early period check-in: how are cramps, energy and comfort today? You can adjust the day around the answer.",
        "Your period has just started. No need to pretend that feels like an ordinary day if it does not.",
        "A fresh period can change the whole feel of a day. Keep things easy where you can and check in with yourself.",
      ]),
      careBody: _pick(context.daySeed + 53, const [
        "Just checking in on you. Early period days do not need extra pressure.",
        "How is your body doing now? Keep the comfy things close if today is still rough.",
        "A little period-day check-in: make the rest of today easier where you can.",
        "Still feeling it? Take the slower route through the rest of the day if that helps.",
      ]),
      careHour: 14,
    );
  }

  if (cramps >= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 35, const [
        "Noticing cramps today? Warmth, a comfortable position or gentle movement may feel good.",
        "A little crampy? Give your body some room and choose whatever feels easiest.",
        "Cramps showing up today? You can make small comfort adjustments before they take over the whole day.",
        "If cramps are nagging at you, try the comfortable option first: warmth, rest or gentle movement if it feels good.",
        "Mild-to-moderate cramps can still be distracting. Make the day a little kinder where you can.",
      ]),
    );
  }

  if (poorSleep) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 39, const [
        "Sleep was rough? You do not need to perform like it was not. Be a little easier on yourself today.",
        "A poor-sleep day deserves a softer plan. Protect a little energy for yourself too.",
        "Not your best night? Keep today's expectations realistic and save some energy for later.",
        "If you woke up already tired, that matters. Build a little breathing room into the day if you can.",
        "Poor sleep can make everything feel louder. Keep the day simpler and give yourself a gentler evening.",
      ]),
    );
  }

  if (lowEnergy) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 45, const [
        "Low-energy day? Do the important things gently and let enough be enough.",
        "Your energy is low today. A slower pace is still a valid pace.",
        "Not much in the tank today? Spend it on what matters and make the rest easier.",
        "Your body is giving you a low-battery day. Adjust the plan instead of fighting the battery.",
        "If energy is scarce today, protect some of it for yourself too.",
      ]),
    );
  }

  if (difficultMood.isNotEmpty) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 49, const [
        "A more sensitive day is still just a day. Give yourself a little space and do not make it a character judgment.",
        "Your mood feels heavier today. Notice it without making yourself fight it.",
        "A tender mood can make small things land harder. Keep some distance from anything you do not need to deal with right now.",
        "If you feel more irritable or low today, give yourself a little room before expecting an explanation.",
        "Your check-in sounds emotionally heavier today. Be careful with the way you talk to yourself too.",
      ]),
    );
  }

  if (headache >= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 51, const [
        "Headache showing up today? A quieter pace and a little rest may be kinder than pushing through.",
        "Your head is a little unhappy today. Lower the noise where you can and keep the pace comfortable.",
        "A nagging headache can make everything feel more tiring. Give yourself some quiet if you can.",
        "Headache day? Protect a little calm and do not force extra screen time or noise if it feels worse.",
      ]),
    );
  }

  if (nausea >= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 55, const [
        "Your stomach seems a little unhappy today. Keep things simple and go at the pace that feels manageable.",
        "A bit nauseous? Small and easy is fine today. Listen to what your stomach tolerates.",
        "If your stomach feels off, do not make food or the day into a battle. Choose what feels manageable.",
        "Nausea can quietly drain energy. Keep the plan light and your choices easy on your stomach.",
      ]),
    );
  }

  if (bloating >= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 57, const [
        "Feeling bloated today? Comfort comes first. Choose what feels easy on your body and skip the self-judgment.",
        "Bloaty day? Wear the comfortable thing and let your stomach take up the space it takes up.",
        "If your tummy feels full or uncomfortable today, make comfort the goal rather than trying to look or feel a certain way.",
        "Bloating can make clothes and movement feel different. Give yourself the practical comfort you need.",
        "Your stomach feels a little more full today. No need to turn that into a problem with your body.",
      ]),
    );
  }

  if (backPain >= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 59, const [
        "A little achy today? Change position, stretch only if it feels good, and choose comfort where you can.",
        "Back feeling grumpy? Shift position when you need to and skip the heroic sitting posture.",
        "If your back is nagging today, move or rest in the way that feels best rather than forcing one position.",
        "A mild back ache still deserves comfort. Make small adjustments before it becomes the whole day.",
      ]),
    );
  }

  if (tenderness >= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 61, const [
        "Feeling tender today? Soft, comfortable support and a gentler day may feel better.",
        "Breast tenderness today? Choose whatever support feels comfortable and avoid making the day harder than it needs to be.",
        "If your chest feels tender, comfort is the useful goal. Softer clothing or support may help.",
        "A tender-body day is a good day to pick comfort over anything restrictive.",
      ]),
    );
  }

  if (digestion != null && digestion != 'usual') {
    final digestionCopy = switch (digestion) {
      'constipation' => const [
          "Digestion is moving slowly today. Keep comfortable, drink normally, and notice what helps without forcing it.",
          "Constipated today? Give your gut some patience and keep food, fluids and movement comfortable for you.",
          "Your gut seems a little slow today. Small routine things can help; no need to make it a whole project.",
        ],
      'loose_stool' => const [
          "Your gut is moving faster today. Keep fluids nearby and make the day easy on your stomach.",
          "Looser-stool day? Stay comfortable, drink normally and give your gut a quieter day if it needs one.",
          "Your digestion is a little speedy today. Keep things simple and look after your fluids.",
        ],
      'gassy' => const [
          "Feeling gassy today? Comfort first. Gentle movement can feel good if your body is up for it.",
          "Your stomach feels a bit bubbly today. Wear the comfortable thing and let your gut have an ordinary weird day.",
          "Gassy day? Keep things easy and notice what feels comfortable without overthinking every bite.",
        ],
      _ => const [
          "Your digestion feels different today. Keep comfortable and notice what your body prefers.",
          "Gut feeling a little off? Keep things simple and give it some room to settle.",
          "Your stomach has a different rhythm today. Comfort and a little patience are enough.",
        ],
    };
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 63, digestionCopy),
    );
  }

  if (appetite == 'higher' || appetite == 'cravings') {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 67, const [
        "Hungrier or craving something today? There is no moral score attached. Eat enough and listen to what your body is asking for.",
        "More hungry today? Feed yourself. Appetite is information, not a test of discipline.",
        "Craving something? You do not need to turn food into a negotiation. Eat enough and move on with your day.",
        "Your appetite is louder today. That is allowed. Notice it, feed yourself and skip the guilt.",
        "Hungry is a body signal, not a personality flaw. Give yourself enough food today.",
      ]),
    );
  }

  if (brightMood.isNotEmpty || brightEnergy) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 69, const [
        "A lighter-feeling day? I hope there is a little room to enjoy it.",
        "You seem to have a bit more ease today. Enjoy the good patch without needing to optimise it.",
        "Nice to see a brighter note in today's check-in. Let yourself have the good day.",
        "More energy or a lighter mood today? Lovely. Spend a little of it on something that feels good too.",
        "Today sounds a touch easier. You do not need a lesson from it; you can just enjoy that.",
        "A good-body day deserves noticing too. I hope something in it feels genuinely nice.",
      ]),
    );
  }

  if (context.phase == CyclePhase.menstruation) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 71, const [
        "Period-day check-in: how is your body doing, beyond just the flow number?",
        "Your period is here. How are comfort, energy and mood doing today?",
        "A little period-day hello. Anything your body wants more or less of today?",
        "How is this period day treating you? You can adjust the plan around how you actually feel.",
        "Period day, ordinary life still happening. Check what would make today a little easier for you.",
      ]),
    );
  }

  final daysUntil = context.daysUntilLikelyPeriod;
  if (daysUntil != null && daysUntil >= 0 && daysUntil <= 3) {
    final closeCopy = daysUntil <= 1
        ? const [
            "Your period may be very close now. Maybe keep the comfy things and whatever supplies you like within easy reach.",
            "Your period could be around the corner. A small practical prep now can make tomorrow easier.",
            "Period may be close. Keep what you usually want nearby and give yourself a little extra room today.",
            "This may be the day before your period. If your body feels different, meet it where it is rather than pushing against it.",
          ]
        : const [
            "Your period may be getting close. If you feel a little different today, meet yourself where you are.",
            "Your period could be nearby. Maybe keep the comfy things close and give yourself a little extra room.",
            "A few days from your expected period. Nothing special to do; just keep what makes period days easier within reach.",
            "Your period may be a few days away. Check in with energy, appetite, sleep and comfort without expecting any one pattern.",
          ];
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 73, closeCopy),
    );
  }

  if (context.phase == CyclePhase.follicular) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 79, const [
        "How is your energy settling today? No right answer — just notice what kind of day your body brought you.",
        "Small check-in: how are energy, focus and comfort today?",
        "How does your body feel after the period stretch — lighter, the same, or something else entirely?",
        "A little body check-in for today: what feels easy, and what feels like effort?",
        "How is your pace today? If energy is there, enjoy it. If it is not, work with the day you actually have.",
      ]),
    );
  }

  if (context.phase == CyclePhase.periOvulatory) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 83, const [
        "Around mid-cycle, a small check-in: anything feeling noticeably different in energy, discharge or comfort today?",
        "How is mid-cycle treating you today? A quick note now can be useful when you look back later.",
        "Today's tiny check-in: energy, mood, discharge, comfort — anything worth remembering?",
        "Anything standing out in your body today? Mid-cycle can be subtle, and subtle still counts as useful information.",
      ]),
    );
  }

  if (context.phase == CyclePhase.luteal) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed + 89, const [
        "A small later-cycle check-in: how are sleep, appetite, energy and comfort today?",
        "How is your body doing today? Notice what feels different without deciding it has to mean something.",
        "Tiny check-in: anything in mood, sleep, appetite or comfort worth remembering from today?",
        "How is your pace today? If you need more room, take it; if you feel good, enjoy that too.",
        "One minute for yourself: what is your body making easy today, and what is it asking you to soften?",
      ]),
    );
  }

  return CompanionNotificationPlan(
    dailyBody: genericCompanionBody(context.daySeed),
  );
}

String genericCompanionBody(int daySeed) => _pick(daySeed + 97, const [
      "How are you feeling today? No perfect log needed — just a small check-in with yourself.",
      "Tiny check-in: how are body, mood and energy actually doing today?",
      "Just checking in. What feels different, easy or annoying today?",
      "How is today sitting in your body? A few taps is enough if anything is worth remembering.",
      "A small moment for you: how are energy, comfort and mood right now?",
      "Anything your body has been trying to get your attention about today?",
      "Before the day runs away with you, how are you actually feeling?",
      "No need for a perfect health diary. Just notice the one or two things that feel most true today.",
      "A little hello from Nyla. How is your body treating you today?",
      "What kind of day is your body having — easy, tired, crampy, hungry, calm, something else?",
      "Quick self-check: is there anything from today you would want future-you to remember?",
      "How are you doing in your body today, not just on your to-do list?",
    ]);

String periodApproachingCompanionBody(int daySeed) =>
    _pick(daySeed + 101, const [
      "Your period may be getting close. Maybe keep the comfy things and your usual supplies within easy reach.",
      "Your expected period window is coming up. A tiny bit of prep now can make the next few days easier.",
      "Period may be approaching. Nothing dramatic — just a good time to make sure the things you like to have are nearby.",
      "Your next period could be getting close. Keep comfort and whatever supplies you prefer somewhere easy to grab.",
      "A small heads-up: your period may be on its way soon. Make future-you's day a little easier if you feel like it.",
    ]);

String expectedWindowCompanionBody(int daySeed) => _pick(daySeed + 103, const [
      "Your period could start around now. Be a little extra kind to yourself if your body feels different today.",
      "Your expected period window starts around now. Keep the practical things close and take the day as it comes.",
      "Your period may show up around now. If today feels ordinary, that is fine too — this is only a timing window.",
      "This is around the start of your expected period window. Keep what you need nearby and check in with how you actually feel.",
      "Your period could be near. A little comfort and a little practical prep are enough; the timing can still move around.",
    ]);

String privateCompanionBody(int daySeed) => _pick(daySeed + 107, const [
      "A little check-in from Nyla. Be gentle with yourself today.",
      "Nyla is thinking of you. Take today at your own pace.",
      "A small note from Nyla: check in with yourself when you have a moment.",
      "A quiet hello from Nyla. How are you doing today?",
      "A tiny reminder from Nyla: save a little care for yourself too.",
      "Nyla check-in. Take a moment for yourself when you can.",
      "Just a little hello from Nyla. Hope you are treating yourself kindly today.",
      "A small moment for you, whenever you have one.",
    ]);

T _pick<T>(int seed, List<T> values) => values[seed.abs() % values.length];
