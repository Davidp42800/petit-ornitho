import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/sightings.dart';
import 'package:petit_ornitho/ui/sighting_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Coches persistantes, uniques et séparées entre profils et jeu',
    () async {
      SharedPreferences.setMockInitialValues({'ornitho_v1_guest': '{"xp":75}'});
      final prefs = await SharedPreferences.getInstance();
      final guest = Sightings(prefs, 'guest');
      await guest.put(
        'robin',
        date: '2026-09-30',
        place: ' Lausanne ',
        note: ' Jardin ',
      );
      final reloaded = Sightings(prefs, 'guest');
      expect(reloaded.entry('robin')?['place'], 'Lausanne');
      expect(reloaded.entry('robin')?['date'], '2026-09-30');
      expect(Sightings(prefs, 'another-user').all, isEmpty);
      await reloaded.put('robin', note: 'Nouvelle note');
      expect(reloaded.all.length, 1);
      expect(reloaded.entry('robin')?['date'], isNull);
      await reloaded.remove('robin');
      expect(reloaded.all, isEmpty);
      expect(prefs.getString('ornitho_v1_guest'), '{"xp":75}');
    },
  );

  testWidgets('Ajouter, modifier, annuler puis retirer une coche sur mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = Sightings(await SharedPreferences.getInstance(), 'guest');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SightingEditor(
                    sightings: store,
                    species: 'robin',
                    name: 'Rougegorge familier',
                  ),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.tap(find.text('Ajouter une date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sighting-place')),
      'Lausanne',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('sighting-note')),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('sighting-note')),
      'Dans le jardin',
    );
    await tester.scrollUntilVisible(
      find.text('Enregistrer ma coche'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer ma coche'));
    await tester.pumpAndSettle();
    expect(store.entry('robin')?['note'], 'Dans le jardin');
    expect(store.entry('robin')?['date'], isNotNull);
    await open();
    expect(find.text('Lausanne'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('sighting-place')),
      'Berne',
    );
    await tester.scrollUntilVisible(
      find.text('Enregistrer ma coche'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer ma coche'));
    await tester.pumpAndSettle();
    expect(store.entry('robin')?['place'], 'Berne');
    await open();
    await tester.scrollUntilVisible(
      find.text('Retirer ma coche'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer ma coche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garder'));
    await tester.pumpAndSettle();
    expect(store.entry('robin'), isNotNull);
    await tester.tap(find.text('Retirer ma coche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    expect(store.entry('robin'), isNull);
    expect(tester.takeException(), isNull);
  });
}
