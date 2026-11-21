import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/hidden_name_input.dart';

void main() {
  testWidgets(
    'Shuffle is free and preserves placed letters and automatic completion',
    (t) async {
      var hints = 0;
      int? answer;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HiddenNameInput(
                question: Question({
                  'id': 'shuffle',
                  'kind': 'mystery',
                  'species_id': 'test',
                  'options': ['Merle'],
                  'answer': 0,
                }),
                locked: false,
                beforeHint: () async {
                  hints++;
                  return true;
                },
                beforeSpellingHelp: () async {
                  hints++;
                  return true;
                },
                onAnswer: (value) => answer = value,
              ),
            ),
          ),
        ),
      );
      Finder bankButtons() => find.byWidgetPredicate(
        (w) => w is OutlinedButton && w.key.toString().contains('bank-letter-'),
      );
      List<String> labels() => t
          .widgetList<OutlinedButton>(bankButtons())
          .map((w) => (w.child as Text).data!)
          .toList();
      Future<void> letter(String value) async {
        final button = find
            .byWidgetPredicate(
              (w) =>
                  w is OutlinedButton &&
                  w.key.toString().contains('bank-letter-') &&
                  (w.child as Text).data == value &&
                  w.onPressed != null,
            )
            .first;
        await t.ensureVisible(button);
        await t.tap(button);
        await t.pumpAndSettle();
      }

      await letter('M');
      final before = labels();
      final used = before.indexOf('·');
      await t.tap(find.byKey(const ValueKey('shuffle-letters')));
      await t.pumpAndSettle();
      final after = labels();
      expect(after, isNot(before));
      expect(after[used], '·');
      expect([...after]..sort(), [...before]..sort());
      expect(hints, 0);
      for (final value in ['E', 'R', 'L', 'E']) {
        await letter(value);
      }
      expect(answer, 0);
      expect(hints, 0);
    },
  );
}
