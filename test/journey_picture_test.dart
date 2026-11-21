import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/game_screen.dart';
import 'package:petit_ornitho/ui/picture_choice_board.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

class PictureStore extends GameStore {
  PictureStore(super.prefs, super.content, super.media, {super.photoCatalog});
  @override
  String get identity => 'guest';
}

class RecoveringPictureStore extends PictureStore {
  final Map<String, dynamic> delivered;
  RecoveringPictureStore(super.prefs, super.content, super.media, this.delivered);
  @override
  bool get cloud => true;
  @override
  Future<void> fetchJourneyQuestions() async {
    await Future<void>.delayed(Duration.zero);
    (content['questions'] as List).add(delivered);
  }
}

void main() {
  testWidgets('Missing saved question loads automatically without changing points', (t) async {
    SharedPreferences.setMockInitialValues({});
    final catalog=jsonDecode(File('assets/data/content.json').readAsStringSync());
    final question=Map<String,dynamic>.from((catalog['questions'] as List).firstWhere((q)=>q['format']=='image_choice'));
    final store=RecoveringPictureStore(await SharedPreferences.getInstance(),{'questions':[]},[],question)..reload();
    store.state={'xp':30,'active':{'id':'saved','level':1,'index':0,'ids':[question['id']],'hints':1,'score':30,'answers':[]}};
    final before=jsonEncode(store.state);
    await t.pumpWidget(MaterialApp(home: GameScreen(store:store)));
    await t.pumpAndSettle();
    expect(find.byType(PictureChoiceBoard),findsOneWidget);
    expect(jsonEncode(store.state),before);
    expect(t.takeException(),isNull);
  });
  testWidgets(
    'A server question missing locally preserves the session and shows recovery',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = PictureStore(await SharedPreferences.getInstance(), {
        'questions': [],
      }, [])..reload();
      store.state = {
        'xp': 465,
        'active': {
          'id': 'saved',
          'level': 4,
          'index': 1,
          'ids': ['old', 'new-server-question'],
          'answers': [
            {'correct': true},
          ],
          'score': 15,
        },
      };
      final before = jsonEncode(store.state);
      await t.pumpWidget(MaterialApp(home: GameScreen(store: store)));
      await t.pumpAndSettle();
      expect(find.text('Ta balade est sauvegardée'), findsOneWidget);
      expect(find.text('Retour au parcours'), findsOneWidget);
      expect(jsonEncode(store.state), before);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Journey asks for a named bird, shows four photos and saves visual evidence',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      dynamic read(String p) => jsonDecode(File(p).readAsStringSync());
      final store = PictureStore(
        await SharedPreferences.getInstance(),
        read('assets/data/content.json'),
        [],
        photoCatalog: read('assets/data/photo_catalog.json'),
      )..reload();
      final q = store.questions.firstWhere(
        (q) => q.data['format'] == 'image_choice',
      );
      store.state = {
        'unlocked': 1,
        'active': {
          'id': 'picture-test',
          'level': 1,
          'index': 0,
          'ids': [q.id],
          'hints': 0,
          'score': 0,
          'answers': [],
          'feedback': null,
        },
      };
      await t.pumpWidget(MaterialApp(home: GameScreen(store: store)));
      await t.pumpAndSettle();
      expect(find.byType(PictureChoiceBoard), findsOneWidget);
      expect(find.byType(BirdPhoto), findsNWidgets(4));
      for (final name in q.options) {
        expect(find.text(name), findsNothing);
      }
      final correct = find.byWidgetPredicate(
        (widget) => widget is BirdPhoto && widget.species == q.species,
      );
      expect(correct, findsOneWidget);
      await t.ensureVisible(correct);
      await t.tap(correct);
      await t.pumpAndSettle();
      expect(store.active!['feedback']['correct'], true);
      expect(find.text('✓ ${q.options[q.answer]}'), findsOneWidget);
      store.reload();
      expect(store.active!['feedback']['correct'], true);
      expect(t.takeException(), isNull);
    },
  );
}
