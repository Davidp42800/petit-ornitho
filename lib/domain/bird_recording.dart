import 'dart:math';

class BirdRecording {
  final String id, species, url, source, author, license, licenseUrl;
  final int startMs, endMs;
  final String vocalization;
  String get label => switch (vocalization) {
    'call' => 'cri',
    'alarm' => 'cri d’alarme',
    'flight' => 'cri de vol',
    _ => 'chant',
  };
  const BirdRecording({
    required this.id,
    required this.species,
    required this.url,
    required this.source,
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.startMs,
    required this.endMs,
    this.vocalization = 'song',
  });

  /// Reject incomplete, disputed or unreviewed recordings, including taxon mismatches.
  static List<BirdRecording> validated(
    List<dynamic> entries,
    List<dynamic> species,
  ) {
    final result = <BirdRecording>[];
    final seen = <String>{};
    bool https(dynamic value) =>
        value is String &&
        Uri.tryParse(value)?.scheme == 'https' &&
        (Uri.tryParse(value)?.host.isNotEmpty ?? false);
    for (final entry in entries) {
      if (entry is! Map) continue;
      final bird = species
          .where((s) => s['id'] == entry['species_id'])
          .firstOrNull;
      if (bird == null ||
          entry['status'] != 'validated' ||
          !{'song', 'call', 'alarm', 'flight'}.contains(entry['type']) ||
          entry['scientific_name'] != bird['latin'] ||
          entry['identification_disputed'] != false ||
          entry['reuse_approved'] != true) {
        continue;
      }
      if (['id', 'author', 'license', 'reviewer', 'review_note'].any(
        (key) => entry[key] is! String || (entry[key] as String).trim().isEmpty,
      )) {
        continue;
      }
      if (!https(entry['url']) ||
          !https(entry['source']) ||
          !https(entry['license_url']) ||
          !RegExp(
            r'^https://creativecommons\.org/(licenses/(by|by-sa)/[0-9.]+|publicdomain/zero/[0-9.]+)/?$',
          ).hasMatch(entry['license_url']) ||
          entry['reviewed_at'] is! String ||
          DateTime.tryParse(entry['reviewed_at']) == null) {
        continue;
      }
      final start = entry['start_ms'], end = entry['end_ms'];
      if (start is! int ||
          end is! int ||
          start < 0 ||
          end <= start ||
          end - start > 30000 ||
          !seen.add(entry['id'])) {
        continue;
      }
      result.add(
        BirdRecording(
          id: entry['id'],
          vocalization: entry['type'],
          species: entry['species_id'],
          url: entry['url'],
          source: entry['source'],
          author: entry['author'],
          license: entry['license'],
          licenseUrl: entry['license_url'],
          startMs: start,
          endMs: end,
        ),
      );
    }
    return result;
  }
}

/// One answer per species, with recordings drawn without replacement.
/// Keeping the deck for the activity also varies the clips on replay.
class BirdRecordingDeck {
  final Random random;
  final Map<String, List<BirdRecording>> _pool = {};
  final Map<String, List<BirdRecording>> _bags = {};
  final Map<String, String> _last = {};

  BirdRecordingDeck(List<BirdRecording> recordings, {Random? random})
    : random = random ?? Random() {
    final ids = <String>{};
    for (final clip in recordings) {
      if (ids.add(clip.id)) {
        (_pool[clip.species] ??= []).add(clip);
      }
    }
  }

  List<BirdRecording> nextRound() {
    final selected = <BirdRecording>[];
    for (final species in _pool.keys) {
      final bag = _bags.putIfAbsent(species, () => []);
      if (bag.isEmpty) {
        bag.addAll(_pool[species]!);
        bag.shuffle(random);
        if (bag.length > 1 && bag.last.id == _last[species]) {
          final previous = bag.removeLast();
          bag.insert(0, previous);
        }
      }
      final clip = bag.removeLast();
      _last[species] = clip.id;
      selected.add(clip);
    }
    return selected..shuffle(random);
  }
}
