import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/game_screen.dart';
import 'package:petit_ornitho/ui/criterion_board.dart';

class CriterionTestStore extends GameStore {
  CriterionTestStore(
    super.prefs,
    super.content,
    super.media, {
    super.publishedFacts,
  });
  @override
  String get identity => 'guest';
}

Future<CriterionTestStore> fixture() async {
  SharedPreferences.setMockInitialValues({});
  dynamic read(String path) => jsonDecode(File(path).readAsStringSync());
  final content = read('assets/data/content.json') as Map<String, dynamic>;
  final q =
      read('data/editorial/completion-2026-10-16/expert-harle-pair/candidate.json')
          as Map<String, dynamic>;
  q.addAll({'id': 'test_criterion', 'kind': 'quiz', 'asset': '', 'version': 1});
  content['questions'] = [q, ...content['questions']];
  final store = CriterionTestStore(
    await SharedPreferences.getInstance(),
    content,
    [],
    publishedFacts: read('assets/data/published_species_facts.json')['facts'],
  )..reload();
  store.state['active'] = {
    'id': 'fixture',
    'ids': [q['id'], content['questions'][1]['id']],
    'index': 0,
    'hints': 1,
    'level': 5,
    'score': 0,
    'answers': [],
  };
  await store.save();
  return store;
}

void main() {
  testWidgets(
    'two gestures, resume, corrected error and sources after completion',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = await fixture();
      Future<void> show() =>
          t.pumpWidget(MaterialApp(home: GameScreen(store: s)));
      await show();
      await t.pumpAndSettle();
      expect(find.text(s.current.explanation), findsNothing);
      await t.ensureVisible(find.text('Harle huppé'));
      await t.pumpAndSettle();
      await t.tap(find.text('Harle huppé'));
      await t.pumpAndSettle();
      expect(s.active!['feedback'], isNull);
      expect(s.active!['score'], 0);
      await t.pumpWidget(const SizedBox());
      s.reload();
      await show();
      await t.pumpAndSettle();
      expect(find.text('2 · Quel détail fait la différence ?'), findsOneWidget);
      final wrong = s.current.data['justification']['options'][1] as String;
      await t.ensureVisible(find.text(wrong));
      await t.pumpAndSettle();
      await t.tap(find.text(wrong));
      await t.pumpAndSettle();
      expect(s.active!['criterion']['justification'], [1]);
      expect(find.text(s.current.explanation), findsNothing);
      final correct = s.current.data['justification']['options'][0] as String;
      await t.ensureVisible(find.text(correct));
      await t.pumpAndSettle();
      await t.tap(find.text(correct));
      await t.pumpAndSettle();
      expect(find.text('Tu as retrouvé le bon détail !'), findsOneWidget);
      expect(s.active!['score'], 0);
      expect(s.attempts.single['justification_correct'], false);
      expect(find.text(s.current.explanation), findsOneWidget);
      expect(t.takeException(), isNull);
      // Reloaded completion remains readable and has an explicit way forward.
      await t.pumpWidget(const SizedBox());
      s.reload();
      await show();
      await t.pumpAndSettle();
      expect(find.text('Poursuivre ma balade'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'correct completion waits for the player before advancing',
    (t) async {
      final s = await fixture();
      await t.pumpWidget(MaterialApp(home: GameScreen(store: s)));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Harle huppé'));
      await t.pumpAndSettle();
      await t.tap(find.text('Harle huppé'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 10));
      expect(s.active!['index'], 0);
      final answer = s.current.data['justification']['options'][0] as String;
      await t.ensureVisible(find.text(answer));
      await t.pumpAndSettle();
      await t.tap(find.text(answer));
      await t.pumpAndSettle();
      expect(s.active!['score'], 15);
      await t.pump(const Duration(seconds: 30));
      expect(s.active!['index'], 0);
      final next = find.text('Poursuivre ma balade');
      await t.ensureVisible(next);
      await t.pumpAndSettle();
      await t.tap(next);
      await t.pumpAndSettle();
      expect(s.active!['index'], 1);
      expect(s.active!['score'], 15);
      expect(s.active!['criterion'], isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('narrow and wide boards support enlarged text without overflow', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final entry in {
      'Avenir': '/System/Library/Fonts/Avenir Next.ttc',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
    for (final width in [390.0, 734.0]) {
      t.view.physicalSize = Size(width, 977);
      final s = await fixture();
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'Avenir',
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xff145b72),
              foregroundColor: Color(0xfffff9e5),
              centerTitle: true,
            ),
          ),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              textScaler: TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: key,
            child: GameScreen(store: s),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(CriterionBoard), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final im =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/criterion-${width.toInt()}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        im.dispose();
      });
      await t.ensureVisible(find.text('Harle huppé'));
      await t.pumpAndSettle();
      await t.tap(find.text('Harle huppé'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }
  });
}
