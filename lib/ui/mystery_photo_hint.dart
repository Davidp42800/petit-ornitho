import 'package:flutter/material.dart';
import 'bird_photo.dart';
import 'pepi_hint_button.dart';
import 'dart:async';

class MysteryPhotoHint extends StatefulWidget {
  final String species;
  final Map<String, dynamic>? photo;
  final bool busy;
  final Future<bool> Function()? beforeHint;
  final VoidCallback onSource;
  const MysteryPhotoHint({
    super.key,
    required this.species,
    required this.photo,
    required this.busy,
    required this.beforeHint,
    required this.onSource,
  });
  @override
  State<MysteryPhotoHint> createState() => _MysteryPhotoHintState();
}

class _MysteryPhotoHintState extends State<MysteryPhotoHint> {
  bool visible = false, loading = false;
  String? error;
  Future<void> reveal() async {
    if (loading || widget.busy || visible || widget.photo == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    var allowed = false;
    try {
      allowed = await widget.beforeHint?.call() ?? false;
    } catch (_) {}
    if (!mounted) return;
    if (!allowed) {
      setState(() { loading = false; error = 'La photo n’a pas pu être débloquée. Réessaie.'; });
      return;
    }
    // Warm the bundled photo before starting the three-second glimpse.
    final asset = bundledBirdAsset(widget.photo?['asset'] as String? ?? 'assets/birds/${widget.species}.jpg');
    try {
      await precacheImage(AssetImage(asset), context);
    } catch (_) {}
    if (!mounted) return;
    setState(() { loading = false; visible = true; });
    Timer? timer;
    await showDialog<void>(context: context, builder: (dialogContext) {
      timer ??= Timer(const Duration(seconds: 3), () {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      });
      return Dialog(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ouvre l’œil !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(18), child: BirdPhoto(
            species: widget.species, media: widget.photo, height: 240,
            semanticLabel: 'Photo de l’oiseau à retrouver',
          )),
          const SizedBox(height: 8),
          const Text('La photo se cache après 3 secondes'),
          if (widget.photo?['author'] != null) Text('${widget.photo!['author']} · ${widget.photo?['license'] ?? ''}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
        ],
      )));
    });
    timer?.cancel();
    if (mounted) setState(() => visible = false);
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    PepiHintButton(
      photo: true,
      label: loading ? 'Un instant…' : 'Découvrir la photo',
      onPressed: widget.busy || loading || visible || widget.photo == null ? null : reveal,
    ),
    if (widget.photo == null) const Text('Photo pas encore disponible', textAlign: TextAlign.center),
    if (error != null) Text(error!),
  ]);
}
