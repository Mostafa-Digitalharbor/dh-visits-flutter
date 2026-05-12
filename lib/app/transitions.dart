import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _duration = Duration(milliseconds: 320);
const _reverseDuration = Duration(milliseconds: 240);

CustomTransitionPage<T> fadeTransition<T>(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: _duration,
    reverseTransitionDuration: _reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: fade, child: child);
    },
  );
}

CustomTransitionPage<T> slideTransition<T>(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: _duration,
    reverseTransitionDuration: _reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      final beginX = isRtl ? -1.0 : 1.0;

      final slide = Tween<Offset>(
        begin: Offset(beginX, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));

      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      );

      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}

CustomTransitionPage<T> scaleTransition<T>(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: _duration,
    reverseTransitionDuration: _reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
