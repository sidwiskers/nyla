import 'package:flutter/material.dart';

import '../theme/nyla_theme.dart';

enum LogKind { scale, choice, toggle }

class LogDefinition {
  const LogDefinition({
    required this.key,
    required this.label,
    required this.icon,
    required this.tint,
    this.kind = LogKind.scale,
    this.choices = const [],
  });

  final String key;
  final String label;
  final IconData icon;
  final Color tint;
  final LogKind kind;
  final List<String> choices;
}

const flowDefinition = LogDefinition(
  key: 'flow',
  label: 'Flow',
  icon: Icons.water_drop_rounded,
  tint: NylaColors.roseSoft,
  kind: LogKind.choice,
  choices: ['None', 'Spotting', 'Light', 'Medium', 'Heavy'],
);

const builtInLogs = <LogDefinition>[
  LogDefinition(key: 'cramps', label: 'Cramps', icon: Icons.blur_circular_rounded, tint: NylaColors.peach),
  LogDefinition(key: 'energy', label: 'Energy', icon: Icons.bolt_rounded, tint: NylaColors.sage),
  LogDefinition(key: 'mood', label: 'Mood', icon: Icons.sentiment_satisfied_alt_rounded, tint: NylaColors.lavender),
  LogDefinition(key: 'sleep', label: 'Sleep', icon: Icons.bedtime_rounded, tint: NylaColors.lavender),
  LogDefinition(key: 'headache', label: 'Headache', icon: Icons.psychology_alt_rounded, tint: NylaColors.peach),
  LogDefinition(key: 'bloating', label: 'Bloating', icon: Icons.circle_outlined, tint: NylaColors.sage),
  LogDefinition(key: 'skin', label: 'Skin', icon: Icons.face_rounded, tint: NylaColors.roseSoft),
  LogDefinition(key: 'appetite', label: 'Appetite', icon: Icons.restaurant_rounded, tint: NylaColors.peach),
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
    choices: ['None', 'Dry', 'Sticky', 'Creamy', 'Watery', 'Stretchy'],
  ),
  LogDefinition(
    key: 'digestion',
    label: 'Digestion',
    icon: Icons.spa_rounded,
    tint: NylaColors.sage,
    kind: LogKind.choice,
    choices: ['Usual', 'Constipation', 'Loose stool'],
  ),
  LogDefinition(
    key: 'exercise',
    label: 'Exercise',
    icon: Icons.directions_walk_rounded,
    tint: NylaColors.lavender,
    kind: LogKind.choice,
    choices: ['None', 'Light', 'Moderate', 'Hard'],
  ),
];

const severityLabels = ['None', 'Mild', 'Moderate', 'Strong', 'Severe'];
