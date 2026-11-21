import 'journey_option_order.dart';
import 'quest_materials.dart';
import 'pio.dart';
import 'dart:async';
import 'dart:math' as math;
import 'game_effects.dart';
import 'package:flutter/material.dart';
import '../domain/bird_recording.dart';
import '../domain/game.dart';
import 'bird_photo.dart';
import 'components.dart';
import 'listening_screen.dart';
import 'naturalist_guide.dart';

/// An audio question within the saved journey, not a separate free game.
class AudioMission extends StatefulWidget {
  final Question question;
  final BirdRecording recording;
  final dynamic feedback;
  final bool busy;
  final String? saveError;
  final int step, total;
  final int level;
  final ValueChanged<int> onAnswer;
  final VoidCallback onNext, onPause;
  final VoidCallback? onModerate, onRestart;
  final Future<bool> Function() beforeHint;
  final BirdAudio Function()? audioFactory;
  final VoidCallback? onReport;
  const AudioMission({
    this.onReport,
    super.key,
    required this.question,
    required this.recording,
    required this.feedback,
    required this.busy,
    this.saveError,
    required this.step,
    required this.total,
    this.level = 1,
    required this.onAnswer,
    required this.onNext,
    required this.onPause,
    required this.beforeHint,
    this.audioFactory,
    this.onModerate,
    this.onRestart,
  });
  @override
  State<AudioMission> createState() => _AudioMissionState();
}

class _AudioMissionState extends State<AudioMission>
    with WidgetsBindingObserver {
  BirdAudio? audio;
  Timer? timer;
  bool loading = false, playing = false, heard = false;
  String? error;
  int ticket = 0;
  final eliminated = <int>{};
  int? wrongCard;
  bool recovered = false, submitting = false;
  bool readingPaused = false;
  int effectTick = 0;
  Timer? feedbackTimer, advanceTimer;
  bool get solved => recovered || widget.feedback?['correct'] == true;

  void wrong(int index) {
    feedbackTimer?.cancel();
    setState(() {
      wrongCard = index;
      effectTick++;
    });
    feedbackTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        eliminated.add(index);
        wrongCard = null;
      });
    });
  }

  void celebrate() {
    setState(() => effectTick++);
    // Reading has no time limit; only Suivant advances the journey.
  }

  void choose(int index) {
    if (submitting ||
        widget.busy ||
        solved ||
        wrongCard != null ||
        eliminated.contains(index)) {
      return;
    }
    unawaited(stop());
    if (widget.feedback == null) {
      submitting = true;
      widget.onAnswer(index);
    } else if (index == widget.feedback['answer']) {
      setState(() => recovered = true);
      celebrate();
    } else {
      wrong(index);
    }
  }

  @override
  void didUpdateWidget(covariant AudioMission old) {
    super.didUpdateWidget(old);
    if (!widget.busy) submitting = false;
    if (old.feedback == null && widget.feedback != null) {
      if (widget.feedback['correct'] == true) {
        celebrate();
      } else {
        wrong(widget.feedback['choice'] as int);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.feedback != null) {
      heard = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (solved) {
          celebrate();
        } else {
          wrong(widget.feedback['choice'] as int);
        }
      });
    }
  }

  Future<void> stop() async {
    ticket++;
    timer?.cancel();
    final player = audio;
    audio = null;
    if (mounted) {
      setState(() {
        playing = false;
        loading = false;
      });
    }
    try {
      await player?.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  @override
  void dispose() {
    ticket++;
    timer?.cancel();
    feedbackTimer?.cancel();
    advanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(audio?.dispose());
    super.dispose();
  }

  Future<void> listen() async {
    if (loading) return;
    if (playing) {
      await stop();
      return;
    }
    final current = ++ticket;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      audio = widget.audioFactory?.call() ?? DeviceBirdAudio();
      await audio!.play(widget.recording).timeout(const Duration(seconds: 12));
      if (!mounted || current != ticket) return;
      setState(() {
        loading = false;
        playing = true;
      });
      // A successful start alone is not listening: allow a short audible sample.
      timer = Timer(const Duration(seconds: 2), () {
        if (!mounted || current != ticket) return;
        setState(() => heard = true);
        timer = Timer(
          Duration(
            milliseconds:
                (widget.recording.endMs - widget.recording.startMs - 2000)
                    .clamp(0, 30000),
          ),
          () => unawaited(stop()),
        );
      });
    } catch (_) {
      if (!mounted || current != ticket) return;
      final cleanup = stop();
      if (mounted) {
        setState(
          () => error =
              'Le son ne se charge pas. Réessaie ou mets la balade en pause.',
        );
      }
      await cleanup;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final options = q.data['option_photos'] as List;
    final answered = solved;
    return Scaffold(
      backgroundColor: const Color(0xff145b72),
      appBar: AppBar(
        actions: [
          if (widget.onReport != null)
            IconButton(
              tooltip: 'Signaler cette question',
              icon: const Icon(Icons.feedback_outlined),
              onPressed: widget.busy ? null : widget.onReport,
            ),
          if (widget.onModerate != null)
            IconButton(
              tooltip: 'Écarter cette question',
              icon: const Icon(Icons.flag_outlined),
              onPressed: widget.busy
                  ? null
                  : () {
                      unawaited(stop());
                      widget.onModerate!();
                    },
            ),
        ],
        title: Text('À l’écoute · ${widget.step}/${widget.total}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Mettre la balade en pause',
          onPressed: widget.busy ? null : widget.onPause,
        ),
      ),
      body: GameEffects(
        event: effectTick == 0 ? null : effectTick,
        success: solved,
        readingPaused: readingPaused,
        onKeepReading: solved
            ? () {
                advanceTimer?.cancel();
                setState(() => readingPaused = true);
              }
            : null,
        onContinue: solved && !widget.busy ? widget.onNext : null,
        child: GamePageBody(
          progress: widget.step / widget.total,
          children: [
            Row(
              children: [
                const Pio(size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'À l’écoute',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!answered)
              Text(
                q.prompt,
                style: const TextStyle(
                  fontSize: 20,
                  color: ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 16),
            if (!answered)
              Text(
                widget.level >= 4
                    ? 'Écoute, puis choisis une photo ou « Un autre ».'
                    : 'Touche la note, écoute, puis choisis une photo.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            if (answered) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BirdPhoto(
                  species: options[widget.feedback['answer']]['species_id'],
                  media: Map<String, dynamic>.from(
                    options[widget.feedback['answer']]['photo'],
                  ),
                  height: 250,
                  semanticLabel: q.options[widget.feedback['answer']],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                q.options[widget.feedback['answer']],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                q.explanation,
                style: const TextStyle(fontSize: 18, color: ink),
              ),
              TextButton.icon(
                onPressed: loading ? null : listen,
                icon: Icon(
                  playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                ),
                label: Text(playing ? 'Arrêter le son' : 'Réécouter l’oiseau'),
              ),
            ] else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 20) / 2;
                  final photoHeight = (cardWidth * .70).clamp(100.0, 185.0);
                  final hidden = widget.level >= 4
                      ? q.id.codeUnits
                                .fold<int>(0, (a, b) => a * 31 + b)
                                .abs() %
                            options.length
                      : -1;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Wrap(
                        spacing: 20,
                        runSpacing: 64,
                        children: [
                          for (final i in JourneyOptionOrder.indices(context, options.length))
                            Visibility(
                              visible: true,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(
                                  'audio-card-$i-${wrongCard == i ? effectTick : 0}',
                                ),
                                tween: Tween(begin: 0, end: 1),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 400),
                                builder: (context, t, child) =>
                                    Transform.translate(
                                      offset: Offset(
                                        wrongCard == i
                                            ? math.sin(t * math.pi * 6) *
                                                  9 *
                                                  (1 - t)
                                            : 0,
                                        0,
                                      ),
                                      child: child,
                                    ),
                                child: SizedBox(
                                  width: cardWidth,
                                  child: OutlinedButton(
                                    onPressed:
                                        !heard ||
                                            answered ||
                                            widget.busy ||
                                            submitting ||
                                            wrongCard != null ||
                                            eliminated.contains(i)
                                        ? null
                                        : () => choose(i),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.all(6),
                                      backgroundColor:
                                          wrongCard == i ||
                                              eliminated.contains(i)
                                          ? const Color(0xffffd9d5)
                                          : gameButter,
                                      foregroundColor: ink,
                                      disabledForegroundColor: ink,
                                      side: BorderSide(
                                        color:
                                            answered &&
                                                i == widget.feedback['answer']
                                            ? green
                                            : const Color(0xffbfd8d1),
                                        width:
                                            answered &&
                                                i == widget.feedback['answer']
                                            ? 3
                                            : 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        if (i == hidden && !answered)
                                          Container(
                                            height: photoHeight,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: gameSky,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Text(
                                              '?',
                                              style: TextStyle(
                                                fontSize: 64,
                                                fontWeight: FontWeight.w900,
                                                color: ink,
                                              ),
                                            ),
                                          )
                                        else
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: BirdPhoto(
                                              species: options[i]['species_id'],
                                              media: Map<String, dynamic>.from(
                                                options[i]['photo'],
                                              ),
                                              height: photoHeight,
                                              semanticLabel: q.options[i],
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            i == hidden && !answered
                                                ? 'Un autre'
                                                : q.options[i],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
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
                      Semantics(
                        button: true,
                        label: loading
                            ? 'Annuler le chargement'
                            : playing
                            ? 'Arrêter le son'
                            : 'Écouter l’oiseau',
                        child: Tooltip(
                          message: loading
                              ? 'Annuler le chargement'
                              : playing
                              ? 'Arrêter le son'
                              : 'Écouter l’oiseau',
                          child: SizedBox(
                            width: 82,
                            height: 82,
                            child: FilledButton(
                              onPressed: widget.busy
                                  ? null
                                  : loading
                                  ? () => unawaited(stop())
                                  : listen,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: const Color(0xff16858b),
                                foregroundColor: gameButter,
                                elevation: 5,
                                side: const BorderSide(
                                  color: Color(0xffffedb9),
                                  width: 5,
                                ),
                                shape: const CircleBorder(),
                              ),
                              child: Icon(
                                loading
                                    ? Icons.close
                                    : playing
                                    ? Icons.stop_rounded
                                    : Icons.music_note_rounded,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 14),
            if (widget.feedback != null && !solved)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Pas celui-ci ! Écoute encore et essaie une autre photo.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (!answered)
              Text(
                loading
                    ? 'Le chant arrive…'
                    : playing
                    ? 'Écoute bien…'
                    : heard
                    ? 'Quel oiseau as-tu reconnu ?'
                    : 'Prêt à tendre l’oreille ?',
                textAlign: TextAlign.center,
              ),
            if (error != null) Text(error!, semanticsLabel: error),
            if (widget.saveError != null) Text(widget.saveError!),
            const SizedBox(height: 16),
            if (answered) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.feedback['correct'] == true
                      ? 'Bravo, bien écouté !'
                      : 'Bravo, tu l’as retrouvé !',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (recovered)
                const Text(
                  'Tu as corrigé ton erreur. La première réponse reste comptée pour cette série.',
                ),
            ],
            if (widget.feedback == null)
              NaturalistGuideButton(
                question: q,
                answered: answered,
                pastel: true,
                enabled: !widget.busy,
                beforeHint: widget.beforeHint,
              ),
            if (widget.onRestart != null)
              TextButton.icon(
                onPressed: widget.busy
                    ? null
                    : () {
                        unawaited(stop());
                        widget.onRestart!();
                      },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Recommencer cette série'),
              ),
            ExpansionTile(
              title: const Text('Sources et crédits'),
              children: [
                Text(
                  'Enregistrement : ${widget.recording.author} · ${widget.recording.license}',
                ),
                TextButton(
                  onPressed: () => openSource(context, widget.recording.source),
                  child: const Text('Source Xeno-canto'),
                ),
                TextButton(
                  onPressed: () =>
                      openSource(context, widget.recording.licenseUrl),
                  child: const Text('Licence du son'),
                ),
                for (final option in options)
                  TextButton(
                    onPressed: () =>
                        openSource(context, option['photo']['source']),
                    child: Text(
                      'Photo : ${option['photo']['author']} · ${option['photo']['license']}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
