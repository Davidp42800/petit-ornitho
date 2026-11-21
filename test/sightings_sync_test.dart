import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/sightings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Account consent, retry, guest isolation, concurrent edits and deletion',
    () async {
      SharedPreferences.setMockInitialValues({
        'ornitho_sightings_v1_owner': '{"robin":{"note":"Archive"}}',
        'ornitho_sightings_v1_guest': '{"wren":{"note":"Invité"}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final book = Sightings(prefs, 'owner');
      final guest = Sightings(prefs, 'guest');
      final other = Sightings(prefs, 'other');
      expect(book.entry('robin')?['note'], 'Archive');
      await book.synchronize((_, _) async => fail('upload before consent'));
      await guest.synchronize((_, _) async => fail('guest upload'));
      await book.setCloudEnabled(true);
      expect(other.cloudEnabled, isFalse);
      await expectLater(
        book.synchronize((_, _) async => throw StateError('offline')),
        throwsStateError,
      );
      expect(book.entry('robin')?['note'], 'Archive');

      final remote = Completer<Map<String, dynamic>>();
      final pending = book.synchronize((owner, changes) async {
        expect(owner, 'owner');
        expect(changes.single['species'], 'robin');
        return remote.future;
      });
      await book.put('robin', note: 'Édition pendant la requête');
      remote.complete({
        'robin': {
          'revision': 2,
          'tie': '0000000000000001',
          'observation': {'note': 'Autre appareil'},
        },
        'owl': {
          'revision': 4,
          'tie': '0000000000000002',
          'observation': {'note': 'Arrivée distante'},
        },
      });
      await pending;
      expect(book.entry('robin')?['note'], 'Édition pendant la requête');
      expect(book.entry('owl')?['note'], 'Arrivée distante');
      await book.remove('owl');
      await book.synchronize((_, changes) async {
        expect(
          changes.singleWhere((c) => c['species'] == 'owl')['observation'],
          isNull,
        );
        return {
          'owl': {
            'revision': 4,
            'tie': '0000000000000002',
            'observation': {'note': 'Ancienne coche'},
          },
        };
      });
      expect(Sightings(prefs, 'owner').entry('owl'), isNull);
      expect(other.all, isEmpty);
      expect(guest.all.keys, ['wren']);
      await book.setCloudEnabled(false);
      await book.synchronize((_, _) async => fail('upload after pause'));
    },
  );
}
