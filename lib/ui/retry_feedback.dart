import 'dart:math' as math;
import 'package:flutter/material.dart';

class RetryFeedback extends InheritedWidget {
  final Set<int> wrong;
  final int? correctAnswer;
  const RetryFeedback({
    super.key,
    required this.wrong,
    this.correctAnswer,
    required super.child,
  });
  static bool isWrong(BuildContext context, int index) =>
      context
          .dependOnInheritedWidgetOfExactType<RetryFeedback>()
          ?.wrong
          .contains(index) ??
      false;
  @override
  bool updateShouldNotify(RetryFeedback old) =>
      old.wrong != wrong || old.correctAnswer != correctAnswer;
}

class RetryChoice extends StatelessWidget {
  final int index;
  final Widget child;
  const RetryChoice({super.key, required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    final wrong = RetryFeedback.isWrong(context, index);
    return TweenAnimationBuilder<double>(
      key: ValueKey('retry-$index-$wrong'),
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 400),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(wrong ? math.sin(t * math.pi * 6) * 8 * (1 - t) : 0, 0),
        child: child,
      ),
      child: Semantics(
        label: wrong
            ? 'Réponse incorrecte, essaie une autre proposition'
            : null,
        child: IgnorePointer(
          ignoring: wrong,
          child: Stack(
            children: [
              child,
              if (wrong)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x44e84e54),
                        border: Border.all(
                          color: const Color(0xffbd3340),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
