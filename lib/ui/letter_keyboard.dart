import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Physical letters work across the active puzzle, even after another control
/// takes focus. Dialogs, text editing, and browser shortcuts keep their keys.
class LetterKeyboard extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final bool Function(String letter) onLetter;
  const LetterKeyboard({
    super.key,
    required this.child,
    required this.enabled,
    required this.onLetter,
  });
  @override
  State<LetterKeyboard> createState() => _LetterKeyboardState();
}

class _LetterKeyboardState extends State<LetterKeyboard> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(handleKey);
  }

  bool handleKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (!mounted ||
        !widget.enabled ||
        event is! KeyDownEvent ||
        ModalRoute.of(context)?.isCurrent != true ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return false;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.widget is EditableText ||
        focusContext?.findAncestorStateOfType<EditableTextState>() != null) {
      return false;
    }
    final letter = (event.character ?? event.logicalKey.keyLabel).toUpperCase();
    if (letter.runes.length != 1) return false;
    return widget.onLetter(letter);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(handleKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
