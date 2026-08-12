import 'package:flutter/material.dart';

import '../theme/nyla_theme.dart';

enum LogKind { severity, choice, multiChoice }

class LogChoice {
  const LogChoice(this.id, this.label);

  final String id;
  final String label;
}

class LogDefinition {
  const LogDefinition({
    required this.key,
    required this.label,
    required this.icon,
    required this.tint,
    this.kind = LogKind.severity,
    this.choices = const [],
  });

  final String key;
  final String label;
  final IconData icon;
  final Color tint;
  final LogKind kind;
  final List<LogChoice> choices;

  String choiceLabel(String id) {
    for (final choice in choices) {
      if (choice.id == id) return choice.label;
    }
    return id;
  }
}

const flowDefinition = LogDefinition(
  key: 'flow',
  label: 'Flow',
  icon: Icons.water_drop_rounded,
  tint: NylaColors.roseSoft,
  kind: LogKind.choice,
  choices: [
    LogChoice('none', 'None'),
    LogChoice('spotting', 'Spotting'),
    LogChoice('light', 'Light'),
    LogChoice('medium', 'Medium'),
    LogChoice('heavy', 'Heavy'),
  ],
);

const builtInLogs = <LogDefinition>[
  LogDefinition(key: 'cramps', label: 'Cramps', icon: Icons.blur_circular_rounded, tint: NylaColors.peach),
  LogDefinition(
    key: 'energy',
    label: 'Energy',
    icon: Icons.bolt_rounded,
    tint: NylaColors.sage,
    kind: LogKind.choice,
    choices: [
      LogChoice('very_low', 'Very low'),
      LogChoice('low', 'Low'),
      LogChoice('steady', 'Steady'),
      LogChoice('high', 'High'),
      LogChoice('very_high', 'Very high'),
    ],
  ),
  LogDefinition(
    key: 'mood',
    label: 'Mood',
    icon: Icons.sentiment_satisfied_alt_rounded,
    tint: NylaColors.lavender,
    kind: LogKind.multiChoice,
    choices: [
      LogChoice('calm', 'Calm'),
      LogChoice('good', 'Good'),
      LogChoice('happy', 'Happy'),
      LogChoice('sensitive', 'Sensitive'),
      LogChoice('low', 'Low'),
      LogChoice('irritable', 'Irritable'),
      LogChoice('anxious', 'Anxious'),
      LogChoice('overwhelmed', 'Overwhelmed'),
    ],
  ),
  LogDefinition(
    key: 'sleep',
    label: 'Sleep',
    icon: Icons.bedtime_rounded,
    tint: NylaColors.lavender,
    kind: LogKind.choice,
    choices: [
      LogChoice('very_poor', 'Very poor'),
      LogChoice('poor', 'Poor'),
      LogChoice('okay', 'Okay'),
      LogChoice('good', 'Good'),
      LogChoice('great', 'Great'),
    ],
  ),
  LogDefinition(key: 'headache', label: 'Headache', icon: Icons.psychology_alt_rounded, tint: NylaColors.peach),
  LogDefinition(key: 'bloating', label: 'Bloating', icon: Icons.circle_outlined, tint: NylaColors.sage),
  LogDefinition(key: 'nausea', label: 'Nausea', icon: Icons.sick_outlined, tint: NylaColors.sage),
  LogDefinition(key: 'dizziness', label: 'Dizziness', icon: Icons.motion_photos_on_outlined, tint: NylaColors.lavender),
  LogDefinition(key: 'back_pain', label: 'Back pain', icon: Icons.accessibility_new_rounded, tint: NylaColors.peach),
  LogDefinition(
    key: 'skin',
    label: 'Skin',
    icon: Icons.face_rounded,
    tint: NylaColors.roseSoft,
    kind: LogKind.multiChoice,
    choices: [
      LogChoice('clear', 'Clear'),
      LogChoice('breakout', 'Breakout'),
      LogChoice('oily', 'Oily'),
      LogChoice('dry', 'Dry'),
      LogChoice('sensitive', 'Sensitive'),
    ],
  ),
  LogDefinition(
    key: 'appetite',
    label: 'Appetite',
    icon: Icons.restaurant_rounded,
    tint: NylaColors.peach,
    kind: LogKind.choice,
    choices: [
      LogChoice('lower', 'Lower'),
      LogChoice('usual', 'Usual'),
      LogChoice('higher', 'Higher'),
      LogChoice('cravings', 'Cravings'),
    ],
  ),
  LogDefinition(
    key: 'breast_tenderness',
    label: 'Tenderness',
    icon: Icons.favorite_border_rounded,
    tint: NylaColors.roseSoft,
  ),
  LogDefinition(
    key: 'discharge',
    label: 'Discharge',
    icon: Icons.opacity_rounded,
    tint: NylaColors.sage,
    kind: LogKind.choice,
    choices: [
      LogChoice('none', 'None'),
      LogChoice('dry', 'Dry'),
      LogChoice('sticky', 'Sticky'),
      LogChoice('creamy', 'Creamy'),
      LogChoice('watery', 'Watery'),
      LogChoice('stretchy', 'Stretchy'),
    ],
  ),
  LogDefinition(
    key: 'digestion',
    label: 'Digestion',
    icon: Icons.spa_rounded,
    tint: NylaColors.sage,
    kind: LogKind.choice,
    choices: [
      LogChoice('usual', 'Usual'),
      LogChoice('constipation', 'Constipation'),
      LogChoice('loose_stool', 'Loose stool'),
      LogChoice('gassy', 'Gassy'),
    ],
  ),
  LogDefinition(
    key: 'exercise',
    label: 'Exercise',
    icon: Icons.directions_walk_rounded,
    tint: NylaColors.lavender,
    kind: LogKind.choice,
    choices: [
      LogChoice('none', 'None'),
      LogChoice('gentle', 'Gentle'),
      LogChoice('moderate', 'Moderate'),
      LogChoice('intense', 'Intense'),
    ],
  ),
];

const severityChoices = <LogChoice>[
  LogChoice('none', 'None'),
  LogChoice('mild', 'Mild'),
  LogChoice('moderate', 'Moderate'),
  LogChoice('strong', 'Strong'),
  LogChoice('severe', 'Severe'),
];
