import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../widgets/glass.dart';

const _padding = 10.0;
const _rowHeight = 44.0;
const _gap = 8.0;

/// The tools for formatting a note, which take the keyboard's place while
/// they're open, as on Apple's Notes: the line's style, the text's, then
/// lists, quotes and indents. Each one lights up while the text being
/// written, or picked out, has it.
class FormatPanel extends StatelessWidget {
  const FormatPanel({super.key, required this.controller});

  static const height = _padding * 2 + _rowHeight * 3 + _gap * 2;

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Glass(
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              final selection = controller.selection;
              // The lines' formats as they are: unlike the text's, they're
              // never left waiting for what's written next, where the
              // editor keeps the ones picked with nothing selected.
              final lines = controller.document
                  .collectStyle(
                      selection.start, selection.end - selection.start)
                  .attributes;
              final text = controller.getSelectionStyle().attributes;
              final list = lines[Attribute.list.key];
              return Column(
                children: [
                  _Styles(
                    level: lines[Attribute.header.key]?.value as int?,
                    onChanged: _format,
                  ),
                  const SizedBox(height: _gap),
                  _Group(
                    children: [
                      _toggle(text, Attribute.bold, Icons.format_bold_rounded,
                          "Bold"),
                      _toggle(text, Attribute.italic,
                          Icons.format_italic_rounded, "Italic"),
                      _toggle(text, Attribute.underline,
                          Icons.format_underlined_rounded, "Underline"),
                      _toggle(text, Attribute.strikeThrough,
                          Icons.format_strikethrough_rounded, "Strikethrough"),
                    ],
                  ),
                  const SizedBox(height: _gap),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _Group(
                          children: [
                            _listToggle(list == Attribute.ul, Attribute.ul,
                                Icons.format_list_bulleted_rounded, "Bullets"),
                            _listToggle(list == Attribute.ol, Attribute.ol,
                                Icons.format_list_numbered_rounded, "Numbers"),
                            _listToggle(
                                list == Attribute.checked ||
                                    list == Attribute.unchecked,
                                Attribute.unchecked,
                                Icons.checklist_rounded,
                                "Checklist"),
                          ],
                        ),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(
                        child: _Group(
                          children: [
                            _toggle(lines, Attribute.blockQuote,
                                Icons.format_quote_rounded, "Quote"),
                          ],
                        ),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(
                        flex: 2,
                        child: _Group(
                          children: [
                            _Segment(
                              icon: Icons.format_indent_decrease_rounded,
                              tooltip: "Indent Less",
                              onPressed: lines.containsKey(Attribute.indent.key)
                                  ? () => _indent(false)
                                  : null,
                            ),
                            _Segment(
                              icon: Icons.format_indent_increase_rounded,
                              tooltip: "Indent More",
                              onPressed: () => _indent(true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// A button that gives the text, or its lines, [attribute], or takes it
  /// away again, lit while [attributes] has it.
  Widget _toggle(Map<String, Attribute> attributes, Attribute attribute,
      IconData icon, String tooltip) {
    final on = attributes.containsKey(attribute.key);
    return _Segment(
      icon: icon,
      tooltip: tooltip,
      on: on,
      onPressed: () =>
          _format(on ? Attribute.clone(attribute, null) : attribute),
    );
  }

  /// A button that makes the lines a list of one kind, [list], or plain
  /// lines again once they are.
  Widget _listToggle(bool on, Attribute list, IconData icon, String tooltip) {
    return _Segment(
      icon: icon,
      tooltip: tooltip,
      on: on,
      onPressed: () => _format(on ? Attribute.clone(list, null) : list),
    );
  }

  void _format(Attribute attribute) => controller
      .changeWithoutKeyboard(() => controller.formatSelection(attribute));

  void _indent(bool more) =>
      controller.changeWithoutKeyboard(() => controller.indentSelection(more));
}

extension KeyboardFreeChanges on QuillController {
  /// Makes [change] without the editor calling the keyboard up, which it
  /// does for any change while the keyboard's away: the panel is in its
  /// place, or the note is only being read.
  void changeWithoutKeyboard(VoidCallback change) {
    skipRequestKeyboard = true;
    change();
    skipRequestKeyboard = false;
  }
}

/// The line's style, each shown in a hint of itself: a title, a heading, a
/// subheading, or the body's plain text.
class _Styles extends StatelessWidget {
  const _Styles({required this.level, required this.onChanged});

  /// The line's heading level, or null for body text.
  final int? level;
  final ValueChanged<Attribute> onChanged;

  static final _styles = <(String, Attribute, TextStyle)>[
    (
      "Title",
      Attribute.h1,
      const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
    ),
    (
      "Heading",
      Attribute.h2,
      const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    ),
    (
      "Subheading",
      Attribute.h3,
      const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    ),
    ("Body", Attribute.header, const TextStyle(fontSize: 15)),
  ];

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          for (final (label, heading, style) in _styles)
            Expanded(
              child: _Pressable(
                shape: const StadiumBorder(),
                onPressed: () => onChanged(heading),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    color: heading.value == level
                        ? accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  // Shrinks rather than wrapping when the text is scaled up.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: style.copyWith(
                        color: heading.value == level ? accent : ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Buttons side by side on one tinted, rounded strip, with a hairline
/// between each, like a segmented control's.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return Container(
      height: _rowHeight,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: ink.withValues(alpha: 0.07),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: Row(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              SizedBox(
                height: 22,
                child: VerticalDivider(
                  width: 0.5,
                  thickness: 0.5,
                  color: ink.withValues(alpha: 0.14),
                ),
              ),
            Expanded(child: child),
          ],
        ],
      ),
    );
  }
}

/// A button in a [_Group], tinted with the accent while it's [on].
class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.on = false,
  });

  final IconData icon;
  final String tooltip;

  /// Disables the button when null.
  final VoidCallback? onPressed;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        selected: on,
        child: _Pressable(
          onPressed: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: on ? accent.withValues(alpha: 0.16) : Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedOpacity(
              opacity: onPressed == null ? 0.28 : 1,
              duration: const Duration(milliseconds: 150),
              child: Icon(icon, size: 23, color: on ? accent : ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Highlights rather than ripples when it's pressed, as glass does.
class _Pressable extends StatelessWidget {
  const _Pressable({
    required this.onPressed,
    required this.child,
    this.shape,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        splashFactory: NoSplash.splashFactory,
        highlightColor: context.colors.wB.withValues(alpha: 0.1),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}
