import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _silkCurve = Cubic(0.16, 1, 0.3, 1);
const _depthEnterCurve = Cubic(0.16, 1, 0.3, 1);
const _depthExitCurve = Cubic(0.7, 0, 0.84, 0);

/// Bottom-navigation destinations have one spatial order. Keeping that order
/// explicit makes the motion model predictable in tests and deep links.
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
  // StatefulShellRoute owns section motion. Branch-root pages therefore have
  // no navigator transition of their own; two animation owners caused the old
  // hitch/ghost effect.
  return NoTransitionPage<void>(key: key, child: child);
}

Page<void> nylaDepthPage({
  required LocalKey key,
  required Widget child,
  bool modal = false,
}) {
  return CustomTransitionPage<void>(
    key: key,
    fullscreenDialog: modal,
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

/// Persistent branch container for the five primary sections.
///
/// Every branch keeps its own Navigator in the tree, so scroll position and
/// local route state survive tab switches. Inactive branches sit a tiny amount
/// toward their physical side of the nav bar. When selected they glide to the
/// center, fade in and settle from 0.992 scale. Animated* widgets retarget from
/// their current value when taps are interrupted, which makes rapid tab changes
/// continuous instead of restarting from a hard-coded pose.
class NylaBranchMotion extends StatelessWidget {
  const NylaBranchMotion({
    required this.currentIndex,
    required this.children,
    required this.reduceMotion,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    assert(currentIndex >= 0 && currentIndex < children.length);
    final movementDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 330);
    final fadeDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 235);

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < children.length; index++)
          _BranchSurface(
            key: ValueKey('nyla-branch-$index'),
            active: index == currentIndex,
            side: index < currentIndex ? -1 : 1,
            movementDuration: movementDuration,
            fadeDuration: fadeDuration,
            child: children[index],
          ),
      ],
    );
  }
}

class _BranchSurface extends StatelessWidget {
  const _BranchSurface({
    required this.active,
    required this.side,
    required this.movementDuration,
    required this.fadeDuration,
    required this.child,
    super.key,
  });

  final bool active;
  final int side;
  final Duration movementDuration;
  final Duration fadeDuration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final restingOffset = Offset(side * 0.026, 0.0025);

    return AnimatedSlide(
      offset: active ? Offset.zero : restingOffset,
      duration: movementDuration,
      curve: _silkCurve,
      child: AnimatedScale(
        scale: active ? 1 : 0.992,
        duration: movementDuration,
        curve: _silkCurve,
        alignment: Alignment.center,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: fadeDuration,
          curve: active ? _silkCurve : Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !active,
            child: ExcludeSemantics(
              excluding: !active,
              child: TickerMode(
                enabled: active,
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
