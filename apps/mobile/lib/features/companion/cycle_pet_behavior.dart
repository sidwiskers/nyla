import 'package:flutter/foundation.dart';

import 'cycle_pet_state.dart';

enum CyclePetAction {
  lookLeft,
  lookRight,
  nod,
  wink,
  stretch,
  yawn,
  groom,
  paw,
  tailFlick,
  peek,
  hopLeft,
  hopRight,
  settle,
  purr,
  nuzzle,
  love,
  surprised,
  annoyed,
  shakeOff,
}

@immutable
class CyclePetBehaviorProfile {
  const CyclePetBehaviorProfile({
    required this.idleActions,
    required this.tapActions,
    required this.minIdleMilliseconds,
    required this.maxIdleMilliseconds,
    required this.blinkChance,
    required this.roaming,
  });

  final List<CyclePetAction> idleActions;
  final List<CyclePetAction> tapActions;
  final int minIdleMilliseconds;
  final int maxIdleMilliseconds;
  final double blinkChance;
  final double roaming;
}

CyclePetBehaviorProfile cyclePetBehavior(CyclePetDisposition disposition) {
  final familiar = disposition.familiarity >= 0.55 || disposition.recentlyPetted;

  final base = switch (disposition.mood) {
    CyclePetMood.cozy => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.settle,
          CyclePetAction.stretch,
          CyclePetAction.groom,
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.tailFlick,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.nod,
          CyclePetAction.purr,
          CyclePetAction.nuzzle,
          CyclePetAction.wink,
        ],
        minIdleMilliseconds: 3900,
        maxIdleMilliseconds: 7600,
        blinkChance: 0.62,
        roaming: 0.18,
      ),
    CyclePetMood.gentle => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.settle,
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.peek,
          CyclePetAction.tailFlick,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.nod,
          CyclePetAction.purr,
          CyclePetAction.nuzzle,
          CyclePetAction.paw,
          CyclePetAction.wink,
        ],
        minIdleMilliseconds: 4100,
        maxIdleMilliseconds: 7800,
        blinkChance: 0.66,
        roaming: 0.12,
      ),
    CyclePetMood.drowsy => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.yawn,
          CyclePetAction.settle,
          CyclePetAction.stretch,
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.nod,
          CyclePetAction.purr,
          CyclePetAction.nuzzle,
        ],
        minIdleMilliseconds: 4700,
        maxIdleMilliseconds: 8500,
        blinkChance: 0.74,
        roaming: 0.08,
      ),
    CyclePetMood.curious => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.peek,
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.paw,
          CyclePetAction.tailFlick,
          CyclePetAction.hopLeft,
          CyclePetAction.hopRight,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.paw,
          CyclePetAction.peek,
          CyclePetAction.nod,
          CyclePetAction.hopLeft,
          CyclePetAction.hopRight,
          CyclePetAction.wink,
        ],
        minIdleMilliseconds: 3000,
        maxIdleMilliseconds: 6500,
        blinkChance: 0.48,
        roaming: 0.62,
      ),
    CyclePetMood.bright => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.stretch,
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.tailFlick,
          CyclePetAction.paw,
          CyclePetAction.hopLeft,
          CyclePetAction.hopRight,
          CyclePetAction.peek,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.paw,
          CyclePetAction.nod,
          CyclePetAction.hopLeft,
          CyclePetAction.hopRight,
          CyclePetAction.nuzzle,
          CyclePetAction.wink,
        ],
        minIdleMilliseconds: 2700,
        maxIdleMilliseconds: 5900,
        blinkChance: 0.40,
        roaming: 0.76,
      ),
    CyclePetMood.playful => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.hopLeft,
          CyclePetAction.hopRight,
          CyclePetAction.paw,
          CyclePetAction.tailFlick,
          CyclePetAction.peek,
          CyclePetAction.stretch,
          CyclePetAction.groom,
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.paw,
          CyclePetAction.hopLeft,
          CyclePetAction.hopRight,
          CyclePetAction.peek,
          CyclePetAction.nuzzle,
          CyclePetAction.wink,
        ],
        minIdleMilliseconds: 2400,
        maxIdleMilliseconds: 5300,
        blinkChance: 0.32,
        roaming: 0.92,
      ),
    CyclePetMood.calm => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.settle,
          CyclePetAction.groom,
          CyclePetAction.tailFlick,
          CyclePetAction.stretch,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.nod,
          CyclePetAction.purr,
          CyclePetAction.paw,
          CyclePetAction.nuzzle,
          CyclePetAction.wink,
        ],
        minIdleMilliseconds: 3600,
        maxIdleMilliseconds: 7200,
        blinkChance: 0.57,
        roaming: 0.28,
      ),
    CyclePetMood.affectionate => const CyclePetBehaviorProfile(
        idleActions: [
          CyclePetAction.purr,
          CyclePetAction.nuzzle,
          CyclePetAction.love,
          CyclePetAction.groom,
          CyclePetAction.settle,
          CyclePetAction.lookLeft,
          CyclePetAction.lookRight,
          CyclePetAction.tailFlick,
          CyclePetAction.wink,
        ],
        tapActions: [
          CyclePetAction.nuzzle,
          CyclePetAction.purr,
          CyclePetAction.love,
          CyclePetAction.paw,
          CyclePetAction.nod,
          CyclePetAction.wink,
        ],
        minIdleMilliseconds: 3200,
        maxIdleMilliseconds: 6800,
        blinkChance: 0.56,
        roaming: 0.24,
      ),
  };

  if (!familiar || disposition.mood == CyclePetMood.affectionate) return base;

  return CyclePetBehaviorProfile(
    idleActions: [
      ...base.idleActions,
      CyclePetAction.nuzzle,
      CyclePetAction.purr,
      CyclePetAction.love,
    ],
    tapActions: [
      CyclePetAction.nuzzle,
      CyclePetAction.purr,
      CyclePetAction.love,
      ...base.tapActions,
    ],
    minIdleMilliseconds: base.minIdleMilliseconds,
    maxIdleMilliseconds: base.maxIdleMilliseconds,
    blinkChance: base.blinkChance,
    roaming: base.roaming,
  );
}

Duration cyclePetActionDuration(CyclePetAction action) => switch (action) {
      CyclePetAction.lookLeft || CyclePetAction.lookRight =>
        const Duration(milliseconds: 650),
      CyclePetAction.nod => const Duration(milliseconds: 560),
      CyclePetAction.wink => const Duration(milliseconds: 720),
      CyclePetAction.tailFlick => const Duration(milliseconds: 720),
      CyclePetAction.paw => const Duration(milliseconds: 780),
      CyclePetAction.peek => const Duration(milliseconds: 900),
      CyclePetAction.hopLeft || CyclePetAction.hopRight =>
        const Duration(milliseconds: 720),
      CyclePetAction.stretch => const Duration(milliseconds: 1180),
      CyclePetAction.yawn => const Duration(milliseconds: 1250),
      CyclePetAction.groom => const Duration(milliseconds: 1320),
      CyclePetAction.settle => const Duration(milliseconds: 1120),
      CyclePetAction.purr => const Duration(milliseconds: 1180),
      CyclePetAction.nuzzle => const Duration(milliseconds: 980),
      CyclePetAction.love => const Duration(milliseconds: 1380),
      CyclePetAction.surprised => const Duration(milliseconds: 620),
      CyclePetAction.annoyed => const Duration(milliseconds: 1080),
      CyclePetAction.shakeOff => const Duration(milliseconds: 860),
    };
