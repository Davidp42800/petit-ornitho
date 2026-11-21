import 'package:flutter/material.dart';
import 'garden_backdrop.dart';

/// Raised game control with a real depressed state.
class QuestButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool gold, wrong;
  final bool dimWhenDisabled;
  final Color? pastelColor;
  const QuestButton({
    super.key,
    required this.child,
    this.onPressed,
    this.gold = false,
    this.wrong = false,
    this.dimWhenDisabled = true,
    this.pastelColor,
  });
  @override
  State<QuestButton> createState() => _QuestButtonState();
}

class _QuestButtonState extends State<QuestButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final gold = widget.gold;
    final top =
        widget.pastelColor ??
        (gold
            ? const Color(0xffffe5a0)
            : widget.wrong
            ? const Color(0xffbd5949)
            : const Color(0xff1b91a7));
    final bottom =
        widget.pastelColor ??
        (gold
            ? const Color(0xffffc64e)
            : widget.wrong
            ? const Color(0xff91473d)
            : const Color(0xff12637d));
    final rim = widget.pastelColor != null
        ? Colors.white
        : gold
        ? const Color(0xffffe6a0)
        : widget.wrong
        ? const Color(0xffdc9874)
        : const Color(0xff7ad8dd);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled || !widget.dimWhenDisabled ? 1 : .48,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 100),
            transform: Matrix4.translationValues(0, pressed ? 4 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: widget.pastelColor != null
                      ? const Color(0xffbdd1d9)
                      : const Color(0xff114963),
                  offset: Offset(0, pressed ? 1 : 5),
                ),
                if (!pressed && widget.pastelColor == null)
                  const BoxShadow(
                    color: Color(0x22183e54),
                    blurRadius: 8,
                    offset: Offset(0, 6),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top, bottom],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: rim, width: 1.5),
                ),
                child: InkWell(
                  onTap: widget.onPressed,
                  onHighlightChanged: (v) {
                    if (mounted) setState(() => pressed = v);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 58),
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x44ffe9b3)),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExpeditionFrame extends StatelessWidget {
  final Widget child;
  const ExpeditionFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xffffe6a3),
          Color(0xff77cdd8),
          Color(0xffdcf6ff),
          Color(0xff308da8),
        ],
        stops: [0, .3, .65, 1],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xff226c87), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0xbb081b12),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xff10291f),
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        ),
        for (final alignment in [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ])
          Positioned(
            top: alignment.y < 0 ? 0 : null,
            bottom: alignment.y > 0 ? 0 : null,
            left: alignment.x < 0 ? 0 : null,
            right: alignment.x > 0 ? 0 : null,
            child: ExcludeSemantics(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xffffedb3), Color(0xff88612d)],
                  ),
                  border: Border.all(color: const Color(0xff6e512b)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x99000000), offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class FieldPaper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const FieldPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xfff5fcff), Color(0xffeaf6f9)],
      ),
      border: Border.all(color: const Color(0xffbee2e8), width: 1.5),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24183e54),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

/// The mystery game's shared setting: garden, blue paper, pale yellow actions.
class GamePageBody extends StatelessWidget {
  final List<Widget> children;
  final double? progress;
  const GamePageBody({super.key, required this.children, this.progress});
  @override
  Widget build(BuildContext context) => GardenBackdrop(
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (progress != null) ...[
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
              ],
              FieldPaper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const gameButter = Color(0xfffff2d4);
const gameSky = Color(0xffd9edf7);
