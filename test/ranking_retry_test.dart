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
    'Wrong ranking identifies misplaced birds, then lets the child correct them',
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
      expect(order, isNot(wanted));
      final firstConfirm = find.byKey(const ValueKey('rank-confirm'));
      await t.ensureVisible(firstConfirm); await t.pumpAndSettle();
      await t.tap(firstConfirm); await t.pumpAndSettle();
      expect(store.active!['feedback']['correct'], false);
      expect(find.textContaining('À déplacer au rang'), findsWidgets);
      expect(find.textContaining('oiseaux à déplacer'), findsOneWidget);
      final attempts = store.attempts.length;

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
      expect(find.text('Tout est bien placé ! Valide ton classement.'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('rank-confirm'));
      await t.ensureVisible(confirm);
      await t.pumpAndSettle();
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(store.active!['feedback']['correct'], false);
      expect(store.attempts.length, attempts);
      expect(find.byType(RankingChoice), findsNothing);
      store.reload();
      expect(store.active!['feedback']['correct'], false);
      expect(store.attempts.length, attempts);
      await t.pump(const Duration(seconds: 2));
      expect(store.active!['index'], 0);
      final next = find.text('Continuer →');
      await t.ensureVisible(next);
      await t.tap(next);
      await t.pumpAndSettle();
      expect(store.active!['index'], 1);
      expect(t.takeException(), isNull);
    },
  );
}
