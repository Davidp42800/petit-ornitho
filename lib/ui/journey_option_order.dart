import 'package:flutter/widgets.dart';

/// Maps visible positions to the immutable catalogue indices used for grading.
class JourneyOptionOrder extends InheritedWidget {
  const JourneyOptionOrder({
    required this.seed,
    required super.child,
    super.key,
  });
  final String seed;

  static List<int> indices(
    BuildContext context,
    int count, [
    String phase = '',
  ]) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<JourneyOptionOrder>();
    if (scope == null) return List.generate(count, (i) => i);
    return permutation('${scope.seed}/$phase', count);
  }

  // Fixed algorithm with integers within JS's exact range, shared by web and native.
  static List<int> permutation(String seed, int count) {
    const modulus = 2147483647;
    var state = 1;
    for (final unit in seed.codeUnits) {
      state = (state * 31 + unit) % modulus;
    }
    if (state == 0) state = 1;
    final result = List.generate(count, (i) => i);
    for (var i = count - 1; i > 0; i--) {
      state = (state * 48271) % modulus;
      final j = state % (i + 1);
      final value = result[i];
      result[i] = result[j];
      result[j] = value;
    }
    return result;
  }

  @override
  bool updateShouldNotify(JourneyOptionOrder oldWidget) =>
      seed != oldWidget.seed;
}
