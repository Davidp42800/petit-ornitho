import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Personal life list, independent of exercise scores and cloud game state.
class Sightings {
  final SharedPreferences prefs;
  final String identity;
  Sightings(this.prefs, this.identity);

  String get _key => 'ornitho_sightings_v1_$identity';
  String get _recordsKey => 'ornitho_notebook_v2_$identity';
  String get _consentKey => 'ornitho_notebook_sync_$identity';
  bool get cloudEnabled =>
      identity != 'guest' && prefs.getBool(_consentKey) == true;

  Future<void> setCloudEnabled(bool value) async {
    if (identity == 'guest' || !await prefs.setBool(_consentKey, value)) {
      throw StateError('Impossible de modifier la synchronisation.');
    }
  }

  Map<String, dynamic> get _records {
    final saved = prefs.getString(_recordsKey);
    if (saved != null) return Map<String, dynamic>.from(jsonDecode(saved));
    final legacy = Map<String, dynamic>.from(
      jsonDecode(prefs.getString(_key) ?? '{}'),
    );
    return legacy.map(
      (species, observation) => MapEntry(species, {
        'revision': 1,
        'tie': '0000000000000000',
        'observation': observation,
      }),
    );
  }

  Map<String, dynamic> get all => {
    for (final row in _records.entries)
      if (row.value['observation'] != null) row.key: row.value['observation'],
  };

  static int _compare(dynamic a, dynamic b) {
    final cmp = (a['revision'] as int).compareTo(b['revision'] as int);
    return cmp != 0 ? cmp : (a['tie'] as String).compareTo(b['tie'] as String);
  }

  Future<void> synchronize(
    Future<dynamic> Function(String, List<Map<String, dynamic>>) exchange,
  ) async {
    if (!cloudEnabled) return;
    final outgoing = _records.entries
        .map(
          (e) => <String, dynamic>{
            'species': e.key,
            ...Map<String, dynamic>.from(e.value),
          },
        )
        .toList();
    final received = Map<String, dynamic>.from(
      await exchange(identity, outgoing),
    );
    if (!cloudEnabled) return;
    final merged = _records;
    for (final e in received.entries) {
      if (merged[e.key] == null || _compare(e.value, merged[e.key]) >= 0) {
        merged[e.key] = e.value;
      }
    }
    await _save(merged);
  }

  Map<String, dynamic>? entry(String species) {
    final value = all[species];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  Future<void> put(
    String species, {
    String? date,
    String place = '',
    String note = '',
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    if ((latitude == null) != (longitude == null) ||
        (latitude != null && (!latitude.isFinite || latitude.abs() > 90)) ||
        (longitude != null && (!longitude.isFinite || longitude.abs() > 180)) ||
        (accuracy != null &&
            (!accuracy.isFinite || accuracy < 0 || latitude == null))) {
      throw ArgumentError('Coordonnées GPS invalides.');
    }
    await _change(species, {
      'date': date,
      'place': place.trim(),
      'note': note.trim(),
      'latitude': ?latitude,
      'longitude': ?longitude,
      'accuracy': ?accuracy,
    });
  }

  Future<void> remove(String species) => _change(species, null);

  Future<void> _change(
    String species,
    Map<String, dynamic>? observation,
  ) async {
    final values = _records;
    final random = Random.secure();
    final tie = List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    values[species] = {
      'revision': max(
        DateTime.now().microsecondsSinceEpoch,
        ((values[species]?['revision'] as int?) ?? 0) + 1,
      ),
      'tie': tie,
      'observation': observation,
    };
    await _save(values);
  }

  Future<void> _save(Map<String, dynamic> values) async {
    if (!await prefs.setString(_recordsKey, jsonEncode(values))) {
      throw StateError('Impossible de sauvegarder la coche.');
    }
  }
}
