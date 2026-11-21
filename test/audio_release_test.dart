import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/bird_recording.dart';

void main() {
  test(
    'Released recordings retain source identity, license, interval and honest verification scope',
    () {
      final rows =
          jsonDecode(
                File(
                  'data/editorial/audio-release/recordings.json',
                ).readAsStringSync(),
              )
              as List;
      final species =
          jsonDecode(
                File('assets/data/species_catalog.json').readAsStringSync(),
              )['species']
              as List;
      final recordings = BirdRecording.validated(rows, species);
      expect(recordings.length, rows.length);
      expect(recordings, isNotEmpty);
      expect(recordings.map((r) => r.species).toSet().length, greaterThanOrEqualTo(35));
      final ids = recordings.map((r) => r.id).toSet();
      expect(ids.length, recordings.length);
      final shipped = jsonDecode(File('assets/data/recordings.json').readAsStringSync()) as List;
      expect(shipped.map((r) => r['id']).toSet(), ids);
      for (final row in rows) {
        final verification = row['verification'];
        expect(verification['acoustic_species_validation'], false);
        expect(verification['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(row['end_ms'], lessThanOrEqualTo(verification['duration_ms']));
        expect(
          row['review_note'],
          contains('Pas de certification acoustique humaine'),
        );
      }
      expect(recordings.any((r) => r.vocalization == 'call'), true);
      expect(recordings.any((r) => r.vocalization == 'song'), true);
    },
  );
}
