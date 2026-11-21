import 'journey_option_order.dart';
import 'retry_feedback.dart';
import 'package:flutter/material.dart';

/// One tap submits a response. Ignore repeated taps until the request settles.
class FieldChoice extends StatefulWidget {
  final List<String> options;
  final bool locked;
  final ValueChanged<int> onAnswer;
  const FieldChoice({
    super.key,
    required this.options,
    required this.locked,
    required this.onAnswer,
  });
  @override
  State<FieldChoice> createState() => _FieldChoiceState();
}

class _FieldChoiceState extends State<FieldChoice> {
  int? selected;
  bool submitted = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (selected != null && RetryFeedback.isWrong(context, selected!)) submitted = false;
    // Establish the dependency before the first answer, too.
    RetryFeedback.isWrong(context, -1);
  }
  @override
  void didUpdateWidget(covariant FieldChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locked && !widget.locked) submitted = false;
  }
  void choose(int index) {
    if (widget.locked || submitted) return;
    setState(() { selected = index; submitted = true; });
    widget.onAnswer(index);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final i in JourneyOptionOrder.indices(context, widget.options.length))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RetryChoice(index: i, child: Semantics(
              selected: selected == i,
              child: OutlinedButton(
                key: ValueKey('field-option-$i'),
                onPressed: widget.locked || submitted ? null : () => choose(i),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(16),
                  minimumSize: const Size.fromHeight(58),
                  foregroundColor: const Color(0xff294d45),
                  backgroundColor: selected == i
                      ? const Color(0xffd9edc8)
                      : const Color(0xffeef4f3),
                  side: BorderSide(
                    color: selected == i
                        ? const Color(0xff52794d)
                        : const Color(0xffadc7bd),
                    width: selected == i ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected == i ? Icons.flutter_dash : Icons.place_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.options[i],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected == i) const Icon(Icons.check_circle_outline),
                  ],
                ),
              ),
          )),
        ),
    ],
  );
}
