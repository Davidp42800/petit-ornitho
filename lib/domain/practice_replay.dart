/// Preserve the selected challenges, while choosing a fresh opening when possible.
void varyReplayOpening<T>(
  List<T> items,
  String Function(T) species,
  String previousFirst,
  String previousLast,
) {
  final fresh = items.indexWhere(
    (item) => species(item) != previousFirst && species(item) != previousLast,
  );
  final next = fresh >= 0
      ? fresh
      : items.indexWhere((item) => species(item) != previousLast);
  if (next > 0) items.insert(0, items.removeAt(next));
}
