import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/hidden_bird_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/hidden_name_input.dart';

void main() {
  testWidgets('PC keyboard rejects errors, accepts accents and submits once', (
    t,
  ) async {
    var answers = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HiddenNameInput(
              question: Question({
                'id': 'keyboard',
                'species_id': 'test',
                'kind': 'mystery',
                'options': ['Été'],
                'answer': 0,
              }),
              locked: false,
              beforeHint: null,
              onAnswer: (_) => answers++,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ, character: 'z');
    await t.pump();
    expect(
      find.text('Pas cette lettre ! Essaie une autre touche.'),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
    await t.sendKeyEvent(LogicalKeyboardKey.keyT, character: 't');
    await t.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'é');
    await t.pump();
    expect(answers, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
    expect(answers, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'PC letters survive focus changes, protect fields and shortcuts, and respect locks',
    (t) async {
      final outside = FocusNode();
      final editing = FocusNode();
      addTearDown(outside.dispose);
      addTearDown(editing.dispose);
      var answers = 0;
      var locked = false;
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextButton(
                        focusNode: outside,
                        onPressed: () {},
                        child: const Text('Autre commande'),
                      ),
                      TextField(focusNode: editing),
                      HiddenNameInput(
                        question: Question({
                          'id': 'focus',
                          'species_id': 'test',
                          'kind': 'mystery',
                          'options': ['Été'],
                          'answer': 0,
                        }),
                        locked: locked,
                        beforeHint: null,
                        onAnswer: (_) => answers++,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      outside.requestFocus();
      await t.pump();
      // Web keydown can supply the logical letter without a character.
      await t.sendKeyEvent(LogicalKeyboardKey.keyE);
      await t.pump();
      expect(
        find.text('✓ Bien placé ! Continue avec la prochaine lettre.'),
        findsOneWidget,
      );
      editing.requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.keyT, character: 't');
      expect(answers, 0);
      outside.requestFocus();
      await t.pump();
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyT, character: 't');
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      update(() => locked = true);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.keyT, character: 't');
      update(() => locked = false);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.keyT, character: 't');
      expect(
        answers,
        0,
        reason: 'Fields, shortcuts and lock must not consume a puzzle letter',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'é');
      await t.pump();
      expect(answers, 1);
      await t.pumpWidget(const SizedBox());
      await t.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
      expect(answers, 1);
    },
  );

  testWidgets('A dialog keeps physical keys until closed', (t) async {
    var answers = 0;
    late BuildContext screen;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            screen = context;
            return Scaffold(
              body: HiddenNameInput(
                question: Question({
                  'id': 'dialog',
                  'species_id': 'test',
                  'kind': 'mystery',
                  'options': ['A'],
                  'answer': 0,
                }),
                locked: false,
                beforeHint: null,
                onAnswer: (_) => answers++,
              ),
            );
          },
        ),
      ),
    );
    await t.pump();
    showDialog<void>(
      context: screen,
      builder: (_) => const AlertDialog(content: Text('Source')),
    );
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    expect(answers, 0);
    Navigator.of(screen).pop();
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await t.pump();
    expect(answers, 1);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Free hidden bird accepts physical letters without awarding plumes',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance(), {
        'species': [
          {
            'id': 'test',
            'name': 'Été',
            'latin': 'Test',
            'level': 1,
            'clues': ['Un nom de test'],
            'source': 'https://example.org',
            'publisher': 'Test',
          },
        ],
        'questions': [],
      }, []);
      await t.pumpWidget(MaterialApp(home: HiddenBirdScreen(store: store)));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ, character: 'z');
      await t.pumpAndSettle();
      expect(
        find.text('Pas de Z ici. Essaie une autre lettre !'),
        findsOneWidget,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'é');
      await t.sendKeyEvent(LogicalKeyboardKey.keyT);
      await t.pumpAndSettle();
      expect(find.text('Bravo ! Tu as découvert Été !'), findsOneWidget);
      expect(store.xp, 0);
      expect(store.active, isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
