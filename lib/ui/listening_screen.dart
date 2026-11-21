import '../domain/practice_replay.dart';
import 'game_effects.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../data/game_store.dart';
import '../domain/bird_recording.dart';
import 'bird_photo.dart';
import 'components.dart';
import 'garden_backdrop.dart';
import 'pio.dart';
import 'quest_materials.dart';

abstract class BirdAudio {
  Future<void> play(BirdRecording clip);
  Future<void> stop();
  Future<void> dispose();
}

class DeviceBirdAudio implements BirdAudio {
  AudioPlayer? _player;
  bool _disposed = false;
  int _request = 0;

  @override
  Future<void> play(BirdRecording clip) async {
    if (_disposed) return;
    final request = ++_request;
    final previous = _player;
    _player = null;
    await previous?.dispose();
    if (_disposed || request != _request) return;
    // A fresh web element avoids reusing a released source on replay.
    final player = AudioPlayer();
    _player = player;
    await player.setReleaseMode(ReleaseMode.stop);
    if (_disposed || request != _request) return;
    await player.play(
      UrlSource(clip.url),
      position: Duration(milliseconds: clip.startMs),
    );
  }

  @override
  Future<void> stop() async {
    _request++;
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _request++;
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}

class ListeningScreen extends StatefulWidget {
  final GameStore store;
  final bool ultimate;
  final BirdAudio Function()? audioFactory;
  const ListeningScreen({
    super.key,
    required this.store,
    this.ultimate = false,
    this.audioFactory,
  });
  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with WidgetsBindingObserver {
  late final deck = BirdRecordingDeck(
    BirdRecording.validated(
      widget.store.content['recordings'] as List? ?? [],
      widget.store.playableSpecies,
    ),
  );
  late final clips = deck.nextRound();
  late final photos = clips.map((c) => c.species).toList()..shuffle();
  late final sounds = List<BirdRecording>.of(clips)..shuffle();
  BirdAudio? audio;
  Timer? timer;
  int round = 0, generation = 0;
  String? photo, sound, playing, message;
  int attempt = 0;
  final heard = <String>{};
  bool loading = false, solved = false, finished = false;
  BirdRecording get target => clips[round];
  String name(String id) =>
      widget.store.species.firstWhere((s) => s['id'] == id)['name'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  Future<void> stop() async {
    generation++;
    timer?.cancel();
    if (mounted) {
      setState(() {
        playing = null;
        loading = false;
      });
    }
    try {
      await audio?.stop();
    } catch (_) {
      /* A disposed player is already silent. */
    }
  }

  Future<void> listen(BirdRecording clip) async {
    if (loading) return;
    if (playing == clip.id) {
      await stop();
      return;
    }
    timer?.cancel();
    final ticket = ++generation;
    setState(() {
      loading = true;
      message = null;
      playing = null;
    });
    try {
      audio ??= widget.audioFactory?.call() ?? DeviceBirdAudio();
      await audio!.play(clip).timeout(const Duration(seconds: 12));
      if (!mounted || ticket != generation) {
        await audio?.stop();
        return;
      }
      setState(() {
        heard.add(clip.id);
        playing = clip.id;
        loading = false;
      });
      timer = Timer(
        Duration(milliseconds: clip.endMs - clip.startMs),
        () => unawaited(stop()),
      );
    } catch (_) {
      if (!mounted || ticket != generation) return;
      await stop();
      if (mounted) {
        setState(
          () => message =
              'Le son ne se charge pas. Réessaie ou reviens au parcours.',
        );
      }
    }
  }

  void check() {
    if (loading ||
        solved ||
        photo == null ||
        (widget.ultimate ? sound == null : !heard.contains(target.id))) {
      return;
    }
    setState(() {
      solved =
          photo == target.species && (!widget.ultimate || sound == target.id);
      attempt++;
      message = solved
          ? 'Bien joué ! Tu as retrouvé ${name(target.species)}.'
          : 'Pas encore ! Observe les photos et réécoute les sons.';
    });
    unawaited(stop());
  }

  Future<void> next() async {
    await stop();
    if (!mounted) return;
    setState(() {
      if (round + 1 == clips.length) {
        finished = true;
        return;
      }
      round++;
      attempt = 0;
      photo = null;
      sound = null;
      solved = false;
      message = null;
      heard.clear();
      photos.shuffle();
      sounds.shuffle();
    });
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(audio?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.ultimate ? 'Le défi ultime' : 'Qui entends-tu ?'),
    ),
    body: GameEffects(
      event: attempt == 0 ? null : '$round:$attempt',
      success: solved,
      child: GardenBackdrop(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PioGreeting(
                  level: widget.store.unlocked,
                  title: widget.ultimate
                      ? 'Relie les trois !'
                      : 'Ouvre grand tes oreilles !',
                  message: widget.ultimate
                      ? 'Retrouve la photo et le son qui vont avec le nom.'
                      : 'Écoute cet oiseau, puis choisis la photo de l’oiseau.',
                ),
                const SizedBox(height: 16),
                if (clips.length < 2)
                  FieldPaper(
                    child: Column(
                      children: [
                        const Icon(Icons.headphones, size: 64, color: green),
                        const Text(
                          'Les sons se préparent',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pépi attend des enregistrements vérifiés pour te faire découvrir les bonnes voix. En attendant, joue aux lettres ou aux photos.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Retour aux jeux'),
                        ),
                      ],
                    ),
                  )
                else if (finished)
                  FieldPaper(
                    child: Column(
                      children: [
                        Pio(level: widget.store.unlocked, size: 130),
                        const Text(
                          'Bravo, partie terminée !',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text('${clips.length} oiseaux retrouvés'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            final previousFirst = clips.first.species;
                            final previousLast = clips.last.species;
                            clips
                              ..clear()
                              ..addAll(deck.nextRound());
                            varyReplayOpening(clips, (clip) => clip.species, previousFirst, previousLast);
                            photos
                              ..clear()
                              ..addAll(clips.map((c) => c.species))
                              ..shuffle();
                            sounds
                              ..clear()
                              ..addAll(clips)
                              ..shuffle();
                            round = 0;
                            photo = null;
                            sound = null;
                            solved = false;
                            finished = false;
                            attempt = 0;
                            heard.clear();
                            message = null;
                          }),
                          child: const Text('Rejouer'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Retour aux jeux'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  FieldPaper(
                    child: Column(
                      children: [
                        Text(
                          'OISEAU ${round + 1} / ${clips.length}',
                          style: const TextStyle(
                            color: green,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (widget.ultimate)
                          Text(
                            name(target.species),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: ink,
                            ),
                          )
                        else
                          audioButton(target, 'Écouter le son'),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Chargement du son…'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choisis une photo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, c) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          SizedBox(
                            width: c.maxWidth < 340
                                ? c.maxWidth
                                : (c.maxWidth - 12) / 2,
                            child: Semantics(
                              button: true,
                              selected: photo == photos[i],
                              label: 'Photo ${i + 1}',
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    width: 4,
                                    color: photo == photos[i]
                                        ? lime
                                        : Colors.white,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: solved
                                      ? null
                                      : () => setState(() => photo = photos[i]),
                                  child: Column(
                                    children: [
                                      BirdPhoto(
                                        species: photos[i],
                                        media: widget.store.photoFor(photos[i]),
                                        height: 150,
                                        semanticLabel:
                                            'Oiseau de la photo ${i + 1}',
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Text(
                                          '${photo == photos[i] ? '✓ ' : ''}Photo ${i + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.ultimate) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Choisis son enregistrement',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    for (var i = 0; i < sounds.length; i++)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              audioButton(sounds[i], 'Écouter le son ${i + 1}'),
                              OutlinedButton(
                                onPressed:
                                    solved || !heard.contains(sounds[i].id)
                                    ? null
                                    : () =>
                                          setState(() => sound = sounds[i].id),
                                child: Text(
                                  sound == sounds[i].id
                                      ? '✓ Chant ${i + 1} choisi'
                                      : 'Choisir le son ${i + 1}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  if (message != null)
                    FieldPaper(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          message!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (!solved)
                    FilledButton(
                      onPressed:
                          loading ||
                              photo == null ||
                              (widget.ultimate
                                  ? sound == null
                                  : !heard.contains(target.id))
                          ? null
                          : check,
                      child: Text(
                        widget.ultimate
                            ? 'Relier le nom, la photo et le son'
                            : 'Valider ma photo',
                      ),
                    ),
                  if (solved) ...[
                    QuestButton(
                      gold: true,
                      onPressed: next,
                      child: Text(
                        round + 1 == clips.length
                            ? 'Terminer le jeu'
                            : 'Oiseau suivant →',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                    ),
                    FieldPaper(
                      child: Column(
                        children: [
                          Text(
                            '${target.label} : ${target.author} · ${target.license}',
                          ),
                          TextButton(
                            onPressed: () => openSource(context, target.source),
                            child: const Text('Enregistrement original'),
                          ),
                          TextButton(
                            onPressed: () =>
                                openSource(context, target.licenseUrl),
                            child: const Text('Licence du son'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget audioButton(BirdRecording clip, String label) => TextButton.icon(
    onPressed: loading ? null : () => listen(clip),
    icon: Icon(playing == clip.id ? Icons.stop_circle : Icons.play_circle),
    label: Text(playing == clip.id ? 'Arrêter' : label),
  );
}
