import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/domain/hidden_bird.dart';
import 'package:petit_ornitho/domain/bird_recording.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/hidden_bird_screen.dart';
import 'package:petit_ornitho/ui/listening_screen.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

Map<String, dynamic> clip(String species, String latin) => {
  'id': species,
  'species_id': species,
  'scientific_name': latin,
  'url': 'https://example.org/$species.mp3',
  'source': 'https://example.org/$species',
  'author': 'Test fixture',
  'license': 'CC BY 4.0',
  'license_url': 'https://creativecommons.org/licenses/by/4.0/',
  'status': 'validated',
  'type': 'song',
  'reviewer': 'Test only',
  'review_note': 'Synthetic metadata, not a real verified recording.',
  'reviewed_at': '2026-10-03',
  'identification_disputed': false,
  'reuse_approved': true,
  'start_ms': 0,
  'end_ms': 10000,
};

class FakeAudio implements BirdAudio {
  BirdRecording? last;
  bool fail = false;
  bool disposed = false;
  @override
  Future<void> play(BirdRecording clip) async {
    if (fail) throw StateError('offline');
    last = clip;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  Future<GameStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return GameStore(
      await SharedPreferences.getInstance(),
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      [],
    )..reload();
  }

  test(
    'Letters preserve accents, repeated letters and separators; hints terminate',
    () {
      final p = HiddenBird('Mésange bleue');
      expect(p.visible(' '), true);
      expect(p.visible('é'), false);
      expect(p.guess('E'), true);
      expect(p.visible('é'), true);
      expect(p.guess('Z'), false);
      expect(p.guess('E'), false);
      for (var i = 0; i < 26 && !p.complete; i++) {
        p.reveal();
      }
      expect(p.complete, true);
      expect(p.reveal(), null);
    },
  );
  test(
    'Audio rejects wrong taxonomy, missing review, disputed identification and bad intervals',
    () {
      final species = [
        {'id': 'robin', 'latin': 'Erithacus rubecula'},
      ];
      final good = clip('robin', 'Erithacus rubecula');
      expect(BirdRecording.validated([good], species), hasLength(1));
      for (final change in [
        {'status': 'candidate'},
        {'scientific_name': 'Turdus merula'},
        {'type': 'song, call'},
        {'reviewer': ''},
        {'identification_disputed': true},
        {'reuse_approved': false},
        {'end_ms': 0},
        {'end_ms': 31000},
        {'url': 'http://example.org/a'},
      ]) {
        expect(
          BirdRecording.validated([
            {...good, ...change},
          ], species),
          isEmpty,
        );
      }
      expect(BirdRecording.validated([good, good], species), hasLength(1));
    },
  );
  test(
    'Audio retains distinct clips and labels calls without duplicate answers',
    () {
      final species = [
        {'id': 'robin', 'latin': 'Erithacus rubecula'},
      ];
      final base = clip('robin', 'Erithacus rubecula');
      final recordings = BirdRecording.validated([
        {...base, 'id': 'one'},
        {...base, 'id': 'two', 'type': 'call'},
        {...base, 'id': 'three', 'type': 'alarm'},
        {...base, 'id': 'four', 'type': 'flight'},
      ], species);
      expect(recordings, hasLength(4));
      expect(recordings.map((r) => r.label), [
        'chant',
        'cri',
        'cri d’alarme',
        'cri de vol',
      ]);
      final deck = BirdRecordingDeck(recordings, random: Random(7));
      String? last;
      for (var cycle = 0; cycle < 10; cycle++) {
        final seen = <String>{};
        for (var i = 0; i < 4; i++) {
          final round = deck.nextRound();
          expect(round, hasLength(1));
          expect(round.single.id, isNot(last));
          seen.add(round.single.id);
          last = round.single.id;
        }
        expect(seen, hasLength(4));
      }
      expect(BirdRecordingDeck([]).nextRound(), isEmpty);
    },
  );
  testWidgets(
    'Letter help completes four birds; replay preserves the saved journey',
    (t) async {
      final s = await store();
      await s.start(1);
      final before = jsonEncode(s.state);
      await t.pumpWidget(MaterialApp(home: HiddenBirdScreen(store: s)));
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await t.scrollUntilVisible(find.text('Découvrir une lettre'), 200);
        while (find.textContaining('Bravo !').evaluate().isEmpty) {
          await t.scrollUntilVisible(find.text('Découvrir une lettre'), 200);
          await t.ensureVisible(find.text('Découvrir une lettre'));
          await t.pumpAndSettle();
          await t.tap(find.text('Découvrir une lettre'));
          await t.pumpAndSettle();
        }
        final next = find.text(i == 3 ? 'Terminer le jeu' : 'Oiseau suivant →');
        await t.scrollUntilVisible(next, 150);
        await t.tap(next);
        await t.pumpAndSettle();
      }
      expect(find.text('4 oiseaux découverts'), findsOneWidget);
      await t.tap(find.text('Rejouer'));
      await t.pumpAndSettle();
      expect(find.text('OISEAU 1 / 4'), findsOneWidget);
      expect(jsonEncode(s.state), before);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Unreviewed audio never starts a game or instantiates the player',
    (t) async {
      final s = await store();
      for (final ultimate in [false, true]) {
        await t.pumpWidget(
          MaterialApp(
            home: ListeningScreen(
              key: ValueKey(ultimate),
              store: s,
              ultimate: ultimate,
              audioFactory: () => throw StateError('must not instantiate'),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Les sons se préparent'), findsOneWidget);
        expect(find.text('Valider ma photo'), findsNothing);
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Audio game requires playback; offline failure is retryable; correct photo advances',
    (t) async {
      final s = await store();
      final before = jsonEncode(s.state);
      s.content['recordings'] = [
        clip('robin', 'Erithacus rubecula'),
        clip('blackbird', 'Turdus merula'),
      ];
      final audio = FakeAudio()..fail = true;
      await t.pumpWidget(
        MaterialApp(
          home: ListeningScreen(store: s, audioFactory: () => audio),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Écouter le son'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Le son ne se charge pas. Réessaie ou reviens au parcours.'),
        150,
      );
      expect(
        find.text('Le son ne se charge pas. Réessaie ou reviens au parcours.'),
        findsOneWidget,
      );
      audio.fail = false;
      await t.scrollUntilVisible(find.text('Écouter le son'), -200);
      await t.tap(find.text('Écouter le son'));
      await t.pumpAndSettle();
      final photo = find.byWidgetPredicate(
        (w) => w is BirdPhoto && w.species == audio.last!.species,
      );
      await t.scrollUntilVisible(photo, 150);
      await t.tap(photo);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Valider ma photo'), 150);
      await t.tap(find.text('Valider ma photo'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Oiseau suivant →'), 100);
      expect(find.text('Oiseau suivant →'), findsOneWidget);
      expect(jsonEncode(s.state), before);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(audio.disposed, true);
    },
  );
  testWidgets('Ultimate links a name to both photo and heard recording', (
    t,
  ) async {
    final s = await store();
    s.content['recordings'] = [
      clip('robin', 'Erithacus rubecula'),
      clip('blackbird', 'Turdus merula'),
    ];
    final audio = FakeAudio();
    await t.pumpWidget(
      MaterialApp(
        home: ListeningScreen(
          store: s,
          ultimate: true,
          audioFactory: () => audio,
        ),
      ),
    );
    await t.pumpAndSettle();
    final targetId = find.text('Rougegorge familier').evaluate().isNotEmpty
        ? 'robin'
        : 'blackbird';
    final photo = find.byWidgetPredicate(
      (w) => w is BirdPhoto && w.species == targetId,
    );
    await t.scrollUntilVisible(photo, 150);
    await t.tap(photo);
    await t.pumpAndSettle();
    int? correctSound;
    for (var i = 1; i <= 2; i++) {
      await t.scrollUntilVisible(find.text('Écouter le son $i'), 150);
      await t.tap(find.text('Écouter le son $i'));
      await t.pumpAndSettle();
      if (audio.last!.species == targetId) correctSound = i;
      await t.tap(find.text('Arrêter'));
      await t.pumpAndSettle();
    }
    final choose = find.text('Choisir le son $correctSound');
    await t.scrollUntilVisible(choose, -120);
    await t.tap(choose);
    await t.pumpAndSettle();
    final validate = find.text('Relier le nom, la photo et le son');
    await t.scrollUntilVisible(validate, 150);
    await t.tap(validate);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Oiseau suivant →'), 150);
    expect(find.text('Oiseau suivant →'), findsOneWidget);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Oiseau suivant →'));
    await t.pumpAndSettle();
    await t.tap(find.text('Oiseau suivant →'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('OISEAU 2 / 2'), -200);
    expect(find.text('OISEAU 2 / 2'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(audio.disposed, true);
    expect(t.takeException(), isNull);
  });
  testWidgets('Hidden letters fit narrow phones with enlarged text', (t) async {
    t.view.physicalSize = const Size(320, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = await store();
    await t.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: HiddenBirdScreen(store: s),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Découvrir une lettre'), 150);
    expect(t.takeException(), isNull);
  });
}
