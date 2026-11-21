import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/hidden_name_input.dart';

void main() {
  for (final allowed in [false, true]) {
    testWidgets('Letter-only interface, hint acknowledgement: $allowed', (
      t,
    ) async {
      var answers = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HiddenNameInput(
                question: Question({
                  'id': 'x',
                  'kind': 'mystery',
                  'species_id': 'x',
                  'options': ['Merle noir'],
                  'answer': 0,
                }),
                locked: false,
                beforeHint: () async => allowed,
                onAnswer: (_) => answers++,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('noms possibles'), findsNothing);
      expect(find.text('Je propose ce nom'), findsNothing);
      await t.pump();
      expect(answers, 0);
      await t.ensureVisible(find.text('Découvrir une lettre'));
      await t.tap(find.text('Découvrir une lettre'));
      await t.pumpAndSettle();
      expect(
        find.textContaining(
          allowed ? 'Pépi t’a apporté' : 'n’a pas pu être enregistrée',
        ),
        findsOneWidget,
      );
    });
  }
}
