import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/glass.dart';

const _accent = Color(0xff3D5AFE);
const _highlight = Color(0xff40C4FF);

final _word = RegExp(r'\S+');
final _thousands = intl.NumberFormat.decimalPattern();

/// The bar along the bottom of the editor, which rides above the keyboard
/// while it's open: buttons that undo and redo, a count of the note's words
/// if the user wants one, and, when changes are saved by hand, the button
/// that saves them.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.text,
    required this.history,
    required this.savedText,
    required this.showCount,
    required this.autoSave,
    required this.onSave,
  });

  static const height = 50.0;

  /// The note's text, as it's being written.
  final TextEditingController text;
  final UndoHistoryController history;

  /// The text as it was last saved.
  final ValueListenable<String> savedText;
  final bool showCount;

  /// Whether changes are saved as they're made, which leaves nothing for a
  /// button to do.
  final bool autoSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _Capsule(text: text, history: history, showCount: showCount),
          ),
        ),
        if (!autoSave) ...[
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: Listenable.merge([text, savedText]),
            builder: (context, child) => _SaveButton(
              saved: text.text == savedText.value,
              onPressed: onSave,
            ),
          ),
        ],
      ],
    );
  }
}

/// Undo and redo, then the count, on one glass capsule. It's only there
/// while it has something to offer, so a note that's only being read is
/// left clear of it.
class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.text,
    required this.history,
    required this.showCount,
  });

  final TextEditingController text;
  final UndoHistoryController history;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: history,
      builder: (context, value, child) {
        final shown = showCount || value.canUndo || value.canRedo;
        return IgnorePointer(
          ignoring: !shown,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedScale(
              scale: shown ? 1 : 0.9,
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                height: EditorToolbar.height,
                child: Glass(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToolbarButton(
                          icon: Icons.undo_rounded,
                          tooltip: "Undo",
                          onPressed: value.canUndo ? history.undo : null,
                        ),
                        _ToolbarButton(
                          icon: Icons.redo_rounded,
                          tooltip: "Redo",
                          onPressed: value.canRedo ? history.redo : null,
                        ),
                        if (showCount) ...[
                          SizedBox(
                            height: 22,
                            child: VerticalDivider(
                              width: 9,
                              thickness: 0.5,
                              color: context.colors.wB.withValues(alpha: 0.2),
                            ),
                          ),
                          Flexible(child: _Count(text: text)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;

  /// Disables the button when null.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 46,
        height: EditorToolbar.height,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            // Glass highlights a pressed button instead of rippling.
            splashFactory: NoSplash.splashFactory,
            highlightColor: ink.withValues(alpha: 0.1),
            child: AnimatedOpacity(
              opacity: onPressed == null ? 0.28 : 1,
              duration: const Duration(milliseconds: 150),
              child: Icon(icon, size: 24, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many words the note has, as it's written, or how many characters
/// after a tap, then words again after another.
class _Count extends StatefulWidget {
  const _Count({required this.text});

  final TextEditingController text;

  @override
  State<_Count> createState() => _CountState();
}

class _CountState extends State<_Count> {
  bool _characters = false;

  // The last count, which the cursor moving about doesn't change.
  String? _countedText;
  bool? _countedCharacters;
  int _count = 0;

  int _countOf(String text) {
    if (!identical(text, _countedText) || _characters != _countedCharacters) {
      _countedText = text;
      _countedCharacters = _characters;
      _count = _characters
          // Leaving out spaces and line breaks, and counting an emoji as one.
          ? text.characters.where((c) => c.trim().isNotEmpty).length
          : _word.allMatches(text).length;
    }
    return _count;
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => setState(() => _characters = !_characters),
        customBorder: const StadiumBorder(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: ink.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          child: Center(
            widthFactor: 1,
            child: ListenableBuilder(
              listenable: widget.text,
              builder: (context, child) {
                final count = _countOf(widget.text.text);
                final noun = _characters ? "character" : "word";
                return Text(
                  "${_thousands.format(count)} "
                  "${count == 1 ? noun : "${noun}s"}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.6),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The button that saves the changes, glowing in the app's blues while
/// there are some, which settles into a quiet note once they're saved.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onPressed});

  final bool saved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: saved
          ? const _SavedLabel()
          : _GlowingSaveButton(onPressed: onPressed),
    );
  }
}

/// Filled with the add button's gradient, and lifted off the page by a soft
/// shadow of its own colour.
class _GlowingSaveButton extends StatefulWidget {
  const _GlowingSaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_GlowingSaveButton> createState() => _GlowingSaveButtonState();
}

class _GlowingSaveButtonState extends State<_GlowingSaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_accent, Color.lerp(_accent, _highlight, 0.7)!],
          ),
          shadows: [
            BoxShadow(
              color: _accent.withValues(alpha: isDarkTheme ? 0.22 : 0.25),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            customBorder: const StadiumBorder(),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.white.withValues(alpha: 0.12),
            child: const SizedBox(
              height: EditorToolbar.height,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 22, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says the note is saved, on the same glass as the toolbar.
class _SavedLabel extends StatelessWidget {
  const _SavedLabel();

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.wB.withValues(alpha: 0.5);
    return SizedBox(
      height: EditorToolbar.height,
      child: Glass(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 20, color: muted),
              const SizedBox(width: 6),
              Text(
                "Saved",
                style: TextStyle(
                  color: muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
