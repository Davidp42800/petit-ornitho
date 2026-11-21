import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/game.dart';
import '../domain/decisive_criterion.dart';
import '../domain/ecology_hints.dart';
import '../domain/chapter_progress.dart';
import '../domain/learning.dart';

class GameStore {
  final SharedPreferences prefs;
  final Map<String, dynamic> content;
  final List<dynamic> media;
  final Map<String, dynamic> photoCatalog;
  final Map<String, dynamic> knowledgeCatalog;
  final List<dynamic>? publishedFacts;
  final List<dynamic> cardSupplements;
  final Map<String, dynamic> learningRules;
  final Map<String, dynamic> speciesCatalog;
  final Map<String, dynamic> progression;
  Map<String, dynamic> state = {};
  String? _owner;
  PhotoRotation _photoRotation = PhotoRotation();
  String? _rotationOwner;
  final Future<bool> Function(String key, String value)? persist;
  GameStore(
    this.prefs,
    this.content,
    this.media, {
    this.persist,
    this.photoCatalog = const {},
    this.knowledgeCatalog = const {},
    this.publishedFacts,
    this.cardSupplements = const [],
    this.learningRules = const {},
    this.speciesCatalog = const {},
    this.progression = const {},
  });
  /// Overlapping releases contribute one playable entry per stable question ID.
  static List<dynamic> mergeQuestionCatalogues(List base, List journey) {
    final latest = <String, dynamic>{};
    for (final rows in [base, journey]) {
      for (final row in rows) {
        final id = row['id'] as String;
        final previous = latest[id];
        if (previous == null ||
            (row['version'] ?? 1) > (previous['version'] ?? 1)) {
          latest[id] = row;
        }
      }
    }
    return latest.values.toList();
  }

  static Future<GameStore> load() async {
    final factCatalog = jsonDecode(
      await rootBundle.loadString('assets/data/published_species_facts.json'),
    );
    final store = GameStore(
      await SharedPreferences.getInstance(),
      jsonDecode(await rootBundle.loadString('assets/data/content.json')),
      jsonDecode(await rootBundle.loadString('assets/data/media.json')),
      learningRules: jsonDecode(
        await rootBundle.loadString('assets/data/learning_rules.json'),
      ),
      speciesCatalog: jsonDecode(
        await rootBundle.loadString('assets/data/species_catalog.json'),
      ),
      progression: jsonDecode(
        await rootBundle.loadString('assets/data/progression.json'),
      ),
      publishedFacts: factCatalog['facts'] as List<dynamic>,
      cardSupplements: factCatalog['card_supplements'] ?? const [],
      knowledgeCatalog: jsonDecode(
        await rootBundle.loadString('assets/data/knowledge_catalog.json'),
      ),
      photoCatalog: jsonDecode(
        await rootBundle.loadString('assets/data/photo_catalog.json'),
      ),
    );
    store.content['recordings'] = jsonDecode(
      await rootBundle.loadString('assets/data/recordings.json'),
    );
    store.content['questions'] = mergeQuestionCatalogues(
      store.content['questions'] as List,
      jsonDecode(
        await rootBundle.loadString('assets/data/journey_questions.json'),
      ),
    );
    store.reload();
    return store;
  }

  Future<void> submitContentReport({
    required String speciesId,
    String? questionId,
    int? version,
    String? photo,
    required String comment,
  }) async {
    final id = await client.rpc(
      'submit_content_report',
      params: {
        'p_question_id': questionId,
        'p_question_version': version,
        'p_species_id': speciesId,
        'p_photo_ref': photo,
        'p_comment': comment,
      },
    );
    if (id is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
        ).hasMatch(id)) {
      throw StateError('Missing report acknowledgement');
    }
  }

  SupabaseClient get client => Supabase.instance.client;
  String get identity => client.auth.currentUser?.id ?? 'guest';
  bool get cloud => identity != 'guest';
  String get key => 'ornitho_v1_$identity';
  void reload() {
    final loaded = jsonDecode(prefs.getString(key) ?? '{}');
    if (loaded is! Map<String, dynamic>) {
      throw StateError('Sauvegarde illisible.');
    }
    state = loaded;
    _owner = identity;
  }

  String _captureOwner() {
    if (_owner != identity) reload();
    return identity;
  }

  void _checkOwner(String owner) {
    if (owner != identity || owner != _owner) {
      throw StateError('Le profil a changé.');
    }
  }

  Map<String, dynamic> _snapshot() => jsonDecode(jsonEncode(state));

  /// Persist before exposing the new state. A failed local write can be retried
  /// without applying XP twice. Never write a late response into another profile.
  Future<void> _commit(Map<String, dynamic> next, String owner) async {
    _checkOwner(owner);
    if (!await (persist?.call('ornitho_v1_$owner', jsonEncode(next)) ??
        prefs.setString('ornitho_v1_$owner', jsonEncode(next)))) {
      throw StateError('Sauvegarde impossible.');
    }
    _checkOwner(owner);
    state = next;
  }

  Future<void> save() {
    final owner = _captureOwner();
    return _commit(_snapshot(), owner);
  }

  Future<void> fetchJourneyQuestions() async {
    final owner = _captureOwner();
    final session = active;
    if (owner == 'guest' || session == null) return;
    final cached = state['journey_snapshot'];
    if (cached is Map &&
        cached['owner'] == owner &&
        cached['session'] == session['id'] &&
        (session['ids'] as List).every((id) => cached['questions']?[id] is Map)) {
      return;
    }
    final rows = await client.rpc(
      'journey_questions',
      params: {'p_session': session['id']},
    );
    _checkOwner(owner);
    if (active?['id'] != session['id']) return;
    final delivered = <String, dynamic>{};
    for (final row in rows as List) {
      final question = Map<String, dynamic>.from(row);
      delivered[question['id'] as String] = question;
    }
    if (!(session['ids'] as List).every((id) => delivered[id] is Map)) {
      throw StateError('Instantané de la balade incomplet.');
    }
    await _commit(
      _snapshot()
        ..['journey_snapshot'] = {
          'owner': owner,
          'session': session['id'],
          'questions': delivered,
        },
      owner,
    );
  }

  List<Question> get questions => (content['questions'] as List).map((q) {
    final data = Map<String, dynamic>.from(q);
    if (data['kind'] == 'photo') {
      data['_ecology'] = ecologyHints[data['species_id']];
    }
    return Question(data);
  }).toList();

  /// The three editorial tiers are cumulative; the five journey stages and
  /// existing saves stay compatible. Unknown taxa never enter a planned game.
  int get catalogueLevel => progression.isEmpty
      ? unlocked.clamp(1, 3)
      : unlocked >= 5
      ? 3
      : unlocked >= 3
      ? 2
      : 1;
  int get maxStage => (progression['stages'] as List?)?.length ?? 5;
  String stageName(int stage) =>
      ((progression['stages'] as List?) ?? [])
          .where((s) => s['id'] == stage)
          .firstOrNull?['title'] ??
      const [
        'Premier regard',
        'Aventurier',
        'Explorateur',
        'Ornitho en herbe',
        'Expert',
      ][(stage - 1).clamp(0, 4)];
  String stagePlace(int stage) =>
      ((progression['stages'] as List?) ?? [])
          .where((s) => s['id'] == stage)
          .firstOrNull?['place'] ??
      stageName(stage);
  int speciesStage(String id) =>
      progression['species_stages']?[id] ?? curriculumFor(id)?['level'] ?? 1;
  Map<String, dynamic>? packAt(int stage) {
    final step = ((progression['stages'] as List?) ?? [])
        .where((s) => s['id'] == stage)
        .firstOrNull;
    if (step == null) return null;
    final ids = species
        .where(
          (b) =>
              speciesStage(b['id']) == stage &&
              b['taxonomy_status'] == 'verified',
        )
        .map((b) => b['id'])
        .toSet();
    return {
      'label': step['pack_label'],
      'stage': stage,
      'count': ids.length,
      'audio_species': (content['recordings'] as List? ?? [])
          .where(
            (r) => r['status'] == 'validated' && ids.contains(r['species_id']),
          )
          .map((r) => r['species_id'])
          .toSet()
          .length,
      'photo_species': ((photoCatalog['species'] as List?) ?? [])
          .where((b) => ids.contains(b['id']))
          .length,
    };
  }

  String get catalogueLevelLabel =>
      const ['Lancement', 'Courant', 'Expert'][catalogueLevel - 1];
  Map<String, dynamic>? curriculumFor(String id) =>
      ((speciesCatalog['species'] as List?) ?? [])
          .where((b) => b['id'] == id)
          .cast<Map<String, dynamic>>()
          .firstOrNull;
  bool speciesAvailable(String id, [int? stage]) {
    // Explicitly injected legacy fixtures have no curriculum. Production always
    // loads the versioned catalogue, including when playing without an account.
    if (speciesCatalog.isEmpty) return true;
    final bird = curriculumFor(id);
    return bird != null &&
        bird['taxonomy_status'] == 'verified' &&
        (progression.isNotEmpty
            ? speciesStage(id) <= (stage ?? unlocked)
            : (bird['level'] as int) <= (stage ?? catalogueLevel).clamp(1, 3));
  }

  List<dynamic> get playableSpecies =>
      species.where((b) => speciesAvailable(b['id'])).toList();
  List<Question> get practiceQuestions => questions
      .where(
        (q) =>
            speciesAvailable(q.species) &&
            q.data['format'] != 'decisive_criterion',
      )
      .toList();
  List<Question> learningRound([Random? random]) {
    final pool = ((knowledgeCatalog['questions'] as List?) ?? [])
        .map((q) => Question(Map<String, dynamic>.from(q)))
        .where(
          (q) =>
              speciesAvailable(q.species) &&
              q.data['format'] != 'decisive_criterion',
        )
        .toList();
    if (pool.isEmpty) {
      return practiceQuestions.where((q) => q.kind == 'quiz').toList();
    }
    return revisionRound(
      pool,
      (q) => q.species,
      'knowledge',
      skills,
      random ?? Random(),
      DateTime.now(),
      6,
    );
  }

  /// Only the notebook includes local archive extracts alongside published facts.
  List<Map<String, dynamic>> sourcedFactsFor(
    String id, {
    bool forNotebook = false,
  }) {
    if (publishedFacts != null) {
      final facts = forNotebook
          ? publishedFacts!.followedBy(cardSupplements)
          : publishedFacts!;
      return facts
          .where((f) => f['species_id'] == id)
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
    }
    // Compatibility for injected catalogues; resolve each fact's own document.
    final documents = {
      for (final d in (knowledgeCatalog['documents'] as List? ?? []))
        d['id']: d,
    };
    return [
      for (final f in (knowledgeCatalog['facts'] as List? ?? []))
        if (f['species_id'] == id &&
            f['status'] == 'published' &&
            documents[f['document_id']]?['url'] != null)
          {
            ...Map<String, dynamic>.from(f),
            'source_url': documents[f['document_id']]['url'],
            'document_title': documents[f['document_id']]['title'],
            'publisher': 'Source documentaire',
          },
    ];
  }

  List<dynamic> get species {
    final merged = <String, dynamic>{};
    for (final bird in [
      ...((speciesCatalog['species'] as List?) ?? []),
      ...content['species'],
      ...((photoCatalog['species'] as List?) ?? []),
      ...((knowledgeCatalog['species'] as List?) ?? []),
    ]) {
      if (speciesCatalog.isNotEmpty && curriculumFor(bird['id']) == null) {
        continue;
      }
      final previous = merged[bird['id']];
      merged[bird['id']] = {
        ...?previous,
        ...bird,
        'facts': <dynamic>{...?previous?['facts'], ...?bird['facts']}.toList(),
        'clues': (bird['clues'] as List?)?.isNotEmpty == true
            ? bird['clues']
            : previous?['clues'] ?? <String>[],
      };
    }
    return merged.values
        .map(
          (b) => {
            ...b, ...?curriculumFor(b['id']),
            // Curriculum metadata cannot erase reviewed scientific content.
            'facts': b['facts'], 'clues': b['clues'],
            'source': b['source'], 'publisher': b['publisher'],
          },
        )
        .toList();
  }

  Map<String, dynamic>? photoFor(String speciesId) {
    final bird = ((photoCatalog['species'] as List?) ?? [])
        .where((s) => s['id'] == speciesId)
        .firstOrNull;
    return bird == null || (bird['photos'] as List).isEmpty
        ? null
        : Map<String, dynamic>.from((bird['photos'] as List).first);
  }

  List<Question> photoRound([Random? random, Set<String>? scope]) =>
      _photoRound(random, scope);

  List<Question> imageChoiceRound([Random? random]) {
    final rng = random ?? Random();
    return photoRound(rng).where((q) => q.data['option_species'] != null).map((
      q,
    ) {
      final ids = List<String>.from(q.data['option_species']);
      final images = ids.map((id) {
        if (id == q.species) return q.data['photo'];
        final bird = (photoCatalog['species'] as List).firstWhere(
          (b) => b['id'] == id,
        );
        return _photoRotation.pick(
          List<dynamic>.from(bird['photos']),
          mediaSeen,
          rng,
        );
      }).toList();
      final target = q.options[q.answer];
      return Question({
        ...q.data,
        'prompt':
            'Mission jumelles : retrouve cet oiseau parmi les photos !\n$target',
        'image_options': images,
      });
    }).toList();
  }

  /// Complete shuffled deck: every available species exactly once per cycle.
  /// Timed play deliberately does not reuse the due-review weighting.
  List<Question> chronoRound([Random? random, String? previousSpecies]) =>
      _photoRound(
        random,
        speciesCatalog.isEmpty
            ? (learningRules['launch_species'] as List?)?.cast<String>().toSet()
            : null,
        fullDeck: true,
        previousSpecies: previousSpecies,
      );

  List<Question> _photoRound(
    Random? random,
    Set<String>? scope, {
    bool fullDeck = false,
    String? previousSpecies,
  }) {
    final rng = random ?? Random();
    if (_rotationOwner != _owner) {
      _photoRotation = PhotoRotation();
      _rotationOwner = _owner;
    }
    final pool = List<dynamic>.of((photoCatalog['species'] as List?) ?? [])
        .where(
          (b) =>
              speciesAvailable(b['id']) &&
              (scope == null || scope.contains(b['id'])),
        )
        .toList();
    if (pool.length < 4) {
      return practiceQuestions.where((q) => q.kind == 'photo').toList();
    }
    final targets = fullDeck
        ? (List<dynamic>.of(pool)..shuffle(rng))
        : revisionRound(
            pool,
            (b) => b['id'] as String,
            'visual',
            skills,
            rng,
            DateTime.now(),
            4,
          );
    if (fullDeck &&
        targets.length > 1 &&
        targets.first['id'] == previousSpecies) {
      targets.add(targets.removeAt(0));
    }
    return targets.map((bird) {
      final chosenPhoto = _photoRotation.pick(
        List<dynamic>.of(bird['photos']),
        mediaSeen,
        rng,
      );
      final distractors = plausibleChoices(
        bird,
        pool,
        learningRules,
        attempts,
        rng,
      );
      final options = [bird, ...distractors.take(3)]..shuffle(rng);
      return Question({
        'id': 'discovery_${chosenPhoto['id']}',
        'species_id': bird['id'],
        'kind': 'photo',
        'prompt': 'Quel oiseau observes-tu ?',
        'options': options.map((b) => b['name']).toList(),
        'option_species': options.map((b) => b['id']).toList(),
        'answer': options.indexOf(bird),
        'hint': chosenPhoto['hint'],
        'explanation':
            chosenPhoto['explanation'] ??
            'Observe le bec, la silhouette et les couleurs de ${bird['name']}.',
        'source': chosenPhoto['source'],
        'publisher': 'iNaturalist — photographie attribuée',
        'clues': <String>[],
        'asset': chosenPhoto['asset'],
        'photo': chosenPhoto,
      });
    }).toList();
  }

  Map<String, dynamic> get mediaSeen {
    final seen = Map<String, dynamic>.from(state['media_seen'] ?? {});
    for (final a in attempts) {
      final id =
          a['photo_id'] ??
          (a['modality'] == 'visual' ? (a['rpc']?['p_ref']) : null);
      final time = a['answered_at'];
      if (id != null &&
          time is String &&
          (seen[id] == null || time.compareTo(seen[id]) > 0)) {
        seen[id] = time;
      }
    }
    return seen;
  }

  Map<String, dynamic> get skills =>
      Map<String, dynamic>.from(state['skills'] ?? {});
  List<dynamic> get attempts =>
      List<dynamic>.from(state['learning_attempts'] ?? []);
  int get dueCount => skills.values.where((s) {
    final due = DateTime.tryParse(s['due_at'] ?? '');
    return due != null && !due.isAfter(DateTime.now());
  }).length;

  Future<void> recordPractice(
    Question q,
    int choice,
    String attemptId,
    int responseMs, {
    bool assisted = false,
  }) async {
    // This one-choice protocol cannot prove the second step of a comparison.
    // These challenges use answerCriterion in a saved journey instead.
    if (q.data['format'] == 'decisive_criterion') {
      throw StateError(
        'Ce défi demande une identification et une justification.',
      );
    }
    final owner = _captureOwner();
    if (choice < 0 || choice >= q.options.length) {
      throw ArgumentError('Choix invalide');
    }
    final existing = attempts.where((a) => a['id'] == attemptId).firstOrNull;
    if (existing != null) {
      if (existing['choice'] != choice || existing['question'] != q.id) {
        throw StateError('Réponse différente');
      }
      await syncLearning();
      return;
    }
    final now = DateTime.now().toUtc();
    final modality = q.kind == 'photo'
        ? 'visual'
        : q.kind == 'audio'
        ? 'audio'
        : 'knowledge';
    final supported =
        q.data['photo'] != null ||
        q.data['recording_id'] != null ||
        q.data['fact_id'] != null;
    final options = q.data['option_species'] ?? q.options;
    final row = <String, dynamic>{
      'id': attemptId,
      'question': q.id,
      'photo_id': q.data['photo']?['id'],
      'target_species': q.species,
      'chosen_species': q.data['option_species']?[choice],
      'modality': modality,
      'correct': choice == q.answer,
      'choice': choice,
      'assisted': assisted,
      'answered_at': now.toIso8601String(),
      'response_ms': responseMs.clamp(0, 3600000),
      'pending': owner != 'guest' && supported,
      'rpc': {
        'p_id': attemptId,
        'p_kind': modality,
        'p_ref': q.data['photo']?['id'] ?? q.data['recording_id'] ?? q.id,
        'p_version': q.data['version'] ?? 1,
        'p_choice': choice,
        'p_options': options,
        'p_assisted': assisted,
        'p_response_ms': responseMs.clamp(0, 3600000),
      },
    };
    final next = _snapshot();
    next['learning_attempts'] = [...attempts, row];
    final updated = skills;
    updated['${q.species}:$modality'] = scheduleSkill(
      updated['${q.species}:$modality'],
      choice == q.answer,
      assisted,
      now,
    );
    next['skills'] = updated;
    await _commit(next, owner);
    await syncLearning();
  }

  Future<void> syncLearning() async {
    final owner = _captureOwner();
    if (owner == 'guest') return;
    for (final a in attempts.where((a) => a['pending'] == true)) {
      await client.rpc(
        'record_practice_attempt',
        params: Map<String, dynamic>.from(a['rpc']),
      );
      _checkOwner(owner);
      final next = _snapshot();
      for (final row in next['learning_attempts'] as List) {
        if (row['id'] == a['id']) row['pending'] = false;
      }
      await _commit(next, owner);
    }
    final rows = await client.from('player_skill').select();
    final seen = await client.rpc('learning_media_history');
    _checkOwner(owner);
    final next = _snapshot();
    next['media_seen'] = seen;
    next['skills'] = {
      for (final row in rows) '${row['species_id']}:${row['modality']}': row,
    };
    await _commit(next, owner);
  }

  int get xp => state['xp'] ?? 0;
  bool audioAvailableInStage(int stage) => questions.any(
    (q) =>
        q.kind == 'audio' &&
        questionPlayable(q) &&
        (q.data['route_stages'] as List? ?? []).contains(stage),
  );

  ChapterProgress chapterProgress(int stage) {
    final remote = (state['chapter_objectives'] as Map?)?[stage.toString()];
    if (identity != 'guest') {
      return remote is Map
          ? ChapterProgress.fromJson(remote)
          : ChapterProgress({}, ChapterProgress.policies[stage] ?? {});
    }
    return ChapterProgress.evaluate(
      stage,
      attempts,
      state['chapter_sessions'] as List? ?? [],
    );
  }

  int get completed => state['completed'] ?? 0;
  int get unlocked => (state['unlocked'] ?? 1) as int;
  Map<String, dynamic>? get active => state['active'] == null
      ? null
      : Map<String, dynamic>.from(state['active']);
  Map<String, dynamic> get mastery =>
      Map<String, dynamic>.from(state['mastery'] ?? {});
  Set<String> get withdrawnQuestions =>
      (prefs.getStringList('question_withdrawals_v1') ?? []).toSet();

  bool questionPlayable(Question q) =>
      !withdrawnQuestions.contains('${q.id}@${q.data['version'] ?? 1}');

  Future<void> syncQuestionWithdrawals() async {
    try {
      final rows = await client
          .from('question_withdrawals')
          .select('id,version')
          .timeout(const Duration(seconds: 3));
      final mediaRows = await client
          .from('media_question_withdrawals')
          .select('id,version')
          .timeout(const Duration(seconds: 3));
      final values = [
        ...rows,
        ...mediaRows,
      ].map((r) => '${r['id']}@${r['version']}').toList();
      await prefs.setStringList('question_withdrawals_v1', values);
    } catch (_) {
      // Offline: retain the last known withdrawal list.
    }
  }

  Future<void> refresh() async {
    await syncQuestionWithdrawals();
    final owner = _captureOwner();
    if (owner == 'guest') return;
    final result = Map<String, dynamic>.from(await client.rpc('player_state'));
    _checkOwner(owner);
    await _commit(_snapshot()..addAll(result), owner);
    await syncLearning();
  }

  Future<void> restartJourney() async {
    final owner = _captureOwner();
    final next = _snapshot();
    final session = active;
    if (session == null) return;
    if (owner != 'guest') {
      next['active'] = await client.rpc(
        'restart_journey',
        params: {'p_session': session['id']},
      );
      await _commit(next, owner);
      await fetchJourneyQuestions();
    } else {
      next.remove('active');
      await _commit(next, owner);
      await start(session['level'] as int);
    }
  }

  Future<void> start(int level) async {
    await syncQuestionWithdrawals();
    final owner = _captureOwner();
    if (level < 1 || level > unlocked || level > maxStage) {
      throw StateError('Cette étape n’est pas encore ouverte.');
    }
    if (active != null) {
      if (active!['level'] != level) {
        throw StateError('Une autre balade est en cours.');
      }
      return;
    }
    for (final q in questions) {
      q.data.remove('_hint_used');
    }
    final next = _snapshot();
    if (owner != 'guest') {
      next['active'] = await client.rpc(
        'start_garden',
        params: {'p_level': level},
      );
    } else {
      final history = List<String>.from(next['history'] ?? []);
      final ids = SessionGenerator().generate(
        questions
            .where(
              (q) =>
                  questionPlayable(q) &&
                  (q.kind != 'quiz' || photoFor(q.species) != null) &&
                  speciesAvailable(q.species, level) &&
                  (progression.isEmpty ||
                      (q.data['route_stages'] as List? ?? []).contains(level)),
            )
            .toList(),
        history.toSet(),
        level,
      );
      next['history'] = [...history, ids.join('|')];
      next['active'] = {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'ids': ids,
        'index': 0,
        'answers': <dynamic>[],
        'hints': 1,
        'level': level,
        'score': 0,
      };
    }
    await _commit(next, owner);
  }

  Question? get currentOrNull {
    final session = active;
    final ids = session?['ids'];
    final index = session?['index'];
    if (ids is! List || index is! int || index < 0 || index >= ids.length) {
      return null;
    }
    if (identity != 'guest') {
      final cached = state['journey_snapshot'];
      if (cached is! Map ||
          cached['owner'] != identity ||
          cached['session'] != session!['id']) {
        return null;
      }
      final data = cached['questions']?[ids[index]];
      if (data is! Map) return null;
      final question = Map<String, dynamic>.from(data);
      if (question['kind'] == 'photo') {
        question['_ecology'] = ecologyHints[question['species_id']];
      }
      return Question(question);
    }
    return questions.where((q) => q.id == ids[index]).firstOrNull;
  }

  Question get current =>
      currentOrNull ??
      (throw StateError(
        'Cette mission nécessite une mise à jour du catalogue.',
      ));

  /// Persist assistance before displaying it, including after pause/reload.
  Future<void> registerGuideHint() async {
    final owner = _captureOwner();
    final next = _snapshot();
    final a = next['active'] as Map<String, dynamic>?;
    if (a == null || a['feedback'] != null) return;
    if (owner != 'guest') {
      next['active'] = await client.rpc(
        'use_garden_hint',
        params: {
          'p_session': a['id'],
          'p_index': a['index'],
          'p_expected_hints': a['hints'],
        },
      );
    } else {
      a['assisted'] = true;
      a['hints'] = ((a['hints'] as int) + 1).clamp(1, 3);
    }
    await _commit(next, owner);
  }

  Future<void> registerSpellingHelp() async {
    final owner = _captureOwner();
    final next = _snapshot();
    final a = next['active'] as Map<String, dynamic>?;
    if (a == null || a['feedback'] != null) return;
    if (owner != 'guest') {
      next['active'] = await client.rpc(
        'mark_spelling_help',
        params: {'p_session': a['id'], 'p_index': a['index']},
      );
    } else if (a['spelling_help_index'] != a['index']) {
      a['hints'] = ((a['hints'] as int) + 1).clamp(1, 3);
      a['spelling_help_index'] = a['index'];
      a['assisted'] = true;
    }
    await _commit(next, owner);
  }

  Future<void> hint() async {
    final owner = _captureOwner();
    final q = current;
    final next = _snapshot();
    final a = next['active'] as Map<String, dynamic>;
    if (q.kind != 'mystery' ||
        a['feedback'] != null ||
        a['hints'] >= q.clues.length) {
      return;
    }
    if (owner != 'guest') {
      next['active'] = await client.rpc(
        'reveal_hint',
        params: {'p_session': a['id']},
      );
    } else {
      a['hints']++;
    }
    await _commit(next, owner);
  }

  Future<Map<String, dynamic>> answer(int selected) async {
    if (current.data['format'] == 'decisive_criterion') {
      throw StateError(
        'Ce défi demande une identification et une justification.',
      );
    }
    return _answer(selected);
  }

  Future<DecisiveCriterion> answerCriterion(
    CriterionPhase expectedPhase,
    int selected,
  ) async {
    final owner = _captureOwner();
    final q = current;
    final next = _snapshot();
    final a = next['active'] as Map<String, dynamic>;
    if (owner != 'guest') {
      final result = Map<String, dynamic>.from(
        await client.rpc(
          'answer_garden_criterion',
          params: {
            'p_session': a['id'],
            'p_index': a['index'],
            'p_version': q.data['version'] ?? 1,
            'p_phase': expectedPhase.name,
            'p_choice': selected,
          },
        ),
      );
      final progress = DecisiveCriterion.restore(
        q.data,
        Map<String, dynamic>.from(result['criterion']),
      );
      next['active'] = result;
      await _commit(next, owner);
      return progress;
    }
    var progress = a['criterion'] == null
        ? DecisiveCriterion.start(q.data)
        : DecisiveCriterion.restore(
            q.data,
            Map<String, dynamic>.from(a['criterion']),
          );
    progress = progress.choose(q.data, expectedPhase, selected);
    if (a['hints'] > 1 ||
        a['assisted'] == true ||
        q.data['_hint_used'] == true) {
      progress = progress.withAssistance();
    }
    a['criterion'] = progress.toJson();
    if (progress.phase(q.data) == null) {
      // Persist both the final answer and its single reward in one commit.
      await _answer(
        progress.identificationChoices.first,
        criterion: progress,
        pending: next,
      );
    } else {
      await _commit(next, owner);
    }
    return progress;
  }

  Future<Map<String, dynamic>> _answer(
    int selected, {
    DecisiveCriterion? criterion,
    Map<String, dynamic>? pending,
  }) async {
    final owner = _captureOwner();
    final q = current;
    final next = pending ?? _snapshot();
    final a = next['active'] as Map<String, dynamic>;
    if (a['feedback'] != null) return Map<String, dynamic>.from(a['feedback']);
    if (selected < 0 || selected >= q.options.length) {
      throw ArgumentError('Choix invalide.');
    }
    Map<String, dynamic> feedback;
    if (owner != 'guest') {
      final result = Map<String, dynamic>.from(
        await client.rpc(
          'answer_garden',
          params: {
            'p_session': a['id'],
            'p_index': a['index'],
            'p_choice': selected,
          },
        ),
      );
      feedback = Map<String, dynamic>.from(result['feedback']);
      next['active'] = result;
    } else {
      final correct = criterion == null
          ? selected == q.answer
          : CriterionPhase.values.every(
              (step) => criterion.firstTryCorrect(q.data, step),
            );
      final points = reward(correct, a['hints']);
      feedback = {
        'correct': correct,
        'choice': selected,
        'answer': q.answer,
        'points': points,
        if (criterion != null) 'criterion': criterion.toJson(),
      };
      a['feedback'] = feedback;
      a['score'] += points;
      final m = Map<String, dynamic>.from(next['mastery'] ?? {});
      final entry = Map<String, dynamic>.from(
        m[q.species] ?? {'seen': 0, 'correct': 0},
      );
      entry['seen']++;
      if (correct) entry['correct']++;
      m[q.species] = entry;
      next['mastery'] = m;
      final modality = q.kind == 'photo'
          ? 'visual'
          : q.kind == 'audio'
          ? 'audio'
          : 'knowledge';
      final now = DateTime.now().toUtc();
      next['learning_attempts'] = [
        ...attempts,
        {
          'id': newAttemptId(),
          'question': q.id,
          'stage': a['level'],
          'session_id': a['id'],
          'protocol': 2,
          'reference': modality == 'audio'
              ? (q.data['recording']?['id'])
              : modality == 'visual'
              ? (q.data['photo']?['id'] ?? q.data['asset'])
              : (q.data['fact_id'] ?? q.id),
          'target_species': q.species,
          'chosen_species': species
              .where((b) => b['name'] == q.options[selected])
              .firstOrNull?['id'],
          'choice': selected,
          if (criterion != null) ...{
            'identification_correct': criterion.firstTryCorrect(
              q.data,
              CriterionPhase.identification,
            ),
            'justification_correct': criterion.firstTryCorrect(
              q.data,
              CriterionPhase.justification,
            ),
            'criterion': criterion.toJson(),
          },
          'correct': correct,
          'assisted':
              criterion?.assisted == true ||
              a['hints'] > 1 ||
              a['assisted'] == true ||
              q.data['_hint_used'] == true,
          'modality': modality,
          'answered_at': now.toIso8601String(),
          'pending': false,
        },
      ];
      final updatedSkills = skills;
      updatedSkills['${q.species}:$modality'] = scheduleSkill(
        updatedSkills['${q.species}:$modality'],
        correct,
        criterion?.assisted == true ||
            a['hints'] > 1 ||
            a['assisted'] == true ||
            q.data['_hint_used'] == true,
        now,
      );
      next['skills'] = updatedSkills;
    }
    await _commit(next, owner);
    return feedback;
  }

  Future<Map<String, dynamic>?> next() async {
    final owner = _captureOwner();
    if (active == null || active!['feedback'] == null) return null;
    final nextState = _snapshot();
    final a = nextState['active'] as Map<String, dynamic>;
    final question = currentOrNull;
    final previous = nextState['journey_recap'];
    final entries = <String, dynamic>{
      if (previous is Map &&
          previous['session'] == a['id'] &&
          previous['entries'] is Map)
        ...Map<String, dynamic>.from(previous['entries'] as Map),
    };
    if (question != null && a['feedback']['correct'] is bool) {
      final name = species
          .where((bird) => bird['id'] == question.species)
          .firstOrNull?['name'];
      if (name is String && name.isNotEmpty) {
        entries['${a['index']}'] = {
          'name': name,
          'correct': a['feedback']['correct'],
          'assisted':
              a['assisted'] == true ||
              (a['hints'] ?? 1) > 1 ||
              a['criterion']?['assisted'] == true ||
              question.data['_hint_used'] == true,
        };
      }
    }
    nextState['journey_recap'] = {'session': a['id'], 'entries': entries};
    if (owner != 'guest') {
      final result = Map<String, dynamic>.from(
        await client.rpc(
          'advance_garden',
          params: {'p_session': a['id'], 'p_index': a['index']},
        ),
      );
      if (result['done'] == true) {
        // Keep the acknowledged question on screen if refresh fails; the same
        // idempotent advance RPC can safely return this completion on retry.
        final refreshed = Map<String, dynamic>.from(
          await client.rpc('player_state'),
        );
        nextState.addAll(refreshed);
        result['recap'] = entries.values.toList();
        nextState.remove('journey_recap');
        nextState['last'] = result;
        await _commit(nextState, owner);
        return result;
      }
      nextState['active'] = result;
      await _commit(nextState, owner);
      return null;
    }
    final answers = List<dynamic>.from(a['answers'])..add(a['feedback']);
    a['answers'] = answers;
    if (a['index'] == (a['ids'] as List).length - 1) {
      final correct = answers.where((x) => x['correct'] == true).length;
      nextState['xp'] = xp + (a['score'] as int);
      nextState['completed'] = completed + 1;
      nextState['chapter_sessions'] = [
        ...(nextState['chapter_sessions'] as List? ?? []),
        {'id': a['id'], 'stage': a['level'], 'total': answers.length},
      ];
      final objectives = ChapterProgress.evaluate(
        a['level'],
        nextState['learning_attempts'] as List? ?? [],
        nextState['chapter_sessions'],
      );
      if (objectives.ready && a['level'] == unlocked && unlocked < maxStage) {
        nextState['unlocked'] = unlocked + 1;
      }
      nextState.remove('journey_recap');
      final result = {
        'recap': entries.values.toList(),
        'done': true,
        'score': a['score'],
        'correct': correct,
        'total': answers.length,
        'level': a['level'],
        'chapter_objectives': objectives.toJson(),
        if (nextState['unlocked'] != unlocked && nextState['unlocked'] != null)
          'unlocked_pack': packAt(nextState['unlocked']),
      };
      nextState['last'] = result;
      nextState['active'] = null;
      await _commit(nextState, owner);
      return result;
    }
    a['index']++;
    a['hints'] = 1;
    a.remove('assisted');
    a.remove('feedback');
    a.remove('criterion');
    await _commit(nextState, owner);
    return null;
  }
}
