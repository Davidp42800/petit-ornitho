import '../platform/observation_location.dart';
import 'package:flutter/material.dart';
import 'garden_backdrop.dart';
import 'quest_materials.dart';
import '../data/sightings.dart';

String sightingDate(String value) => value.split('-').reversed.join('.');

class SightingEditor extends StatefulWidget {
  final Sightings sightings;
  final String species;
  final String name;
  final Future<({double latitude, double longitude, double? accuracy})>
  Function()?
  locate;
  const SightingEditor({
    super.key,
    required this.sightings,
    required this.species,
    required this.name,
    this.locate,
  });

  @override
  State<SightingEditor> createState() => _SightingEditorState();
}

class _SightingEditorState extends State<SightingEditor> {
  late final previous = widget.sightings.entry(widget.species);
  late final place = TextEditingController(text: previous?['place'] ?? '');
  late final note = TextEditingController(text: previous?['note'] ?? '');
  late String? date = previous?['date'];
  late final latitude = TextEditingController(
    text: previous?['latitude']?.toString() ?? '',
  );
  late final longitude = TextEditingController(
    text: previous?['longitude']?.toString() ?? '',
  );
  late double? accuracy = (previous?['accuracy'] as num?)?.toDouble();
  bool locating = false;
  String? locationError;
  bool busy = false;
  double? coordinate(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
  Future<void> locate() async {
    if (locating || busy) return;
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      final point = await (widget.locate ?? observationLocation)();
      if (!mounted) return;
      setState(() {
        latitude.text = point.latitude.toStringAsFixed(6);
        longitude.text = point.longitude.toStringAsFixed(6);
        accuracy = point.accuracy;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => locationError = e is StateError
              ? e.message
              : 'Position indisponible. Tu peux saisir les coordonnées.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  String? error;

  @override
  void dispose() {
    place.dispose();
    note.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  Future<void> save({bool remove = false}) async {
    if (busy || locating) return;
    final lat = coordinate(latitude.text), lon = coordinate(longitude.text);
    if (!remove &&
        (latitude.text.trim().isNotEmpty || longitude.text.trim().isNotEmpty) &&
        (lat == null ||
            lon == null ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180)) {
      setState(
        () => error = locationError =
            'Indique une latitude de −90 à 90 et une longitude de −180 à 180, ou efface les deux.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (remove) {
        await widget.sightings.remove(widget.species);
      } else {
        await widget.sightings.put(
          widget.species,
          date: date,
          place: place.text,
          note: note.text,
          latitude: lat,
          longitude: lon,
          accuracy: lat == null ? null : accuracy,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Sauvegarde impossible. Réessaie, tes informations sont encore ici.';
        });
      }
    }
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: date == null ? now : DateTime.parse(date!),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date de l’observation',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
    );
    if (selected != null && mounted) {
      setState(
        () => date =
            '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(previous == null ? 'Nouvelle coche' : 'Modifier ma coche'),
      ),
      body: GardenBackdrop(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FieldPaper(
                padding: EdgeInsets.zero,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Icon(Icons.visibility_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      widget.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Je l’ai vu en vrai ! Garde un souvenir de cette observation. Tous les détails sont facultatifs.',
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: busy ? null : chooseDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        date == null ? 'Ajouter une date' : sightingDate(date!),
                      ),
                    ),
                    if (date != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => date = null),
                        child: const Text('Ne pas préciser la date'),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('sighting-place'),
                      controller: place,
                      enabled: !busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Lieu (facultatif)',
                        hintText: 'Par exemple : jardin, Lausanne',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: gameButter,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Le point de mon observation',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sur place, utilise ta position actuelle. Sinon, note les coordonnées du lieu où tu as vu l’oiseau.',
                          ),
                          OutlinedButton.icon(
                            onPressed: busy || locating ? null : locate,
                            icon: const Icon(Icons.my_location),
                            label: Text(
                              locating
                                  ? 'Recherche de la position…'
                                  : 'Utiliser ma position actuelle',
                            ),
                          ),
                          TextField(
                            key: const ValueKey('sighting-latitude'),
                            controller: latitude,
                            enabled: !busy && !locating,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            onChanged: (_) => setState(() {
                              accuracy = null;
                              locationError = null;
                            }),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              hintText: '46.5197',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('sighting-longitude'),
                            controller: longitude,
                            enabled: !busy && !locating,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            onChanged: (_) => setState(() {
                              accuracy = null;
                              locationError = null;
                            }),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              hintText: '6.6323',
                            ),
                          ),
                          if (accuracy != null)
                            Text('Précision estimée : ±${accuracy!.round()} m'),
                          TextButton(
                            onPressed: busy || locating
                                ? null
                                : () => setState(() {
                                    latitude.clear();
                                    longitude.clear();
                                    accuracy = null;
                                    locationError = null;
                                  }),
                            child: const Text('Effacer le point GPS'),
                          ),
                          if (locationError != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                locationError!,
                                style: const TextStyle(
                                  color: Color(0xffa52b32),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('sighting-note'),
                      controller: note,
                      enabled: !busy,
                      maxLength: 500,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Mon souvenir (facultatif)',
                        hintText: 'Que faisait l’oiseau ?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Conservé sur cet appareil, pour le profil actuel. Pas encore synchronisé entre appareils.',
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy || locating ? null : () => save(),
                      child: Text(
                        busy ? 'Enregistrement…' : 'Enregistrer ma coche',
                      ),
                    ),
                    if (previous != null)
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Retirer cette coche ?'),
                                    content: const Text(
                                      'La date, le lieu et la note de cette coche seront aussi retirés.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Garder'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Retirer'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && mounted) {
                                  await save(remove: true);
                                }
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Retirer ma coche'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
