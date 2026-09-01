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
  });

  final String dailyBody;
  final String? careBody;
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

  if (dizziness >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Feeling dizzy today? Please take things slowly. Sit or lie down if you need to, and get help if it feels severe or unusual.',
        'Dizzy day? Move gently and give yourself a moment before standing up. If it feels severe or worrying, please get medical help.',
      ]),
      careBody:
          'A small check-in from Nyla: if you are still feeling dizzy, take it slowly and please get help if it feels severe or unusual.',
    );
  }

  if (roughSignals >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Your body has had a lot to say today. You do not have to push through every bit of it at once.',
        'That sounds like a lot for one day. Keep things simple where you can and give yourself permission to do less.',
        'A few things seem to be piling up today. Be on your own side and make the day a little easier where you can.',
      ]),
      careBody: _pick(context.daySeed + 1, const [
        'Just checking in. If today feels like a lot, doing less is allowed.',
        'Nyla check-in: keep today gentle. You do not need to win against a rough body day.',
      ]),
    );
  }

  if (context.phase == CyclePhase.menstruation && cramps >= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Crampy day? Be gentle with yourself. Warmth, rest and a comfortable position can be worth trying.',
        'Those cramps sound rough. You are allowed to slow the day down and get comfortable.',
      ]),
      careBody: _pick(context.daySeed + 1, const [
        'Still crampy? A little rest counts as taking care of things too.',
        'Nyla check-in: no need to treat a rough cramp day like a normal one.',
      ]),
    );
  }

  if (headache >= 3) {
    return CompanionNotificationPlan(
      dailyBody:
          'Headache day? Lower the noise where you can, drink normally, and give yourself a little room to rest.',
      careBody:
          'How is your head feeling now? If the headache is severe, unusual, or worrying, please get medical help.',
    );
  }

  if (nausea >= 3) {
    return const CompanionNotificationPlan(
      dailyBody:
          'Feeling nauseous today? Keep things gentle and go with whatever food, drink and pace feel manageable.',
      careBody:
          'A little Nyla check-in: take today slowly if your stomach is still having a rough time.',
    );
  }

  if (backPain >= 3) {
    return const CompanionNotificationPlan(
      dailyBody:
          'Your back is asking for some kindness today. Change position when you need to and do not force comfort.',
      careBody:
          'Still achy? Give yourself permission to choose the comfortable option today.',
    );
  }

  if (poorSleep && lowEnergy) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Poor sleep and low energy is a heavy combination. Lower the bar a little today.',
        'You sound tired today. Save your energy for what actually matters and let the rest be lighter.',
      ]),
      careBody:
          'Tiny reminder from Nyla: you do not have to earn rest on a low-energy day.',
    );
  }

  if (difficultMood.contains('overwhelmed') ||
      difficultMood.contains('anxious')) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'If everything feels a little loud today, make the next thing small. One thing at a time is enough.',
        'Feeling overwhelmed or anxious deserves gentleness, not another task. Keep the next step tiny.',
      ]),
      careBody: lowEnergy || poorSleep
          ? 'Nyla check-in: keep the next hour simple. You do not need to solve the whole day at once.'
          : null,
    );
  }

  if (context.phase == CyclePhase.menstruation &&
      (context.cycleDay ?? 99) <= 2) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Early period days can be a lot. Get comfortable, eat and drink normally, and take today at your pace.',
        'Your period is here. Let Nyla keep track of the numbers while you take care of yourself.',
      ]),
      careBody: _pick(context.daySeed + 1, const [
        'Just checking in on you. Early period days do not need extra pressure.',
        'Nyla check-in: comfy things, a slower pace, and a little kindness to yourself today.',
      ]),
    );
  }

  if (cramps >= 2) {
    return const CompanionNotificationPlan(
      dailyBody:
          'Noticing cramps today? A little warmth, a comfortable position or gentle movement may feel good.',
    );
  }

  if (poorSleep) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Sleep was rough? You do not need to perform like it was not. Be a little easier on yourself today.',
        'A poor-sleep day deserves a softer plan. Protect a little energy for yourself too.',
      ]),
    );
  }

  if (lowEnergy) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Low-energy day? Do the important things gently and let “enough” be enough.',
        'Your energy is low today. A slower pace is still a perfectly valid pace.',
      ]),
    );
  }

  if (difficultMood.isNotEmpty) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'A more sensitive day is still just a day, not a verdict on you. Give yourself a little space.',
        'Your mood feels heavier today. Notice it without making yourself fight it.',
      ]),
    );
  }

  if (flow == 'heavy') {
    return const CompanionNotificationPlan(
      dailyBody:
          'Heavier-flow day? Keep what you need nearby and take a little extra care of yourself. If bleeding is unusually heavy or you feel faint, please get medical help.',
    );
  }

  if (headache >= 2) {
    return const CompanionNotificationPlan(
      dailyBody:
          'Headache showing up today? A quieter pace and a little rest may be kinder than pushing through.',
    );
  }

  if (nausea >= 2) {
    return const CompanionNotificationPlan(
      dailyBody:
          'Your stomach seems a little unhappy today. Keep things simple and go at the pace that feels manageable.',
    );
  }

  if (bloating >= 2) {
    return const CompanionNotificationPlan(
      dailyBody:
          'Feeling bloated today? Comfort comes first — choose what feels easy on your body and skip the self-judgment.',
    );
  }

  if (backPain >= 2) {
    return const CompanionNotificationPlan(
      dailyBody:
          'A little achy today? Change position, stretch only if it feels good, and choose comfort where you can.',
    );
  }

  if (tenderness >= 2) {
    return const CompanionNotificationPlan(
      dailyBody:
          'Feeling tender today? Soft, comfortable support and a gentler day may feel better.',
    );
  }

  if (digestion != null && digestion != 'usual') {
    return const CompanionNotificationPlan(
      dailyBody:
          'Your digestion feels different today. No need to over-analyse it — keep comfortable and notice what your body prefers.',
    );
  }

  if (appetite == 'higher' || appetite == 'cravings') {
    return const CompanionNotificationPlan(
      dailyBody:
          'Hungrier or craving something today? No moral score attached — eat enough and listen to what your body is asking for.',
    );
  }

  if (brightMood.isNotEmpty || brightEnergy) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'A lighter-feeling day? I hope there is a little room to enjoy it.',
        'You seem to have a bit more ease today. Enjoy the good patch without needing to optimise it.',
        'Nice to see a brighter note in today’s check-in. Keep some of that gentleness for yourself too.',
      ]),
    );
  }

  if (context.phase == CyclePhase.menstruation) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'How is your body feeling today? Your period is here, but the day does not have to revolve around it.',
        'Period day check-in: how are *you* doing, not just the numbers?',
      ]),
    );
  }

  final daysUntil = context.daysUntilLikelyPeriod;
  if (daysUntil != null && daysUntil >= 0 && daysUntil <= 3) {
    return CompanionNotificationPlan(
      dailyBody: _pick(context.daySeed, const [
        'Your period may be getting close. If you feel a little different today, meet yourself where you are.',
        'Your period could be nearby. Maybe keep the comfy things close and give yourself a little extra room.',
      ]),
    );
  }

  return CompanionNotificationPlan(
    dailyBody: _pick(context.daySeed, const [
      'How are you feeling today? No perfect log needed — just a small check-in with yourself.',
      'Tiny Nyla check-in: how is your body, mood and energy actually doing today?',
      'Just checking in. Notice how today feels before worrying about what the calendar says.',
    ]),
  );
}

String privateCompanionBody(int daySeed) => _pick(daySeed, const [
      'A little check-in from Nyla. Be gentle with yourself today.',
      'Nyla is thinking of you. Take today at your own pace.',
      'A small note from Nyla: check in with yourself when you have a moment.',
    ]);

T _pick<T>(int seed, List<T> values) => values[seed.abs() % values.length];
