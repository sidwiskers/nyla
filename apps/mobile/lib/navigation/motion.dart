import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _sectionEnterCurve = Cubic(0.16, 1, 0.3, 1);
const _depthEnterCurve = Cubic(0.16, 1, 0.3, 1);
const _depthExitCurve = Cubic(0.7, 0, 0.84, 0);

/// Bottom-navigation destinations have one spatial order. Keeping that order
/// in one place lets section motion feel directional instead of random.
int nylaSectionIndex(String location) {
  if (location.startsWith('/calendar')) return 1;
  if (location.startsWith('/log')) return 2;
  if (location.startsWith('/insights')) return 3;
  if (location.startsWith('/learn')) return 4;
  return 0;
}

int nylaTravelDirection({required int from, required int to}) {
  if (to == from) return 0;
  return to > from ? 1 : -1;
}

Page<void> nylaSectionPage({
  required LocalKey key,
  required Widget child,
}) {
  // The shell is the sole owner of section-to-section animation. Using a
  // NoTransitionPage here prevents a second Material route animation from
  // running underneath the shell and causing ghosting/hitches.
  return NoTransitionPage<void>(key: key, child: child);
}

Page<void> nylaDepthPage({
  required LocalKey key,
  required Widget child,
  bool modal = false,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 290),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      if (MediaQuery.disableAnimationsOf(context)) return pageChild;

      final primary = CurvedAnimation(
        parent: animation,
        curve: _depthEnterCurve,
        reverseCurve: _depthExitCurve,
      );
      final covered = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return AnimatedBuilder(
        animation: Listenable.merge([primary, covered]),
        child: RepaintBoundary(child: pageChild),
        builder: (context, child) {
          final enter = primary.value.clamp(0.0, 1.0).toDouble();
          final cover = covered.value.clamp(0.0, 1.0).toDouble();

          final baseScale = modal ? 0.986 : 0.992;
          final entranceScale = baseScale + ((1 - baseScale) * enter);
          final coveredScale = 1 - (0.008 * cover);
          final opacity =
              (enter * (1 - (0.07 * cover))).clamp(0.0, 1.0).toDouble();
          final dx = modal ? 0.0 : 0.018 * (1 - enter);
          final dy =
              (modal ? 0.045 : 0.014) * (1 - enter) - (0.004 * cover);

          return Opacity(
            opacity: opacity,
            child: FractionalTranslation(
              translation: Offset(dx, dy),
              child: Transform.scale(
                scale: entranceScale * coveredScale,
                alignment: modal ? Alignment.bottomCenter : Alignment.center,
                child: child,
              ),
            ),
          );
        },
      );
    },
  );
}

/// Nyla's section handoff: the incoming surface follows the physical order of
/// the nav bar, while the outgoing surface simply recedes. That asymmetry is
/// intentional: it preserves spatial direction without making two large pages
/// cross-slide through one another.
class NylaSectionMotion extends StatelessWidget {
  const NylaSectionMotion({
    required this.identity,
    required this.direction,
    required this.reduceMotion,
    required this.child,
    super.key,
  });

  final String identity;
  final int direction;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = _SectionFrame(
      key: ValueKey(identity),
      direction: direction == 0 ? 1 : direction,
      child: child,
    );

    if (reduceMotion) return frame;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 225),
      layoutBuilder: (currentChild, previousChildren) {
        // Only the most recent outgoing surface remains visible. AnimatedSwitcher
        // may retain several children after rapid taps; drawing all of them is
        // the classic source of translucent page "ghosts".
        final latestPrevious =
            previousChildren.isEmpty ? null : previousChildren.last;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (latestPrevious != null) latestPrevious,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (transitionChild, animation) {
        final transitionFrame = transitionChild as _SectionFrame;
        return _SectionMotionTransition(
          animation: animation,
          direction: transitionFrame.direction,
          child: transitionFrame,
        );
      },
      child: frame,
    );
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.direction,
    required this.child,
    super.key,
  });

  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}

class _SectionMotionTransition extends StatelessWidget {
  const _SectionMotionTransition({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final raw = animation.value.clamp(0.0, 1.0).toDouble();
        final exiting = animation.status == AnimationStatus.reverse;
        final progress = exiting
            ? Curves.easeOutCubic.transform(raw)
            : _sectionEnterCurve.transform(raw);

        // Exiting pages recede instead of cross-sliding. This keeps direction
        // correct even when the user taps through several tabs very quickly.
        final dx = exiting ? 0.0 : direction * 0.042 * (1 - progress);
        final dy =
            exiting ? -0.005 * (1 - progress) : 0.005 * (1 - progress);
        final scale = exiting
            ? 0.993 + (0.007 * progress)
            : 0.985 + (0.015 * progress);
        final opacity = exiting
            ? progress
            : ((progress - 0.015) / 0.985).clamp(0.0, 1.0).toDouble();

        return Opacity(
          opacity: opacity,
          child: FractionalTranslation(
            translation: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
