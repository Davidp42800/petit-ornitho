import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/thinking_board.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

void main() {
  testWidgets(
    'Mission nid : photo, choix, crédit et verrouillage après réponse',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final data = jsonDecode(
        File('data/editorial/kingfisher_missions.json').readAsStringSync(),
      );
      final q = Question(Map<String, dynamic>.from(data['questions'][0]));
      final catalog = jsonDecode(
        File('assets/data/photo_catalog.json').readAsStringSync(),
      );
      final photo = Map<String, dynamic>.from(
        (catalog['species'] as List).firstWhere(
          (b) => b['id'] == q.species,
        )['photos'][0],
      );
      int? answer;
      var credits = 0;
      Widget screen({Map<String, dynamic>? feedback}) => MaterialApp(
        home: ThinkingBoard(
          question: q,
          feedback: feedback,
          hints: 0,
          step: 1,
          total: 6,
          score: 0,
          companionLevel: 2,
          busy: false,
          missionTitle: 'Où est mon nid ?',
          birdMedia: photo,
          onAnswer: (v) => answer = v,
          onHint: () {},
          onNext: () {},
          onPause: () {},
          onSource: () => credits++,
        ),
      );
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      expect(find.byType(BirdPhoto), findsOneWidget);
      expect(find.text('Où est mon nid ?'), findsOneWidget);
      await t.ensureVisible(find.text('Source et crédit photo'));
      await t.tap(find.text('Source et crédit photo'));
      expect(credits, 1);
      await t.scrollUntilVisible(find.text(q.options[1]), 200);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(q.options[1]));
      await t.pumpAndSettle();
      await t.tap(find.text(q.options[1]));
      expect(answer, 1);
      await t.pumpWidget(
        screen(
          feedback: {'choice': 1, 'answer': 1, 'correct': true, 'points': 15},
        ),
      );
      await t.pumpAndSettle();
      answer = null;
      await t.ensureVisible(find.text(q.options[1]));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(q.options[1]));
      await t.pumpAndSettle();
      await t.tap(find.text(q.options[1]));
      expect(answer, isNull);
      await t.scrollUntilVisible(find.text(q.explanation), 200);
      expect(find.text(q.explanation), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
