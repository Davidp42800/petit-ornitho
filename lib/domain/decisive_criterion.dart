/// Two distinct answers, kept together for atomic persistence by the store.
/// This model grants no reward and is not a substitute for server validation.
class DecisiveCriterion {
  final String questionId;
  final int version;
  final List<int> identificationChoices;
  final List<int> justificationChoices;
  final bool assisted;

  DecisiveCriterion._(
    this.questionId,
    this.version,
    List<int> identification,
    List<int> justification,
    this.assisted,
  ) : identificationChoices = List.unmodifiable(identification),
      justificationChoices = List.unmodifiable(justification);

  factory DecisiveCriterion.start(Map<String, dynamic> question) {
    _validateQuestion(question);
    return DecisiveCriterion._(
      question['id'],
      question['version'] ?? 1,
      [],
      [],
      false,
    );
  }

  factory DecisiveCriterion.restore(
    Map<String, dynamic> question,
    Map<String, dynamic> saved,
  ) {
    var result = DecisiveCriterion.start(question);
    if (saved['protocol'] != 1 ||
        saved['question_id'] != result.questionId ||
        saved['version'] != result.version ||
        saved['assisted'] is! bool) {
      throw const FormatException('Défi sauvegardé incompatible.');
    }
    for (final phase in CriterionPhase.values) {
      final choices = saved[phase.name];
      if (choices is! List || choices.any((x) => x is! int)) {
        throw const FormatException('Réponses sauvegardées invalides.');
      }
      for (final choice in choices) {
        // Saved history is canonical: no duplicates or choices after success.
        if (result.phase(question) != phase ||
            result.choices(phase).contains(choice)) {
          throw const FormatException('Ordre des réponses invalide.');
        }
        result = result.choose(question, phase, choice);
      }
    }
    return saved['assisted'] == true ? result.withAssistance() : result;
  }

  static void _validateQuestion(Map<String, dynamic> q) {
    if (q['format'] != 'decisive_criterion' ||
        q['id'] is! String ||
        (q['id'] as String).isEmpty ||
        (q['version'] != null && (q['version'] is! int || q['version'] < 1)) ||
        q['justification'] is! Map) {
      throw const FormatException('Défi comparatif invalide.');
    }
    for (final part in [q, q['justification'] as Map]) {
      final options = part['options'];
      final answer = part['answer'];
      final minimum = identical(part, q) ? 2 : 3;
      if (options is! List ||
          options.length < minimum ||
          options.length > 4 ||
          options.any((x) => x is! String || x.trim().isEmpty) ||
          options
                  .map((x) => x.toString().trim().toLowerCase())
                  .toSet()
                  .length !=
              options.length ||
          answer is! int ||
          answer < 0 ||
          answer >= options.length) {
        throw const FormatException('Choix du défi invalides.');
      }
    }
  }

  void _checkQuestion(Map<String, dynamic> q) {
    _validateQuestion(q);
    if (q['id'] != questionId || (q['version'] ?? 1) != version) {
      throw StateError('La réponse appartient à un autre défi.');
    }
  }

  List<int> choices(CriterionPhase phase) =>
      phase == CriterionPhase.identification
      ? identificationChoices
      : justificationChoices;

  CriterionPhase? phase(Map<String, dynamic> question) {
    _checkQuestion(question);
    if (!identificationChoices.contains(question['answer'])) {
      return CriterionPhase.identification;
    }
    if (!justificationChoices.contains(question['justification']['answer'])) {
      return CriterionPhase.justification;
    }
    return null;
  }

  DecisiveCriterion choose(
    Map<String, dynamic> question,
    CriterionPhase expectedPhase,
    int choice,
  ) {
    _checkQuestion(question);
    final part = expectedPhase == CriterionPhase.identification
        ? question
        : question['justification'] as Map;
    if (choice < 0 || choice >= (part['options'] as List).length) {
      throw ArgumentError('Choix invalide.');
    }
    // Retried requests never become an answer to the following step.
    if (choices(expectedPhase).contains(choice)) return this;
    if (phase(question) != expectedPhase) {
      throw StateError('Cette étape ne peut pas recevoir de réponse.');
    }
    return DecisiveCriterion._(
      questionId,
      version,
      [
        ...identificationChoices,
        if (expectedPhase == CriterionPhase.identification) choice,
      ],
      [
        ...justificationChoices,
        if (expectedPhase == CriterionPhase.justification) choice,
      ],
      assisted,
    );
  }

  DecisiveCriterion withAssistance() => assisted
      ? this
      : DecisiveCriterion._(
          questionId,
          version,
          identificationChoices,
          justificationChoices,
          true,
        );

  bool firstTryCorrect(Map<String, dynamic> question, CriterionPhase step) {
    _checkQuestion(question);
    final answer = step == CriterionPhase.identification
        ? question['answer']
        : question['justification']['answer'];
    return choices(step).isNotEmpty && choices(step).first == answer;
  }

  bool autonomousSuccess(Map<String, dynamic> question) =>
      phase(question) == null &&
      !assisted &&
      CriterionPhase.values.every((step) => firstTryCorrect(question, step));

  Map<String, dynamic> toJson() => {
    'protocol': 1,
    'question_id': questionId,
    'version': version,
    'identification': identificationChoices.toList(),
    'justification': justificationChoices.toList(),
    'assisted': assisted,
  };
}

enum CriterionPhase { identification, justification }
