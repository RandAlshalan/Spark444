import 'package:flutter/material.dart';

/// Custom page route with smooth fade and slide transition
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final RouteTransitionsBuilder? customTransition;

  SmoothPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
    this.customTransition,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: customTransition ??
              (context, animation, secondaryAnimation, child) {
                // Smooth fade and slight slide transition
                const begin = Offset(0.03, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;

                var slideTween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var fadeTween = Tween<double>(begin: 0.0, end: 1.0)
                    .chain(CurveTween(curve: curve));

                return SlideTransition(
                  position: animation.drive(slideTween),
                  child: FadeTransition(
                    opacity: animation.drive(fadeTween),
                    child: child,
                  ),
                );
              },
        );
}

/// Fade-only transition for subtle navigation
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 250),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
              ),
              child: child,
            );
          },
        );
}

/// Scale and fade transition for dialog-like pages
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  ScalePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 350),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeInOutCubic;

            var scaleTween = Tween<double>(begin: 0.92, end: 1.0)
                .chain(CurveTween(curve: curve));
            var fadeTween = Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: curve));

            return ScaleTransition(
              scale: animation.drive(scaleTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );
}

/// Slide from bottom transition for modal-like pages
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideUpPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 350),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.15);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var slideTween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));
            var fadeTween = Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );
}

/// No transition - instant navigation (for tab switches, etc.)
class NoTransitionRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  NoTransitionRoute({
    required this.page,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}

/// Extension methods for easier navigation
extension NavigatorExtensions on BuildContext {
  /// Navigate with smooth transition
  Future<T?> pushSmooth<T>(Widget page) {
    return Navigator.push<T>(
      this,
      SmoothPageRoute(page: page),
    );
  }

  /// Navigate with fade transition
  Future<T?> pushFade<T>(Widget page) {
    return Navigator.push<T>(
      this,
      FadePageRoute(page: page),
    );
  }

  /// Navigate with scale transition
  Future<T?> pushScale<T>(Widget page) {
    return Navigator.push<T>(
      this,
      ScalePageRoute(page: page),
    );
  }

  /// Navigate with slide up transition
  Future<T?> pushSlideUp<T>(Widget page) {
    return Navigator.push<T>(
      this,
      SlideUpPageRoute(page: page),
    );
  }

  /// Navigate with no transition
  Future<T?> pushInstant<T>(Widget page) {
    return Navigator.push<T>(
      this,
      NoTransitionRoute(page: page),
    );
  }
}
