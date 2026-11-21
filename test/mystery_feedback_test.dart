import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/thinking_board.dart';

void main() {
  for (final correct in [true, false]) {
    testWidgets(
      'Mystery correction reveals only the answer (correct=$correct)',
      (t) async {
        final q = Question({
          'id': 'test-mystery',
          'kind': 'mystery',
          'species_id': 'kestrel',
          'prompt': 'Quel oiseau se cache ici ?',
          'options': [
            'Faucon crécerelle',
            'Coucou gris',
            'Merle noir',
            'Moineau domestique',
          ],
          'answer': 0,
          'explanation': 'Observe les ailes pointues de cet oiseau.',
          'clues': [],
          'source': 'https://example.org',
          'publisher': 'Test',
        });
        var continued = false;
        await t.pumpWidget(
          MaterialApp(
            home: ThinkingBoard(
              question: q,
              feedback: {
                'answer': 0,
                'choice': correct ? 0 : 1,
                'correct': correct,
                'points': correct ? 15 : 0,
              },
              hints: 1,
              step: 1,
              total: 6,
              score: 0,
              companionLevel: 1,
              busy: false,
              onAnswer: (_) => fail('No answer after correction'),
              onHint: () {},
              onNext: () => continued = true,
              onPause: () {},
              onSource: () {},
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Faucon crécerelle'), findsOneWidget);
        for (final wrong in q.options.skip(1)) {
          expect(find.text(wrong), findsNothing);
        }
        expect(find.text(q.explanation), findsNothing);
        await t.tap(find.text('Continuer →'));
        expect(continued, true);
        expect(t.takeException(), isNull);
      },
    );
  }
}
