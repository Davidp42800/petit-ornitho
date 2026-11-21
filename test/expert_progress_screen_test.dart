import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/expert_progress.dart';

void main() {
  testWidgets('Expert distinguishes missing content, mastery and all species', (
    t,
  ) async {
    final rows = [
      for (final id in ['a', 'b'])
        for (final modality in ['visual', 'audio', 'knowledge'])
          {
            'species_id': id,
            'modality': modality,
            'mastered': id == 'a',
            'approved_references': id == 'a' ? 3 : 0,
            'successes': id == 'a' ? 4 : 0,
            'distinct_references': id == 'a' ? 3 : 0,
            'sessions': id == 'a' ? 3 : 0,
            'recent_correct': id == 'a' ? 4 : 0,
            'recent_total': id == 'a' ? 4 : 0,
            'spaced_review': id == 'a',
            'latest_correct': id == 'a',
          },
    ];
    await t.pumpWidget(
      MaterialApp(
        home: ExpertProgressScreen(
          load: () async => rows,
          names: const {'a': 'Merle noir', 'b': 'Rougegorge'},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('1 / 2 oiseaux maîtrisés'), findsOneWidget);
    expect(find.text('3 / 6 compétences validées'), findsOneWidget);
    await t.tap(find.text('Rougegorge'));
    await t.pumpAndSettle();
    expect(find.text('Sons · Contenu à compléter'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Merle');
    await t.pumpAndSettle();
    expect(find.text('Rougegorge'), findsNothing);
    expect(find.text('1 / 2 oiseaux maîtrisés'), findsOneWidget);
  });
}
