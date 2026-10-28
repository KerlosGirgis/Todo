import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/utils/note_document_utils.dart';
import '../../../../widgets/glass.dart';
import 'note_formatting.dart';

const _padding = 10.0;
const _rowHeight = 44.0;
const _gap = 8.0;

/// How far the styles fade out at the edge they scroll on from.
const _fade = 14.0;

/// The tools for formatting a note, which take the keyboard's place while
/// they're open, as on Apple's Notes, with all of Markdown's and underlining
/// too: the line's style; the text's, its code and its link; lists, quotes,
/// code blocks and indents; then highlighting, raising and lowering, rules
/// across the note, and clearing the text's formatting. Each one lights up
/// while the text being written, or picked out, has it.
class FormatPanel extends StatelessWidget {
  const FormatPanel({
    super.key,
    required this.controller,
    required this.onLink,
  });

  static const height = _padding * 2 + _rowHeight * 4 + _gap * 3;

  final QuillController controller;

  /// Opens the link the cursor's on to be changed, or links the text.
  final VoidCallback onLink;

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
              // editor keeps the ones picked with nothing selected, nor
              // taken partly from the line before, as the editor takes them
              // at the start of a line.
              final lines = selection.isCollapsed
                  ? (controller.document.queryChild(selection.start).node
                              as Line?)
                          ?.style
                          .attributes ??
                      const <String, Attribute>{}
                  : controller.document
                      .collectStyle(
                          selection.start, selection.end - selection.start)
                      .attributes;
              final text = controller.getSelectionStyle().attributes;
              final list = lines[Attribute.list.key];
              final script = text[Attribute.script.key];
              return Column(
                children: [
                  _Styles(
                    level: lines[Attribute.header.key]?.value as int?,
                    code: lines.containsKey(Attribute.codeBlock.key),
                    onChanged: _format,
                  ),
                  const SizedBox(height: _gap),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _Group(
                          children: [
                            _toggle(text, Attribute.bold,
                                Icons.format_bold_rounded, "Bold"),
                            _toggle(text, Attribute.italic,
                                Icons.format_italic_rounded, "Italic"),
                            _toggle(text, Attribute.underline,
                                Icons.format_underlined_rounded, "Underline"),
                            _toggle(
                                text,
                                Attribute.strikeThrough,
                                Icons.format_strikethrough_rounded,
                                "Strikethrough"),
                            _toggle(text, Attribute.inlineCode,
                                Icons.code_rounded, "Code"),
                          ],
                        ),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(
                        child: _Group(
                          children: [
                            _Segment(
                              icon: Icons.link_rounded,
                              tooltip: text.containsKey(Attribute.link.key)
                                  ? "Edit Link"
                                  : "Add Link",
                              on: text.containsKey(Attribute.link.key),
                              onPressed: onLink,
                            ),
                          ],
                        ),
                      ),
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
                        flex: 2,
                        child: _Group(
                          children: [
                            _toggle(lines, Attribute.blockQuote,
                                Icons.format_quote_rounded, "Quote"),
                            _toggle(lines, Attribute.codeBlock,
                                Icons.data_object_rounded, "Code Block"),
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
                  const SizedBox(height: _gap),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _Group(
                          children: [
                            _toggle(text, NoteDocumentUtils.highlight,
                                Icons.border_color_rounded, "Highlight"),
                            _scriptToggle(script, Attribute.superscript,
                                Icons.superscript_rounded, "Superscript"),
                            _scriptToggle(script, Attribute.subscript,
                                Icons.subscript_rounded, "Subscript"),
                          ],
                        ),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(
                        flex: 2,
                        child: _Group(
                          children: [
                            _Segment(
                              icon: Icons.horizontal_rule_rounded,
                              tooltip: "Divider",
                              onPressed: () => controller.changeWithoutKeyboard(
                                  controller.insertDivider),
                            ),
                            _Segment(
                              icon: Icons.format_clear_rounded,
                              tooltip: "Clear Formatting",
                              onPressed: controller.textFormats.isEmpty
                                  ? null
                                  : () => controller.changeWithoutKeyboard(
                                      controller.clearTextFormats),
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

  /// A button that raises the text above the line, or drops it below, as
  /// [script] says, or sets it back on the line once it is. It can't be
  /// both.
  Widget _scriptToggle(
      Attribute? current, Attribute script, IconData icon, String tooltip) {
    final on = current == script;
    return _Segment(
      icon: icon,
      tooltip: tooltip,
      on: on,
      onPressed: () =>
          _format(on ? Attribute.clone(Attribute.script, null) : script),
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
/// subheading and the smaller headings after them, which scroll into view,
/// or, at the end, the body's plain text. The line's own scrolls into view
/// when it's one of the smaller ones.
class _Styles extends StatefulWidget {
  const _Styles({
    required this.level,
    required this.code,
    required this.onChanged,
  });

  /// The line's heading level, or null for body text.
  final int? level;

  /// Whether the line is code, which is in no style of these.
  final bool code;
  final ValueChanged<Attribute> onChanged;

  @override
  State<_Styles> createState() => _StylesState();
}

class _StylesState extends State<_Styles> {
  static const _headings = <(String, Attribute, TextStyle)>[
    (
      "Title",
      Attribute.h1,
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
    ),
    (
      "Heading",
      Attribute.h2,
      TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    ),
    (
      "Subheading",
      Attribute.h3,
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    ),
    (
      "Heading 4",
      Attribute.h4,
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.1),
    ),
    (
      "Heading 5",
      Attribute.h5,
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    (
      "Heading 6",
      Attribute.h6,
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
    ),
  ];

  final _scrollController = ScrollController();

  /// One for each heading, to bring the line's into view.
  final _keys = [for (final _ in _headings) GlobalKey()];

  /// Whether there are more styles off each edge, which fades out there.
  bool _moreBefore = false;
  bool _moreAfter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(Duration.zero));
  }

  @override
  void didUpdateWidget(_Styles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.level != oldWidget.level) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _reveal(const Duration(milliseconds: 250)));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the line's heading into view, if it's out of it, as far as it
  /// takes.
  void _reveal(Duration duration) {
    final level = widget.level;
    if (!mounted || level == null || level > _keys.length) return;
    final heading = _keys[level - 1].currentContext;
    if (heading == null) return;
    // Only one of them moves it, if either does.
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(heading,
          alignmentPolicy: policy,
          duration: duration,
          curve: Curves.easeOutCubic);
    }
  }

  /// Gives the line [style], a heading's or the body's, which takes it out
  /// of a block of code too, as code is in a style of its own. Only what
  /// changes is changed: the editor would take a change that changes nothing
  /// as the start of one to undo along with the change before it.
  void _choose(Attribute style) {
    if (style.value != widget.level) widget.onChanged(style);
    if (widget.code && style.value == null) {
      widget.onChanged(Attribute.clone(Attribute.codeBlock, null));
    }
  }

  bool _scrolled(ScrollMetrics metrics) {
    final before = metrics.extentBefore > 0.5;
    final after = metrics.extentAfter > 0.5;
    if (before != _moreBefore || after != _moreAfter) {
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          Expanded(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) => _scrolled(notification.metrics),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) =>
                    _scrolled(notification.metrics),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) {
                    final fade =
                        bounds.width > _fade * 2 ? _fade / bounds.width : 0.0;
                    return LinearGradient(
                      colors: [
                        if (_moreBefore) Colors.transparent else Colors.white,
                        Colors.white,
                        Colors.white,
                        if (_moreAfter) Colors.transparent else Colors.white,
                      ],
                      stops: [0, fade, 1 - fade, 1],
                    ).createShader(bounds);
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (index, (label, heading, style))
                            in _headings.indexed)
                          _Style(
                            key: _keys[index],
                            label: label,
                            style: style,
                            on: heading.value == widget.level,
                            onPressed: () => _choose(heading),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 22,
            child: VerticalDivider(
              width: 9,
              thickness: 0.5,
              color: ink.withValues(alpha: 0.14),
            ),
          ),
          _Style(
            label: "Body",
            style: const TextStyle(fontSize: 15),
            on: widget.level == null && !widget.code,
            onPressed: () => _choose(Attribute.header),
          ),
        ],
      ),
    );
  }
}

/// One of the line's styles, named in a hint of itself, and tinted with the
/// accent while it's the line's.
class _Style extends StatelessWidget {
  const _Style({
    super.key,
    required this.label,
    required this.style,
    required this.on,
    required this.onPressed,
  });

  final String label;
  final TextStyle style;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.wB;
    final accent = context.colors.moreLess;
    return Semantics(
      selected: on,
      button: true,
      child: _Pressable(
        shape: const StadiumBorder(),
        expand: false,
        onPressed: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _rowHeight,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: on ? accent.withValues(alpha: 0.16) : Colors.transparent,
          ),
          alignment: Alignment.center,
          // As wide as the fade, so a style brought into view at the edge
          // is clear of it.
          padding: const EdgeInsets.symmetric(horizontal: _fade),
          // Shrinks rather than outgrowing the row when the text is scaled
          // up.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: style.copyWith(color: on ? accent : ink),
            ),
          ),
        ),
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

/// Highlights rather than ripples when it's pressed, as glass does. It fills
/// the room it's given, unless it's not to [expand].
class _Pressable extends StatelessWidget {
  const _Pressable({
    required this.onPressed,
    required this.child,
    this.shape,
    this.expand = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ShapeBorder? shape;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        splashFactory: NoSplash.splashFactory,
        highlightColor: context.colors.wB.withValues(alpha: 0.1),
        child: expand ? SizedBox.expand(child: child) : child,
      ),
    );
  }
}
