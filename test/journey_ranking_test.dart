import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/game_screen.dart';
import 'package:petit_ornitho/ui/ranking_choice.dart';

class FieldStore extends GameStore {
  FieldStore(
    super.prefs,
    super.content,
    super.media, {
    super.photoCatalog,
    super.publishedFacts,
  });
  @override
  String get identity => 'guest';
}

void main() {
  testWidgets(
    'Ranking changes order without submitting and persists the graded answer',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      dynamic read(String p) => jsonDecode(File(p).readAsStringSync());
      final content = read('assets/data/content.json');
      final store = FieldStore(
        await SharedPreferences.getInstance(),
        content,
        [],
        photoCatalog: read('assets/data/photo_catalog.json'),
        publishedFacts: read(
          'assets/data/published_species_facts.json',
        )['facts'],
      )..reload();
      store.state = {
        'unlocked': 2,
        'active': {
          'id': 'test-nest-placement',
          'level': 2,
          'index': 0,
          'ids': ['ranking_v1_2_body_mass_0', 'ranking_v1_2_body_mass_1'],
          'hints': 0,
          'score': 0,
          'answers': [],
          'feedback': null,
        },
      };
      final answer = store.current.answer;
      await t.pumpWidget(MaterialApp(home: GameScreen(store: store)));
      await t.pumpAndSettle();
      expect(find.text('Le podium des oiseaux'), findsOneWidget);
      expect(find.byType(RankingChoice), findsOneWidget);
      final q = store.current;
      final order = List<int>.from(q.data['initial_order']);
      final wanted = List<int>.from(q.data['permutations'][answer]);
      for (var position = 0; position < wanted.length; position++) {
        while (order.indexOf(wanted[position]) > position) {
          final target = find.byKey(ValueKey('rank-up-${wanted[position]}'));
          await t.ensureVisible(target);
          await t.pumpAndSettle();
          await t.tap(target);
          await t.pumpAndSettle();
          final from = order.indexOf(wanted[position]);
          order.insert(from - 1, order.removeAt(from));
        }
      }
      expect(store.active!['feedback'], isNull);
      final confirm = find.byKey(const ValueKey('rank-confirm'));
      await t.ensureVisible(confirm);
      await t.pumpAndSettle();
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(store.active!['feedback']['correct'], true);
      expect(find.byType(RankingChoice), findsNothing);
      store.reload();
      expect(store.active!['feedback']['correct'], true);
      expect(t.takeException(), isNull);
    },
  );
}
