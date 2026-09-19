import 'package:flutter/material.dart';

/// Fade-through page transition: the old screen fades out first, then the new
/// one fades in with a slight scale-up. The two screens are never half
/// visible on top of each other (the default Android transition overlapped
/// them, so text from both pages showed at once).
Widget fadeThrough(Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
  final incoming = CurvedAnimation(parent: animation, curve: const Interval(0.3, 1, curve: Curves.easeOutCubic));
  final outgoing = CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0, 0.3, curve: Curves.easeIn));
  return FadeTransition(
    opacity: ReverseAnimation(outgoing),
    child: FadeTransition(
      opacity: incoming,
      child: ScaleTransition(
        scale: Tween(begin: 0.97, end: 1.0).animate(incoming),
        child: child,
      ),
    ),
  );
}

class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      fadeThrough(animation, secondaryAnimation, child);
}
