import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/theme/nyla_theme.dart';
import 'cycle_pet_state.dart';

const _petWidth = 190.0;
const _petHeight = 132.0;

enum _PetReaction { none, nod, petted, lookLeft, lookRight }

class CyclePetNook extends StatefulWidget {
  const CyclePetNook({
    required this.disposition,
    this.onPetted,
    super.key,
  });

  final CyclePetDisposition disposition;
  final VoidCallback? onPetted;

  @override
  State<CyclePetNook> createState() => _CyclePetNookState();
}

class _CyclePetNookState extends State<CyclePetNook>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _blinkController;
  late final AnimationController _reactionController;
  late final Listenable _repaint;
  final math.Random _random = math.Random();

  Timer? _idleTimer;
  _PetReaction _reaction = _PetReaction.none;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;
  bool _petting = false;
  bool _petHapticSent = false;
  double _petLean = 0;
  double _petDepth = 0;
  double _reactionLean = 0;

  bool get _autonomousMotion => !_reduceMotion && _tickerEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 115),
      reverseDuration: const Duration(milliseconds: 125),
    );
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _repaint = Listenable.merge([_blinkController, _reactionController]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final changed = reduce != _reduceMotion || tickerEnabled != _tickerEnabled;
    _reduceMotion = reduce;
    _tickerEnabled = tickerEnabled;

    if (!_autonomousMotion) {
      _resetMotionState();
      return;
    }
    if (changed || _idleTimer == null) _scheduleIdle();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_autonomousMotion) _scheduleIdle();
      return;
    }
    _resetMotionState();
  }

  void _resetMotionState() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _blinkController.stop(canceled: false);
    _reactionController.stop(canceled: false);
    _blinkController.value = 0;
    _reactionController.value = 0;
    _reaction = _PetReaction.none;
    _reactionLean = 0;
    _petting = false;
    _petHapticSent = false;
    _petLean = 0;
    _petDepth = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _blinkController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    if (!_autonomousMotion || !mounted) return;

    // Energetic dispositions become expressive a little more often, while
    // drowsy/cozy states are deliberately quieter. There is no permanent
    // animation loop; most of the time this widget is completely still.
    final base = (4300 - widget.disposition.energy * 1500).round();
    final milliseconds = base + _random.nextInt(3300);
    _idleTimer = Timer(Duration(milliseconds: milliseconds), () async {
      if (!mounted || !_autonomousMotion || _petting) {
        _scheduleIdle();
        return;
      }

      final gestureChance = 0.10 +
          widget.disposition.energy * 0.18 +
          widget.disposition.familiarity * 0.04;
      if (_random.nextDouble() >= gestureChance) {
        await _blink();
      } else {
        final roll = _random.nextInt(3);
        await _runReaction(
          switch (roll) {
            0 => _PetReaction.lookLeft,
            1 => _PetReaction.lookRight,
            _ => _PetReaction.nod,
          },
          haptic: false,
        );
      }
      _scheduleIdle();
    });
  }

  Future<void> _blink() async {
    if (_blinkController.isAnimating || !mounted || !_autonomousMotion) return;
    await _blinkController.forward(from: 0);
    if (!mounted || !_autonomousMotion) return;
    await _blinkController.reverse();
  }

  Future<void> _runReaction(
    _PetReaction reaction, {
    required bool haptic,
  }) async {
    if (!mounted || _petting) return;
    _idleTimer?.cancel();
    if (haptic) await NylaHaptics.select();
    if (!mounted || _petting) return;

    setState(() => _reaction = reaction);
    await _reactionController.forward(from: 0);
    if (!mounted || _petting || !_tickerEnabled) return;

    setState(() {
      _reaction = _PetReaction.none;
      _reactionLean = 0;
    });
    _reactionController.value = 0;
    _scheduleIdle();
  }

  void _onPetStart(DragStartDetails _) {
    _idleTimer?.cancel();

    // Direct touch always wins over a canned motion. `canceled: false` lets an
    // awaiting reaction finish its Future cleanly before it notices _petting.
    _reactionController.stop(canceled: false);
    setState(() {
      _reaction = _PetReaction.none;
      _reactionController.value = 0;
      _petting = true;
      _petHapticSent = false;
      _petDepth = 0.08;
      _petLean = 0;
    });
  }

  void _onPetUpdate(DragUpdateDetails details) {
    final normalizedX = (details.localPosition.dx / _petWidth).clamp(0.0, 1.0);
    final lean = ((normalizedX - 0.5) * 2).clamp(-1.0, 1.0);
    final nextDepth = (_petDepth + details.delta.dx.abs() / 90).clamp(0.0, 1.0);

    if (!_petHapticSent && nextDepth >= 0.42) {
      _petHapticSent = true;
      unawaited(NylaHaptics.select());
    }

    setState(() {
      _petLean = lean;
      _petDepth = nextDepth;
    });
  }

  void _onPetEnd(DragEndDetails _) {
    final lean = _petLean;
    final wasPet = _petDepth >= 0.28;
    setState(() {
      _petting = false;
      _petLean = 0;
      _petDepth = 0;
      _reactionLean = lean;
    });

    if (!wasPet) {
      _scheduleIdle();
      return;
    }

    widget.onPetted?.call();
    unawaited(NylaHaptics.confirm());
    if (_reduceMotion) {
      _scheduleIdle();
      return;
    }
    unawaited(_runReaction(_PetReaction.petted, haptic: false));
  }

  void _onTap() {
    if (_petting) return;
    if (_reduceMotion) {
      unawaited(NylaHaptics.select());
      return;
    }
    unawaited(_runReaction(_PetReaction.nod, haptic: true));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: SizedBox(
        height: _petHeight,
        width: double.infinity,
        child: Center(
          child: Semantics(
            button: true,
            label:
                'Your little Nyla companion, ${widget.disposition.semantics}. Tap it or stroke left and right to pet it.',
            child: SizedBox(
              key: const ValueKey('cycle-pet-touch-target'),
              width: _petWidth,
              height: _petHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                onHorizontalDragStart: _onPetStart,
                onHorizontalDragUpdate: _onPetUpdate,
                onHorizontalDragEnd: _onPetEnd,
                child: CustomPaint(
                  painter: _CyclePetPainter(
                    disposition: widget.disposition,
                    palette: palette,
                    dark: dark,
                    blink: _blinkController,
                    reactionAnimation: _reactionController,
                    reaction: _reaction,
                    petting: _petting,
                    petLean: _petLean,
                    petDepth: _petDepth,
                    reactionLean: _reactionLean,
                    repaint: _repaint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CyclePetPainter extends CustomPainter {
  _CyclePetPainter({
    required this.disposition,
    required this.palette,
    required this.dark,
    required this.blink,
    required this.reactionAnimation,
    required this.reaction,
    required this.petting,
    required this.petLean,
    required this.petDepth,
    required this.reactionLean,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final CyclePetDisposition disposition;
  final NylaPalette palette;
  final bool dark;
  final Animation<double> blink;
  final Animation<double> reactionAnimation;
  final _PetReaction reaction;
  final bool petting;
  final double petLean;
  final double petDepth;
  final double reactionLean;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _petWidth, size.height / _petHeight);
    final dx = (size.width - _petWidth * scale) / 2;
    final dy = (size.height - _petHeight * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final t = reactionAnimation.value;
    final pulse = math.sin(math.pi * t);
    final variantLean = switch (disposition.variant) {
      1 => -0.025,
      2 => 0.025,
      _ => 0.0,
    };
    final moodTilt = switch (disposition.mood) {
      CyclePetMood.curious => 0.055,
      CyclePetMood.playful => -0.035,
      CyclePetMood.gentle => 0.022,
      _ => 0.0,
    };
    final reactionShift = switch (reaction) {
      _PetReaction.lookLeft => -3.5 * pulse,
      _PetReaction.lookRight => 3.5 * pulse,
      _ => 0.0,
    };
    final nod = reaction == _PetReaction.nod ? 4.5 * pulse : 0.0;
    final petted = reaction == _PetReaction.petted ? pulse : 0.0;
    final activeLean = petting ? petLean * 0.085 : reactionLean * 0.045 * petted;
    final headAngle = moodTilt + variantLean + activeLean;

    _paintBackdrop(canvas, pulse);
    _paintTail(canvas, pulse);
    _paintBody(canvas, petted);
    _paintHead(
      canvas,
      headAngle: headAngle,
      headShiftX: reactionShift,
      headShiftY: nod + petDepth * 1.8 - petted * 1.2,
      petted: petted,
    );
    if (reaction == _PetReaction.petted && t > 0.08 && t < 0.92) {
      _paintAffection(canvas, t, reactionLean);
    }

    canvas.restore();
  }

  void _paintBackdrop(Canvas canvas, double pulse) {
    final ground = Paint()
      ..color = (dark ? palette.lavender : palette.lavenderSoft)
          .withValues(alpha: dark ? 0.24 : 0.68);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(95, 115),
        width: 104 + disposition.closeness * 8,
        height: 12,
      ),
      ground,
    );

    final orb = Paint()
      ..color = switch (disposition.mood) {
        CyclePetMood.cozy =>
          palette.roseSoft.withValues(alpha: dark ? 0.16 : 0.42),
        CyclePetMood.gentle =>
          palette.peachSoft.withValues(alpha: dark ? 0.15 : 0.42),
        CyclePetMood.drowsy =>
          palette.lavenderSoft.withValues(alpha: dark ? 0.18 : 0.52),
        CyclePetMood.curious =>
          palette.sageSoft.withValues(alpha: dark ? 0.13 : 0.42),
        CyclePetMood.bright =>
          palette.butter.withValues(alpha: dark ? 0.12 : 0.28),
        CyclePetMood.playful =>
          palette.roseWash.withValues(alpha: dark ? 0.17 : 0.52),
        CyclePetMood.calm =>
          palette.lavenderMist.withValues(alpha: dark ? 0.14 : 0.54),
      };
    canvas.drawCircle(const Offset(95, 63), 48 + pulse, orb);
  }

  void _paintTail(Canvas canvas, double pulse) {
    final energy = disposition.energy;
    final tailLift = 3 +
        energy * 13 +
        disposition.familiarity * 2 +
        (disposition.recentlyPetted ? 1.2 : 0) +
        (reaction == _PetReaction.nod ? pulse * 2 : 0);
    final tail = Path()
      ..moveTo(126, 89)
      ..cubicTo(
        151,
        91,
        151,
        72 - tailLift,
        139,
        68 - tailLift * 0.34,
      );
    final tailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = dark ? const Color(0xFFB89CCF) : const Color(0xFFC8AFE0);
    canvas.drawPath(tail, tailPaint);
  }

  void _paintBody(Canvas canvas, double petted) {
    final squat = switch (disposition.mood) {
      CyclePetMood.drowsy => 4.0,
      CyclePetMood.cozy => 2.5,
      CyclePetMood.gentle => 2.0,
      _ => 0.0,
    };
    final bodyRect = Rect.fromCenter(
      center: Offset(95, 86 + squat + petted * 1.4),
      width: 78 + disposition.closeness * 4,
      height: 55 - disposition.energy * 4 + squat - petted * 2,
    );
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFFBCA6D6), Color(0xFF987DB8)]
            : const [Color(0xFFE5D8F2), Color(0xFFCBB6E2)],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, body);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = palette.wine.withValues(alpha: dark ? 0.36 : 0.18);
    canvas.drawOval(bodyRect, outline);

    final pawPaint = Paint()
      ..color = dark ? const Color(0xFFAE93CA) : const Color(0xFFD7C4E9);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(72, 106), width: 25, height: 10),
      pawPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(112, 106), width: 25, height: 10),
      pawPaint,
    );
  }

  void _paintHead(
    Canvas canvas, {
    required double headAngle,
    required double headShiftX,
    required double headShiftY,
    required double petted,
  }) {
    canvas.save();
    canvas.translate(95 + headShiftX, 53 + headShiftY);
    canvas.rotate(headAngle);

    final energy = disposition.energy;
    final gentleDrop = switch (disposition.mood) {
      CyclePetMood.gentle => 0.72,
      CyclePetMood.drowsy => 0.62,
      CyclePetMood.cozy => 0.35,
      _ => 0.0,
    };
    final petDrop = petting ? petDepth * 0.48 : petted * 0.28;
    final earDrop = math.max(gentleDrop, petDrop);

    _paintEar(canvas, left: true, drop: earDrop, energy: energy);
    _paintEar(canvas, left: false, drop: earDrop * 0.82, energy: energy);

    final headRect = Rect.fromCenter(
      center: Offset.zero,
      width: 65,
      height: 58 - petted * 1.6,
    );
    final head = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFFC8B4DE), Color(0xFFA68BC2)]
            : const [Color(0xFFEEE4F7), Color(0xFFD4C1E8)],
      ).createShader(headRect);
    canvas.drawOval(headRect, head);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = palette.wine.withValues(alpha: dark ? 0.4 : 0.2);
    canvas.drawOval(headRect, outline);

    _paintForeheadMark(canvas);
    _paintFace(canvas, petted: petted);
    canvas.restore();
  }

  void _paintEar(
    Canvas canvas, {
    required bool left,
    required double drop,
    required double energy,
  }) {
    final direction = left ? -1.0 : 1.0;
    final baseX = direction * 20;
    final lift = 5 + energy * 6;
    final extraFlop = left ? 0.0 : 3.2;
    final path = Path()
      ..moveTo(baseX - direction * 8, -18)
      ..quadraticBezierTo(
        baseX - direction * (15 + extraFlop),
        -37 + drop * 13 + extraFlop,
        baseX + direction,
        -31 - lift + drop * 14,
      )
      ..quadraticBezierTo(
        baseX + direction * 14,
        -25 + drop * 8,
        baseX + direction * 10,
        -14,
      )
      ..close();
    final ear = Paint()
      ..color = dark ? const Color(0xFFB49ACC) : const Color(0xFFDECFEE);
    canvas.drawPath(path, ear);

    final inner = Path()
      ..moveTo(baseX - direction * 3, -21)
      ..quadraticBezierTo(
        baseX - direction * 7,
        -30 + drop * 10,
        baseX + direction,
        -31 - lift * 0.45 + drop * 11,
      )
      ..quadraticBezierTo(
        baseX + direction * 7,
        -25 + drop * 8,
        baseX + direction * 6,
        -19,
      )
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..color = dark
            ? const Color(0xFF8D6F91).withValues(alpha: 0.72)
            : palette.roseSoft.withValues(alpha: 0.86),
    );
  }

  void _paintForeheadMark(Canvas canvas) {
    final markPaint = Paint()
      ..color = (dark ? palette.rose : palette.violet).withValues(alpha: 0.72);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(2, -13), width: 9, height: 5),
      markPaint,
    );
    canvas.drawCircle(
      const Offset(5, -13),
      2.5,
      Paint()
        ..color = dark ? const Color(0xFFC8B4DE) : const Color(0xFFEEE4F7),
    );
  }

  void _paintFace(Canvas canvas, {required double petted}) {
    final moodOpen = switch (disposition.mood) {
      CyclePetMood.drowsy => 0.38,
      CyclePetMood.cozy => 0.72,
      CyclePetMood.gentle => 0.70,
      CyclePetMood.calm => 0.78,
      _ => 1.0,
    };
    final blinkClose = math.sin(math.pi * blink.value);
    final petClose = petting ? petDepth * 0.78 : petted * 0.74;
    final eyeOpen =
        (moodOpen * (1 - blinkClose) * (1 - petClose)).clamp(0.05, 1.0);
    final eyePaint = Paint()
      ..color = dark ? const Color(0xFF392C40) : const Color(0xFF4A3650)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    for (final x in const [-11.0, 11.0]) {
      if (eyeOpen < 0.34) {
        canvas.drawLine(Offset(x - 3, 0), Offset(x + 3, 0.4), eyePaint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, 0),
            width: 5.2,
            height: 7.2 * eyeOpen,
          ),
          eyePaint,
        );
      }
    }

    final blushAlpha = ((switch (disposition.mood) {
              CyclePetMood.playful => 0.28,
              CyclePetMood.cozy => 0.24,
              CyclePetMood.gentle => 0.20,
              _ => 0.15,
            }) +
            disposition.familiarity * 0.04 +
            (disposition.recentlyPetted ? 0.035 : 0.0))
        .clamp(0.0, 0.38);
    final blush = Paint()
      ..color = palette.rose.withValues(alpha: blushAlpha);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-20, 10), width: 9, height: 4),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(20, 10), width: 9, height: 4),
      blush,
    );

    final mouth = Paint()
      ..color = dark ? const Color(0xFF49364E) : const Color(0xFF5B405F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final smile = (switch (disposition.mood) {
          CyclePetMood.playful => 4.4,
          CyclePetMood.bright => 3.6,
          CyclePetMood.curious => 2.6,
          CyclePetMood.cozy => 2.4,
          CyclePetMood.gentle => 2.0,
          CyclePetMood.calm => 2.2,
          CyclePetMood.drowsy => 1.2,
        }) +
        petted * 2.2;
    final mouthPath = Path()
      ..moveTo(-5, 9)
      ..quadraticBezierTo(0, 9 + smile, 5, 9);
    canvas.drawPath(mouthPath, mouth);
  }

  void _paintAffection(Canvas canvas, double t, double lean) {
    final rise = Curves.easeOut.transform(t.clamp(0.0, 1.0));
    final opacity = math.sin(math.pi * t).clamp(0.0, 1.0);
    final heartPaint = Paint()
      ..color = palette.rose.withValues(alpha: 0.56 * opacity);
    final side = lean >= 0 ? 1.0 : -1.0;
    _heart(
      canvas,
      Offset(95 + side * 41, 57 - rise * 28),
      4.5 + rise,
      heartPaint,
    );
    _heart(
      canvas,
      Offset(95 - side * 34, 70 - rise * 19),
      3.3 + rise * 0.6,
      heartPaint,
    );
  }

  void _heart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.85)
      ..cubicTo(
        center.dx - size * 1.35,
        center.dy,
        center.dx - size * 0.72,
        center.dy - size,
        center.dx,
        center.dy - size * 0.2,
      )
      ..cubicTo(
        center.dx + size * 0.72,
        center.dy - size,
        center.dx + size * 1.35,
        center.dy,
        center.dx,
        center.dy + size * 0.85,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CyclePetPainter oldDelegate) =>
      oldDelegate.disposition != disposition ||
      oldDelegate.palette != palette ||
      oldDelegate.dark != dark ||
      oldDelegate.reaction != reaction ||
      oldDelegate.petting != petting ||
      oldDelegate.petLean != petLean ||
      oldDelegate.petDepth != petDepth ||
      oldDelegate.reactionLean != reactionLean;
}
