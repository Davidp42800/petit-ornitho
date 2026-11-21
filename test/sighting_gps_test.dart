import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/sightings.dart';
import 'package:petit_ornitho/ui/sighting_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Coordinates survive reload, remain private to the profile and reject invalid points',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = Sightings(prefs, 'guest');
      await s.put('robin', latitude: 46.5197, longitude: 6.6323, accuracy: 12);
      expect(Sightings(prefs, 'guest').entry('robin')?['latitude'], 46.5197);
      expect(Sightings(prefs, 'other').entry('robin'), isNull);
      await expectLater(
        s.put('robin', latitude: 91, longitude: 6),
        throwsArgumentError,
      );
      await expectLater(s.put('robin', latitude: 46), throwsArgumentError);
      await expectLater(
        s.put('robin', latitude: double.nan, longitude: 6),
        throwsArgumentError,
      );
      expect(s.entry('robin')?['latitude'], 46.5197);
      await s.put('robin', note: 'Sans point GPS');
      expect(s.entry('robin')?['latitude'], isNull);
    },
  );
  for (final refused in [false, true]) {
    testWidgets(
      'Location request, manual fallback and saving: denied=$refused',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final s = Sightings(await SharedPreferences.getInstance(), 'guest');
        var calls = 0;
        await t.pumpWidget(
          MaterialApp(
            home: SightingEditor(
              sightings: s,
              species: 'robin',
              name: 'Rougegorge familier',
              locate: () async {
                calls++;
                if (refused) throw StateError('Localisation non autorisée.');
                return (latitude: 46.5197, longitude: 6.6323, accuracy: 12.0);
              },
            ),
          ),
        );
        expect(calls, 0);
        await t.ensureVisible(find.text('Utiliser ma position actuelle'));
        await t.tap(find.text('Utiliser ma position actuelle'));
        await t.pumpAndSettle();
        expect(calls, 1);
        final lat = find.byKey(const ValueKey('sighting-latitude')),
            lon = find.byKey(const ValueKey('sighting-longitude'));
        if (refused) {
          expect(find.text('Localisation non autorisée.'), findsOneWidget);
          await t.enterText(lat, '46,5197');
          await t.enterText(lon, '6,6323');
        } else {
          expect(t.widget<TextField>(lat).controller!.text, '46.519700');
          expect(find.text('Précision estimée : ±12 m'), findsOneWidget);
        }
        await t.ensureVisible(find.text('Enregistrer ma coche'));
        await t.tap(find.text('Enregistrer ma coche'));
        await t.pumpAndSettle();
        expect(s.entry('robin')?['latitude'], 46.5197);
        expect(s.entry('robin')?['longitude'], 6.6323);
        expect(t.takeException(), isNull);
      },
    );
  }
}
