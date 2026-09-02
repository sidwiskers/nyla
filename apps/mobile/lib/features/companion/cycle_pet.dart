import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/theme/nyla_theme.dart';
import 'cycle_pet_behavior.dart';
import 'cycle_pet_state.dart';

const _petCanvasWidth = 190.0;
const _petCanvasHeight = 132.0;
const _petDisplayWidth = 152.0;
const _petDisplayHeight = 102.0;
const _ledgeTop = 86.0;
const _motionSamplePeriod = Duration(milliseconds: 180);

/// A real little home for Nyla's companion: the main cycle card is the ledge.
///
/// The cat lives on the card edge instead of occupying its own large content
/// block. The card remains the information surface; the cat can move, settle,
/// be petted, cuddled and deliberately picked up without turning Today into a
/// game screen.
class CyclePetLedge extends StatefulWidget {
  const CyclePetLedge({
    required this.disposition,
    required this.child,
    this.onPetted,
    this.enableDeviceMotion = true,
    super.key,
  });

  final CyclePetDisposition disposition;
  final Widget child;
  final VoidCallback? onPetted;

  /// Tiny accelerometer-driven body bias. It is event-throttled, bounded and
  /// only subscribed while Today is active. Tests can disable it explicitly.
  final bool enableDeviceMotion;

  @override
  State<CyclePetLedge> createState() => _CyclePetLedgeState();
}

class _CyclePetLedgeState extends State<CyclePetLedge>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _blinkController;
  late final AnimationController _actionController;
  late final Listenable _repaint;
  final math.Random _random = math.Random();

  Timer? _idleTimer;
  // This subscription is explicitly cancelled whenever the pet is inactive
  // and again in dispose(). The lint cannot follow that helper lifecycle.
  // ignore: cancel_subscriptions
  StreamSubscription<AccelerometerEvent>? _motionSubscription;
  CyclePetAction? _action;
  CyclePetAction? _lastAction;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;
  bool _foreground = true;
  bool _petting = false;
  bool _holding = false;
  bool _carrying = false;
  bool _petHapticSent = false;
  double _petLean = 0;
  double _petDepth = 0;
  double _reactionLean = 0;
  double _ledgeX = 0;
  double _carryY = 0;
  double _motionX = 0;
  double _motionY = 0;
  double? _motionBaseX;
  double? _motionBaseY;
  Offset _lastCarryOffset = Offset.zero;
  Duration _ledgeMotionDuration = Duration.zero;
  DateTime? _lastTapAt;
  DateTime? _lastPickupAt;
  int _rapidTapCount = 0;
  int _rapidPickupCount = 0;
  int _actionEpoch = 0;

  bool get _autonomousMotion =>
      !_reduceMotion && _tickerEnabled && _foreground;

  bool get _canUseDeviceMotion =>
      widget.enableDeviceMotion &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  CyclePetBehaviorProfile get _behavior => cyclePetBehavior(widget.disposition);

  String get _interactionState {
    if (_carrying) return 'carrying';
    if (_holding) return 'cuddling';
    if (_petting) return 'petting';
    return _action?.name ?? 'idle';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _ledgeX = _initialLedgePosition(widget.disposition.variant);
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 115),
      reverseDuration: const Duration(milliseconds: 125),
    );
    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _repaint = Listenable.merge([_blinkController, _actionController]);
  }

  @override
  void didUpdateWidget(covariant CyclePetLedge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disposition != widget.disposition && _autonomousMotion) {
      _scheduleIdle();
    }
    if (oldWidget.enableDeviceMotion != widget.enableDeviceMotion) {
      _syncMotionSubscription();
    }
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
      _syncMotionSubscription();
      return;
    }
    if (changed || _idleTimer == null) _scheduleIdle();
    _syncMotionSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      if (_autonomousMotion) _scheduleIdle();
      _syncMotionSubscription();
      return;
    }
    _resetMotionState();
    _syncMotionSubscription();
  }

  double _initialLedgePosition(int variant) => switch (variant % 3) {
        0 => -0.34,
        1 => 0.08,
        _ => 0.36,
      };

  void _syncMotionSubscription() {
    final shouldListen = _canUseDeviceMotion && _autonomousMotion;
    if (!shouldListen) {
      final subscription = _motionSubscription;
      _motionSubscription = null;
      if (subscription != null) unawaited(subscription.cancel());
      _motionBaseX = null;
      _motionBaseY = null;
      _motionX = 0;
      _motionY = 0;
      return;
    }
    if (_motionSubscription != null) return;

    try {
      _motionSubscription = accelerometerEventStream(
        samplingPeriod: _motionSamplePeriod,
      ).listen(
        _onDeviceMotion,
        onError: (_) {
          _motionSubscription = null;
          _motionBaseX = null;
          _motionBaseY = null;
        },
        cancelOnError: true,
      );
    } catch (_) {
      _motionSubscription = null;
    }
  }

  void _onDeviceMotion(AccelerometerEvent event) {
    if (!mounted ||
        !_autonomousMotion ||
        _carrying ||
        _petting ||
        _holding) {
      return;
    }

    _motionBaseX ??= event.x;
    _motionBaseY ??= event.y;
    final targetX = ((event.x - _motionBaseX!) / 4.8).clamp(-1.0, 1.0);
    final targetY = ((event.y - _motionBaseY!) / 5.6).clamp(-1.0, 1.0);
    final nextX = _motionX + (targetX - _motionX) * 0.22;
    final nextY = _motionY + (targetY - _motionY) * 0.18;
    if ((nextX - _motionX).abs() < 0.025 &&
        (nextY - _motionY).abs() < 0.025) {
      return;
    }

    setState(() {
      _motionX = nextX.toDouble();
      _motionY = nextY.toDouble();
    });
  }

  void _resetMotionState() {
    _actionEpoch++;
    _idleTimer?.cancel();
    _idleTimer = null;
    _blinkController.stop(canceled: false);
    _actionController.stop(canceled: false);
    _blinkController.value = 0;
    _actionController.value = 0;
    _action = null;
    _reactionLean = 0;
    _petting = false;
    _holding = false;
    _carrying = false;
    _petHapticSent = false;
    _petLean = 0;
    _petDepth = 0;
    _carryY = 0;
    _lastCarryOffset = Offset.zero;
    _motionX = 0;
    _motionY = 0;
    _ledgeMotionDuration = Duration.zero;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionEpoch++;
    _idleTimer?.cancel();
    final motionSubscription = _motionSubscription;
    _motionSubscription = null;
    if (motionSubscription != null) unawaited(motionSubscription.cancel());
    _blinkController.stop(canceled: false);
    _actionController.stop(canceled: false);
    _blinkController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    if (!_autonomousMotion || !mounted || _carrying) return;

    final profile = _behavior;
    final spread = math.max(
      1,
      profile.maxIdleMilliseconds - profile.minIdleMilliseconds,
    );
    final milliseconds =
        profile.minIdleMilliseconds + _random.nextInt(spread + 1);

    _idleTimer = Timer(Duration(milliseconds: milliseconds), () async {
      if (!mounted ||
          !_autonomousMotion ||
          _petting ||
          _holding ||
          _carrying) {
        return;
      }
      if (_actionController.isAnimating || _blinkController.isAnimating) {
        _scheduleIdle();
        return;
      }

      if (_random.nextDouble() < profile.blinkChance) {
        await _blink();
      } else {
        await _runAction(_chooseAction(profile.idleActions), haptic: false);
      }
      if (mounted && _autonomousMotion) _scheduleIdle();
    });
  }

  CyclePetAction _chooseAction(List<CyclePetAction> pool) {
    assert(pool.isNotEmpty);
    var selected = pool[_random.nextInt(pool.length)];
    if (pool.length > 1 && selected == _lastAction) {
      for (var attempt = 0; attempt < 3; attempt++) {
        final candidate = pool[_random.nextInt(pool.length)];
        if (candidate != _lastAction) {
          selected = candidate;
          break;
        }
      }
    }

    final range = 0.30 + _behavior.roaming * 0.44;
    if (selected == CyclePetAction.hopLeft && _ledgeX <= -range + 0.08) {
      return CyclePetAction.hopRight;
    }
    if (selected == CyclePetAction.hopRight && _ledgeX >= range - 0.08) {
      return CyclePetAction.hopLeft;
    }
    return selected;
  }

  Future<void> _blink() async {
    if (_blinkController.isAnimating || !mounted || !_autonomousMotion) return;
    await _blinkController.forward(from: 0);
    if (!mounted || !_autonomousMotion) return;
    await _blinkController.reverse();
  }

  Future<void> _runAction(
    CyclePetAction action, {
    required bool haptic,
  }) async {
    if (!mounted ||
        _petting ||
        _holding ||
        _carrying ||
        !_autonomousMotion) {
      return;
    }
    _idleTimer?.cancel();

    // Autonomous work never steals the controller from an action already in
    // progress. A deliberate user reaction may take ownership immediately.
    if (_actionController.isAnimating) {
      if (!haptic) return;
      _actionEpoch++;
      _actionController.stop(canceled: false);
      _actionController.value = 0;
      setState(() => _action = null);
    }

    final epoch = ++_actionEpoch;
    if (haptic) await NylaHaptics.select();
    if (!mounted ||
        epoch != _actionEpoch ||
        _petting ||
        _holding ||
        _carrying ||
        !_autonomousMotion) {
      return;
    }

    final prepared = _prepareLedgeAction(action);
    final duration = cyclePetActionDuration(prepared);
    _actionController.duration = duration;
    setState(() {
      _action = prepared;
      _lastAction = prepared;
      _ledgeMotionDuration = duration;
      _moveAlongLedge(prepared);
    });

    await _actionController.forward(from: 0);
    if (!mounted ||
        epoch != _actionEpoch ||
        _petting ||
        _holding ||
        _carrying ||
        !_autonomousMotion) {
      return;
    }

    setState(() {
      _action = null;
      _reactionLean = 0;
    });
    _actionController.value = 0;
    _scheduleIdle();
  }

  CyclePetAction _prepareLedgeAction(CyclePetAction action) {
    final range = 0.30 + _behavior.roaming * 0.44;
    if (action == CyclePetAction.hopLeft && _ledgeX <= -range + 0.08) {
      return CyclePetAction.hopRight;
    }
    if (action == CyclePetAction.hopRight && _ledgeX >= range - 0.08) {
      return CyclePetAction.hopLeft;
    }
    return action;
  }

  void _moveAlongLedge(CyclePetAction action) {
    final roaming = _behavior.roaming;
    final range = 0.30 + roaming * 0.44;
    final step = 0.18 + roaming * 0.26;
    if (action == CyclePetAction.hopLeft) {
      _ledgeX = (_ledgeX - step).clamp(-range, range).toDouble();
    } else if (action == CyclePetAction.hopRight) {
      _ledgeX = (_ledgeX + step).clamp(-range, range).toDouble();
    }
  }

  void _interruptForTouch({required double lean, double depth = 0.08}) {
    _actionEpoch++;
    _idleTimer?.cancel();
    _actionController.stop(canceled: false);
    _actionController.value = 0;
    setState(() {
      _action = null;
      _petting = true;
      _petHapticSent = false;
      _petDepth = depth;
      _petLean = lean;
      _reactionLean = lean;
    });
  }

  double _leanForX(double x) =>
      (((x / _petDisplayWidth).clamp(0.0, 1.0) - 0.5) * 2)
          .clamp(-1.0, 1.0)
          .toDouble();

  void _onPetStart(DragStartDetails details) {
    _holding = false;
    _interruptForTouch(lean: _leanForX(details.localPosition.dx));
  }

  void _onPetUpdate(DragUpdateDetails details) {
    if (_carrying) return;
    final lean = _leanForX(details.localPosition.dx);
    final nextDepth =
        (_petDepth + details.delta.dx.abs() / 76).clamp(0.0, 1.0).toDouble();

    if (!_petHapticSent && nextDepth >= 0.42) {
      _petHapticSent = true;
      unawaited(NylaHaptics.select());
    }

    setState(() {
      _petLean = lean;
      _reactionLean = lean;
      _petDepth = nextDepth;
    });
  }

  void _onPetEnd(DragEndDetails _) => _finishPet(force: false);

  void _onLongPressStart(LongPressStartDetails details) {
    _holding = true;
    _lastCarryOffset = Offset.zero;
    _interruptForTouch(
      lean: _leanForX(details.localPosition.dx),
      depth: 0.62,
    );
    _holding = true;
    _petHapticSent = true;
    unawaited(NylaHaptics.select());
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    // Use the gesture's global offset. Local coordinates move with the cat
    // while she is being transformed, which would otherwise make the finger
    // appear to stop moving relative to the pet mid-carry.
    final offset = details.offsetFromOrigin;
    if (!_carrying && offset.distance >= 12) {
      _beginCarry(offset);
      return;
    }
    if (!_carrying) {
      setState(() {
        _petLean = _leanForX(details.localPosition.dx);
        _reactionLean = _petLean;
        _petDepth =
            (0.62 + offset.distance / 80).clamp(0.62, 1.0).toDouble();
      });
      return;
    }

    final delta = offset - _lastCarryOffset;
    _lastCarryOffset = offset;
    setState(() {
      _ledgeMotionDuration = Duration.zero;
      _ledgeX = (_ledgeX + delta.dx / 165).clamp(-0.78, 0.78).toDouble();
      _carryY = (offset.dy - 16).clamp(-58.0, -12.0).toDouble();
      _reactionLean = (delta.dx / 22).clamp(-1.0, 1.0).toDouble();
    });
  }

  void _beginCarry(Offset offset) {
    _actionEpoch++;
    _idleTimer?.cancel();
    _actionController.stop(canceled: false);
    _actionController.value = 0;
    _registerPickup();
    setState(() {
      _action = null;
      _petting = false;
      _holding = false;
      _carrying = true;
      _petDepth = 0;
      _petLean = 0;
      _lastCarryOffset = offset;
      _carryY = (offset.dy - 16).clamp(-58.0, -12.0).toDouble();
      _ledgeMotionDuration = Duration.zero;
    });
    unawaited(NylaHaptics.select());
  }

  void _registerPickup() {
    final now = DateTime.now();
    if (_lastPickupAt != null &&
        now.difference(_lastPickupAt!) < const Duration(milliseconds: 1700)) {
      _rapidPickupCount++;
    } else {
      _rapidPickupCount = 1;
    }
    _lastPickupAt = now;
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_carrying) {
      _finishCarry(details.velocity.pixelsPerSecond);
      return;
    }
    _holding = false;
    _finishPet(force: true, love: true);
  }

  void _finishCarry(Offset velocity) {
    final rough = velocity.distance > 1150 || _rapidPickupCount >= 3;
    final lean = _reactionLean;
    setState(() {
      _carrying = false;
      _petting = false;
      _holding = false;
      _petHapticSent = false;
      _petLean = 0;
      _petDepth = 0;
      _carryY = 0;
      _reactionLean = lean;
      _ledgeMotionDuration = const Duration(milliseconds: 390);
    });

    if (_reduceMotion) {
      _scheduleIdle();
      return;
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 360), () {
        if (!mounted || !_autonomousMotion || _carrying) return;
        unawaited(
          _runAction(
            rough ? CyclePetAction.annoyed : CyclePetAction.shakeOff,
            haptic: false,
          ),
        );
      }),
    );
  }

  void _cancelTouch() {
    if (!_petting && !_holding && !_carrying) return;
    _actionEpoch++;
    setState(() {
      _petting = false;
      _holding = false;
      _carrying = false;
      _petHapticSent = false;
      _petLean = 0;
      _petDepth = 0;
      _carryY = 0;
      _reactionLean = 0;
      _lastCarryOffset = Offset.zero;
      _ledgeMotionDuration = const Duration(milliseconds: 320);
    });
    _scheduleIdle();
  }

  void _finishPet({required bool force, bool love = false}) {
    final lean = _petLean;
    final wasPet = force || _petDepth >= 0.28;
    setState(() {
      _petting = false;
      _holding = false;
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
    unawaited(
      _runAction(
        love ? CyclePetAction.love : CyclePetAction.purr,
        haptic: false,
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    _reactionLean = _leanForX(details.localPosition.dx);
  }

  bool _tapHasAnnoyedHer() {
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!) < const Duration(milliseconds: 850)) {
      _rapidTapCount++;
    } else {
      _rapidTapCount = 1;
    }
    _lastTapAt = now;
    if (_rapidTapCount < 4) return false;
    _rapidTapCount = 0;
    return true;
  }

  void _onTap() {
    if (_petting || _holding || _carrying) return;
    final annoyed = _tapHasAnnoyedHer();
    if (_reduceMotion) {
      unawaited(NylaHaptics.select());
      return;
    }
    unawaited(
      _runAction(
        annoyed
            ? CyclePetAction.annoyed
            : _chooseAction(_behavior.tapActions),
        haptic: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardMotion =
        _reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
    final ledgeMotion = _reduceMotion || _carrying
        ? Duration.zero
        : (_ledgeMotionDuration == Duration.zero
            ? const Duration(milliseconds: 640)
            : _ledgeMotionDuration);
    final carryLift = (-_carryY / 58).clamp(0.0, 1.0).toDouble();
    final motionDx = _reduceMotion || _carrying ? 0.0 : _motionX * 4.2;
    final motionDy = _reduceMotion || _carrying ? 0.0 : _motionY * 2.2;
    final petTransform = Matrix4.translationValues(
      motionDx,
      _carryY + motionDy,
      0,
    )..rotateZ((_carrying ? _reactionLean * 0.035 : _motionX * 0.018));

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _ledgeTop),
            child: AnimatedSize(
              duration: cardMotion,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: cardMotion,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                transitionBuilder: (card, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    alignment: Alignment.topCenter,
                    scale: Tween<double>(begin: 0.995, end: 1).animate(animation),
                    child: card,
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            top: 0,
            height: _petDisplayHeight,
            child: AnimatedAlign(
              key: const ValueKey('cycle-pet-ledge-position'),
              alignment: Alignment(_ledgeX, -1),
              duration: ledgeMotion,
              curve: const Cubic(0.16, 1, 0.3, 1),
              child: AnimatedContainer(
                duration: _reduceMotion || _carrying
                    ? Duration.zero
                    : const Duration(milliseconds: 360),
                curve: const Cubic(0.16, 1, 0.3, 1),
                transform: petTransform,
                transformAlignment: Alignment.center,
                child: Semantics(
                  button: true,
                  label:
                      'Your little Nyla cat, ${widget.disposition.semantics}. Tap her, stroke left and right, hold to cuddle, or hold and drag to pick her up.',
                  child: SizedBox(
                    key: const ValueKey('cycle-pet-touch-target'),
                    width: _petDisplayWidth,
                    height: _petDisplayHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: _onTapDown,
                      onTap: _onTap,
                      onHorizontalDragStart: _onPetStart,
                      onHorizontalDragUpdate: _onPetUpdate,
                      onHorizontalDragEnd: _onPetEnd,
                      onHorizontalDragCancel: _cancelTouch,
                      onLongPressStart: _onLongPressStart,
                      onLongPressMoveUpdate: _onLongPressMove,
                      onLongPressEnd: _onLongPressEnd,
                      onLongPressCancel: _cancelTouch,
                      child: KeyedSubtree(
                        key: ValueKey('cycle-pet-state-$_interactionState'),
                        child: CustomPaint(
                          painter: _CyclePetPainter(
                            disposition: widget.disposition,
                            palette: palette,
                            dark: dark,
                            blink: _blinkController,
                            actionAnimation: _actionController,
                            action: _action,
                            petting: _petting,
                            carrying: _carrying,
                            carryLift: carryLift,
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
            ),
          ),
        ],
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
    required this.actionAnimation,
    required this.action,
    required this.petting,
    required this.carrying,
    required this.carryLift,
    required this.petLean,
    required this.petDepth,
    required this.reactionLean,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final CyclePetDisposition disposition;
  final NylaPalette palette;
  final bool dark;
  final Animation<double> blink;
  final Animation<double> actionAnimation;
  final CyclePetAction? action;
  final bool petting;
  final bool carrying;
  final double carryLift;
  final double petLean;
  final double petDepth;
  final double reactionLean;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _petCanvasWidth,
      size.height / _petCanvasHeight,
    );
    final dx = (size.width - _petCanvasWidth * scale) / 2;
    final dy = (size.height - _petCanvasHeight * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final t = actionAnimation.value.clamp(0.0, 1.0).toDouble();
    final pulse = math.sin(math.pi * t);
    final wave = math.sin(math.pi * 2 * t);
    final hop = _isHop ? pulse : 0.0;
    final stretch = action == CyclePetAction.stretch ? pulse : 0.0;
    final settle = action == CyclePetAction.settle ? pulse : 0.0;
    final yawn = action == CyclePetAction.yawn ? pulse : 0.0;
    final groom = action == CyclePetAction.groom ? pulse : 0.0;
    final paw = action == CyclePetAction.paw ? pulse : 0.0;
    final peek = action == CyclePetAction.peek ? pulse : 0.0;
    final purr = action == CyclePetAction.purr ? pulse : 0.0;
    final nuzzle = action == CyclePetAction.nuzzle ? pulse : 0.0;
    final wink = action == CyclePetAction.wink ? pulse : 0.0;
    final love = action == CyclePetAction.love ? pulse : 0.0;
    final surprised = action == CyclePetAction.surprised ? pulse : 0.0;
    final annoyed = action == CyclePetAction.annoyed ? pulse : 0.0;
    final shakeOff = action == CyclePetAction.shakeOff ? pulse : 0.0;
    final shake = shakeOff * wave * 3.2 + annoyed * wave * 1.3;
    canvas.translate(shake, 0);

    final variantLean = switch (disposition.variant) {
      1 => -0.025,
      2 => 0.025,
      _ => 0.0,
    };
    final moodTilt = switch (disposition.mood) {
      CyclePetMood.curious => 0.055,
      CyclePetMood.playful => -0.035,
      CyclePetMood.gentle => 0.022,
      CyclePetMood.affectionate => -0.015,
      _ => 0.0,
    };
    final lookShift = switch (action) {
      CyclePetAction.lookLeft => -4.2 * pulse,
      CyclePetAction.lookRight => 4.2 * pulse,
      _ => 0.0,
    };
    final nod = action == CyclePetAction.nod ? 4.5 * pulse : 0.0;
    final nuzzleSide = reactionLean == 0
        ? (disposition.variant == 1 ? -1.0 : 1.0)
        : reactionLean.sign;
    final activeLean = petting
        ? petLean * 0.09
        : nuzzleSide * 0.055 * nuzzle +
            reactionLean * 0.025 * purr +
            annoyed * -0.035 * nuzzleSide;
    final headAngle = moodTilt + variantLean + activeLean;

    _paintContactShadow(
      canvas,
      hop: hop,
      settle: settle,
      carryLift: carryLift,
    );
    _paintTail(
      canvas,
      pulse: pulse,
      wave: wave,
      hop: hop,
      annoyed: annoyed,
      carrying: carrying,
    );
    _paintBody(
      canvas,
      hop: hop,
      stretch: stretch,
      settle: settle,
      purr: purr,
      carrying: carrying,
      carryLift: carryLift,
    );
    _paintHead(
      canvas,
      headAngle: headAngle,
      headShiftX: lookShift + nuzzleSide * 3.8 * nuzzle + stretch * 3.2,
      headShiftY: nod +
          petDepth * 1.8 +
          peek * 7.2 -
          hop * 5.2 +
          carryLift * 1.5,
      yawn: yawn,
      settle: settle,
      purr: purr,
      nuzzle: nuzzle,
      peek: peek,
      wink: wink,
      love: love,
      surprised: surprised,
      annoyed: annoyed,
      carrying: carrying,
    );
    if (groom > 0.01 || paw > 0.01) {
      _paintActionPaw(canvas, groom: groom, paw: paw, wave: wave, hop: hop);
    }
    if (purr > 0.04) _paintPurr(canvas, purr, wave);
    if ((purr > 0.06 || nuzzle > 0.06 || love > 0.06) && t < 0.95) {
      _paintAffection(
        canvas,
        t,
        nuzzleSide,
        strength: love > 0 ? 1.35 : 1,
      );
    }
    if (annoyed > 0.07) _paintAnnoyedMark(canvas, annoyed, wave);

    canvas.restore();
  }

  bool get _isHop =>
      action == CyclePetAction.hopLeft || action == CyclePetAction.hopRight;

  void _paintContactShadow(
    Canvas canvas, {
    required double hop,
    required double settle,
    required double carryLift,
  }) {
    final shadow = Paint()
      ..color = palette.shadow.withValues(
        alpha: (dark ? 0.22 : 0.13) *
            (1 - hop * 0.55) *
            (1 - carryLift * 0.78),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(95, 115),
        width: (76 + disposition.closeness * 10 + settle * 7 - hop * 8) *
            (1 - carryLift * 0.28),
        height: (8 - hop * 2) * (1 - carryLift * 0.38),
      ),
      shadow,
    );
  }

  void _paintTail(
    Canvas canvas, {
    required double pulse,
    required double wave,
    required double hop,
    required double annoyed,
    required bool carrying,
  }) {
    final energy = disposition.energy;
    final flick = action == CyclePetAction.tailFlick
        ? wave * 13
        : annoyed > 0
            ? wave * 17
            : 0.0;
    final playfulLift = disposition.mood == CyclePetMood.playful ? 2.5 : 0.0;
    final tailLift = 3 +
        energy * 13 +
        disposition.familiarity * 2 +
        (disposition.recentlyPetted ? 1.2 : 0) +
        playfulLift +
        hop * 4 +
        (carrying ? 3.5 : 0);
    final tail = Path()
      ..moveTo(126, 89 - hop * 3)
      ..cubicTo(
        151 + flick * 0.25,
        91 - hop * 2,
        151 + flick,
        72 - tailLift,
        139 + flick * 0.55,
        68 - tailLift * 0.34,
      );
    final tailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = dark ? const Color(0xFFB89CCF) : const Color(0xFFC8AFE0);
    canvas.drawPath(tail, tailPaint);
  }

  void _paintBody(
    Canvas canvas, {
    required double hop,
    required double stretch,
    required double settle,
    required double purr,
    required bool carrying,
    required double carryLift,
  }) {
    final squat = switch (disposition.mood) {
      CyclePetMood.drowsy => 4.0,
      CyclePetMood.cozy => 2.5,
      CyclePetMood.gentle => 2.0,
      CyclePetMood.affectionate => 1.6,
      _ => 0.0,
    };
    final purrWiggle =
        purr * math.sin(actionAnimation.value * math.pi * 6) * 0.6;
    final bodyRect = Rect.fromCenter(
      center: Offset(
        95 + purrWiggle,
        86 + squat + settle * 3.0 - hop * 5.0,
      ),
      width: 78 + disposition.closeness * 4 + stretch * 15 - settle * 3,
      height: 55 -
          disposition.energy * 4 +
          squat -
          stretch * 7 +
          settle * 4 +
          carryLift * 2,
    );
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFFBCA6D6), Color(0xFF987DB8)]
            : const [Color(0xFFE5D8F2), Color(0xFFD4C1E8)],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, body);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = palette.wine.withValues(alpha: dark ? 0.36 : 0.18);
    canvas.drawOval(bodyRect, outline);

    final pawPaint = Paint()
      ..color = dark ? const Color(0xFFAE93CA) : const Color(0xFFD7C4E9);
    final pawY = 109 - hop * 5 + settle * 1.5 + (carrying ? 3.5 : 0);
    final pawHeight = carrying ? 13.0 : 10.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(72 - stretch * 4, pawY),
        width: carrying ? 18 : 25,
        height: pawHeight,
      ),
      pawPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(112 + stretch * 4, pawY),
        width: carrying ? 18 : 25,
        height: pawHeight,
      ),
      pawPaint,
    );
  }

  void _paintHead(
    Canvas canvas, {
    required double headAngle,
    required double headShiftX,
    required double headShiftY,
    required double yawn,
    required double settle,
    required double purr,
    required double nuzzle,
    required double peek,
    required double wink,
    required double love,
    required double surprised,
    required double annoyed,
    required bool carrying,
  }) {
    canvas.save();
    canvas.translate(95 + headShiftX, 53 + headShiftY);
    canvas.rotate(headAngle);

    final energy = disposition.energy;
    final gentleDrop = switch (disposition.mood) {
      CyclePetMood.gentle => 0.72,
      CyclePetMood.drowsy => 0.62,
      CyclePetMood.cozy => 0.35,
      CyclePetMood.affectionate => 0.32,
      _ => 0.0,
    };
    final touchDrop = petting ? petDepth * 0.48 : purr * 0.24 + nuzzle * 0.18;
    final yawnDrop = yawn * 0.32;
    final annoyedDrop = annoyed * 0.98;
    final carryLift = carrying || surprised > 0.12 ? -0.16 : 0.0;
    final earDrop = (math.max(
              gentleDrop,
              math.max(touchDrop, math.max(yawnDrop, annoyedDrop)),
            ) +
            carryLift)
        .clamp(0.0, 1.0)
        .toDouble();

    _paintEar(canvas, left: true, drop: earDrop, energy: energy);
    _paintEar(canvas, left: false, drop: earDrop * 0.82, energy: energy);

    final headRect = Rect.fromCenter(
      center: Offset.zero,
      width: 65 + nuzzle * 1.2,
      height: 58 - purr * 1.1 + settle * 1.2,
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
    _paintFace(
      canvas,
      yawn: yawn,
      settle: settle,
      purr: purr,
      nuzzle: nuzzle,
      peek: peek,
      wink: wink,
      love: love,
      surprised: surprised,
      annoyed: annoyed,
      carrying: carrying,
    );
    _paintWhiskers(canvas, peek: peek);
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

  void _paintFace(
    Canvas canvas, {
    required double yawn,
    required double settle,
    required double purr,
    required double nuzzle,
    required double peek,
    required double wink,
    required double love,
    required double surprised,
    required double annoyed,
    required bool carrying,
  }) {
    final ink = dark ? const Color(0xFF392C40) : const Color(0xFF4A3650);
    final eyePaint = Paint()
      ..color = ink
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    if (annoyed > 0.20) {
      final line = Paint()
        ..color = ink
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-15, -1), const Offset(-8, 2), line);
      canvas.drawLine(const Offset(8, 2), const Offset(15, -1), line);
    } else if (love > 0.24) {
      final heartPaint = Paint()
        ..color = palette.rose.withValues(alpha: 0.82);
      _heart(canvas, const Offset(-11, 0), 3.5, heartPaint);
      _heart(canvas, const Offset(11, 0), 3.5, heartPaint);
    } else if (carrying || surprised > 0.16) {
      final radius = 3.0 + surprised * 0.7;
      canvas.drawCircle(const Offset(-11, 0), radius, eyePaint);
      canvas.drawCircle(const Offset(11, 0), radius, eyePaint);
      final shine = Paint()..color = Colors.white.withValues(alpha: 0.72);
      canvas.drawCircle(const Offset(-10, -1), 0.9, shine);
      canvas.drawCircle(const Offset(12, -1), 0.9, shine);
    } else {
      final moodOpen = switch (disposition.mood) {
        CyclePetMood.drowsy => 0.38,
        CyclePetMood.cozy => 0.72,
        CyclePetMood.gentle => 0.70,
        CyclePetMood.calm => 0.78,
        CyclePetMood.affectionate => 0.74,
        _ => 1.0,
      };
      final blinkClose = math.sin(math.pi * blink.value);
      final touchClose = petting ? petDepth * 0.78 : 0.0;
      final actionClose =
          yawn * 0.82 + settle * 0.68 + purr * 0.72 + nuzzle * 0.50;
      final peekBoost = peek * 0.18;
      final eyeOpen = (moodOpen *
                  (1 - blinkClose) *
                  (1 - touchClose) *
                  (1 - actionClose) +
              peekBoost)
          .clamp(0.05, 1.08)
          .toDouble();

      for (var i = 0; i < 2; i++) {
        final x = i == 0 ? -11.0 : 11.0;
        final winkThisEye = i == 1 && wink > 0.38;
        if (eyeOpen < 0.34 || winkThisEye) {
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
    }

    final blushAlpha = ((switch (disposition.mood) {
              CyclePetMood.playful => 0.28,
              CyclePetMood.cozy => 0.24,
              CyclePetMood.gentle => 0.20,
              CyclePetMood.affectionate => 0.31,
              _ => 0.15,
            }) +
            disposition.familiarity * 0.04 +
            (disposition.recentlyPetted ? 0.035 : 0.0) +
            purr * 0.05 +
            love * 0.08)
        .clamp(0.0, 0.44)
        .toDouble();
    final blush = Paint()..color = palette.rose.withValues(alpha: blushAlpha);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-20, 10), width: 9, height: 4),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(20, 10), width: 9, height: 4),
      blush,
    );

    if (yawn > 0.16) {
      final mouthPaint = Paint()..color = ink;
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, 12),
          width: 6.5 + yawn * 2.2,
          height: 3 + yawn * 8.5,
        ),
        mouthPaint,
      );
      return;
    }

    if (carrying || surprised > 0.20) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0, 11),
          width: 4.6,
          height: 5.8,
        ),
        Paint()..color = ink,
      );
      return;
    }

    final mouth = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    if (annoyed > 0.18) {
      final frown = Path()
        ..moveTo(-5, 12)
        ..quadraticBezierTo(0, 8.5, 5, 12);
      canvas.drawPath(frown, mouth);
      return;
    }

    final smile = (switch (disposition.mood) {
          CyclePetMood.playful => 4.4,
          CyclePetMood.bright => 3.6,
          CyclePetMood.curious => 2.6,
          CyclePetMood.cozy => 2.4,
          CyclePetMood.gentle => 2.0,
          CyclePetMood.calm => 2.2,
          CyclePetMood.drowsy => 1.2,
          CyclePetMood.affectionate => 3.8,
        }) +
        purr * 1.8 +
        nuzzle * 1.0 +
        love * 1.5 +
        (petting ? petDepth * 1.4 : 0.0);
    final mouthPath = Path()
      ..moveTo(-5, 9)
      ..quadraticBezierTo(0, 9 + smile, 5, 9);
    canvas.drawPath(mouthPath, mouth);
  }

  void _paintWhiskers(Canvas canvas, {required double peek}) {
    final whisker = Paint()
      ..color = palette.wine.withValues(alpha: dark ? 0.24 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final reach = 1 + peek * 0.12;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(side * 24, 6),
        Offset(side * 34 * reach, 3),
        whisker,
      );
      canvas.drawLine(
        Offset(side * 24, 9),
        Offset(side * 35 * reach, 11),
        whisker,
      );
    }
  }

  void _paintActionPaw(
    Canvas canvas, {
    required double groom,
    required double paw,
    required double wave,
    required double hop,
  }) {
    final limb = Paint()
      ..color = dark ? const Color(0xFFB39ACA) : const Color(0xFFDCCBED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    if (groom > 0.01) {
      final side = disposition.variant == 1 ? -1.0 : 1.0;
      final sway = wave * 2.4;
      canvas.drawLine(
        Offset(94 + side * 19, 87 - hop * 4),
        Offset(95 + side * (10 + sway), 55 - groom * 8),
        limb,
      );
      return;
    }

    if (paw > 0.01) {
      final side = reactionLean == 0
          ? (disposition.variant == 0 ? -1.0 : 1.0)
          : reactionLean.sign;
      canvas.drawLine(
        Offset(94 + side * 18, 88 - hop * 4),
        Offset(95 + side * (25 + paw * 6), 106 + paw * 9),
        limb,
      );
      canvas.drawCircle(
        Offset(95 + side * (25 + paw * 6), 108 + paw * 9),
        5.2,
        Paint()..color = limb.color,
      );
    }
  }

  void _paintPurr(Canvas canvas, double strength, double wave) {
    final paint = Paint()
      ..color = palette.violet.withValues(alpha: 0.28 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final offset = wave * 1.2;
    for (var i = 0; i < 2; i++) {
      final x = 139 + i * 6.0;
      final path = Path()
        ..moveTo(x, 67 + offset)
        ..quadraticBezierTo(x + 5, 72, x, 77 - offset);
      canvas.drawPath(path, paint);
    }
  }

  void _paintAffection(
    Canvas canvas,
    double t,
    double side, {
    required double strength,
  }) {
    final rise = Curves.easeOut.transform(t.clamp(0.0, 1.0).toDouble());
    final opacity = math.sin(math.pi * t).clamp(0.0, 1.0).toDouble();
    final heartPaint = Paint()
      ..color = palette.rose.withValues(alpha: 0.56 * opacity);
    final direction = side >= 0 ? 1.0 : -1.0;
    _heart(
      canvas,
      Offset(95 + direction * 41, 57 - rise * 28),
      (4.5 + rise) * strength,
      heartPaint,
    );
    _heart(
      canvas,
      Offset(95 - direction * 34, 70 - rise * 19),
      (3.3 + rise * 0.6) * strength,
      heartPaint,
    );
    if (strength > 1.1) {
      _heart(
        canvas,
        Offset(95 + direction * 18, 43 - rise * 34),
        3.0 + rise * 0.8,
        heartPaint,
      );
    }
  }

  void _paintAnnoyedMark(Canvas canvas, double strength, double wave) {
    final paint = Paint()
      ..color = const Color(0xFFE45A68).withValues(alpha: 0.78 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final dx = wave * 0.8;
    final center = Offset(137 + dx, 31 - strength * 3);
    canvas.drawLine(
      center + const Offset(-8, 0),
      center + const Offset(-2, 0),
      paint,
    );
    canvas.drawLine(
      center + const Offset(-2, 0),
      center + const Offset(-2, -6),
      paint,
    );
    canvas.drawLine(
      center + const Offset(3, -7),
      center + const Offset(3, -1),
      paint,
    );
    canvas.drawLine(
      center + const Offset(3, -1),
      center + const Offset(9, -1),
      paint,
    );
    canvas.drawLine(
      center + const Offset(-7, 5),
      center + const Offset(-2, 5),
      paint,
    );
    canvas.drawLine(
      center + const Offset(-2, 5),
      center + const Offset(-2, 10),
      paint,
    );
    canvas.drawLine(
      center + const Offset(3, 4),
      center + const Offset(3, 9),
      paint,
    );
    canvas.drawLine(
      center + const Offset(3, 9),
      center + const Offset(8, 9),
      paint,
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
      oldDelegate.action != action ||
      oldDelegate.petting != petting ||
      oldDelegate.carrying != carrying ||
      oldDelegate.carryLift != carryLift ||
      oldDelegate.petLean != petLean ||
      oldDelegate.petDepth != petDepth ||
      oldDelegate.reactionLean != reactionLean;
}
