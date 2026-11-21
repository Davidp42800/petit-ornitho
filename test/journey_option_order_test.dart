import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/journey_option_order.dart';

void main() {
  test(
    'Each catalogue answer appears at every position across session IDs',
    () {
      final random = Random(47);
      for (final count in [2, 3, 4, 5, 6]) {
        final frequencies = List.generate(count, (_) => List.filled(count, 0));
        for (var run = 0; run < 2400; run++) {
          final seed = '${random.nextInt(1 << 30)}/2/identification';
          final order = JourneyOptionOrder.permutation(seed, count);
          expect(order.toSet(), {for (var i = 0; i < count; i++) i});
          expect(JourneyOptionOrder.permutation(seed, count), order);
          for (var position = 0; position < count; position++) {
            frequencies[order[position]][position]++;
          }
        }
        for (final row in frequencies) {
          for (final hits in row) {
            expect(
              hits,
              inInclusiveRange(2400 / count * .80, 2400 / count * 1.20),
            );
          }
        }
      }
    },
  );
}
