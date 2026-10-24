import 'dart:async';
import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
// Only for the editor's cursor: flutter_quill takes the theme of its own
// Material library.
import 'package:flutter/material.dart' as legacy show TextSelectionThemeData;
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../core/utils/note_document_utils.dart';
import '../../../../../models/note.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/glass_icon_button.dart';
import '../../../../widgets/glass_menu.dart';
import '../../../../widgets/large_title.dart';
import '../../../../widgets/rise_in.dart';
import '../../../profile/profile_page/widgets/aurora.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/note_banner.dart';
import '../widgets/note_styles.dart';

const _accent = Color(0xff3D5AFE);

/// How far below the bar the banner starts.
const _bannerTop = 8.0;

/// The toolbar's gap above the bottom of the page, or the keyboard.
const _toolbarGap = 12.0;

/// iOS's system red, a touch brighter on dark pages, as there.
Color _systemRed(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30);

/// Where a note is read and written: its cover across the top, lit by an
/// aurora in its own colours, over its text, with the tools for writing in
/// a glass toolbar that rides above the keyboard.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.note});

  final Note note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _scrollController = ScrollController();
  late final _controller = QuillController(
    document: NoteDocumentUtils.toDocument(widget.note),
    selection: const TextSelection.collapsed(offset: 0),
    config: const QuillControllerConfig(
      // Text from elsewhere comes in plain, in the note's own style: a web
      // page's colours and fonts would clash with it, or vanish on a dark
      // page, and its pictures are more than the editor can show.
      // ignore: experimental_member_use
      clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: false),
    ),
  );
  final _bodyFocusNode = FocusNode();
  late final StreamSubscription<DocChange> _changes;

  /// The text as it was last saved, which tells whether there are changes
  /// to save.
  late Delta _savedDelta;

  /// The note as it was last saved, whose text the home screen's widget
  /// shows.
  late Note _saved = widget.note;

  /// Whether there are changes since the note was last saved, which the
  /// toolbar's save button shows.
  final _unsaved = ValueNotifier(false);

  /// Whether the text is in a language written from right to left, such as
  /// Arabic, which lines it up on the right.
  late bool _rtl = _isRtl(widget.note.body);

  /// Whether the formatting panel is open, in the keyboard's place.
  bool _formatting = false;

  /// How far the keyboard was up at the last build, which tells it coming up
  /// from going down.
  double _keyboard = 0;

  /// Whether the note has been deleted, so its cover doesn't fly back to a
  /// card that's going away.
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    // Before any change, rather than when it's first compared with one.
    _savedDelta = _controller.document.toDelta();
    _changes = _controller.changes.listen((_) => _changed());
    _bodyFocusNode.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // The keyboard coming back up, for writing, puts the formatting away.
    if (keyboard > _keyboard) _formatting = false;
    _keyboard = keyboard;
  }

  @override
  void dispose() {
    _changes.cancel();
    _scrollController.dispose();
    _controller.dispose();
    _bodyFocusNode.dispose();
    _unsaved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    // Clear of a camera cutout on a phone turned on its side, and lines a
    // comfortable length on large screens.
    final gutterLeft = math.max(16 + padding.left, (width - 720) / 2);
    final gutterRight = math.max(16 + padding.right, (width - 720) / 2);
    // How far up the page the toolbar, and the formatting panel over it
    // while it's open, cover the text.
    final toolbarCover = EditorToolbar.height +
        (_formatting ? EditorToolbar.panelHeight : 0) +
        _toolbarGap +
        padding.bottom;
    final (autoSave, showCount, casualFont, textSize, titleSize) = context
        .select<UserViewModel, (bool, bool, bool, double, double)>((user) => (
              user.user.autoSave == 1,
              user.user.count == 1,
              user.user.casual == 1,
              user.user.notesTextSize,
              user.user.notesTitleSize,
            ));
    final note = widget.note;
    final bodyStyle =
        noteBodyStyle(context, size: textSize, casualFont: casualFont);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // There's no app bar to pick the status bar's icons, so they're set here.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.colors.pageBackground,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: padding.top + 400,
              // Drifts up at half the speed of the page, for a little depth.
              child: ListenableBuilder(
                listenable: _scrollController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                      0,
                      _scrollController.hasClients
                          ? -_scrollController.offset / 2
                          : 0),
                  child: child,
                ),
                child:
                    ProfileAurora(colors: _glowsFor(note.coverColor.toColor)),
              ),
            ),
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: LargeTitleBarDelegate(
                    title: note.title,
                    topInset: padding.top,
                    controller: _scrollController,
                    leading: Padding(
                      padding: EdgeInsets.only(left: padding.left),
                      child: GlassIconButton(
                        icon: Icons.chevron_left_rounded,
                        iconSize: 28,
                        tooltip: "Back",
                        // Straight back, even with the formatting open.
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    trailing: Padding(
                      padding: EdgeInsets.only(right: padding.right),
                      child: GlassMenu(items: _menuItems(isDarkTheme)),
                    ),
                    titleRevealOffset:
                        _bannerTop + NoteBanner.titleScrolledAway(titleSize),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      gutterLeft, _bannerTop, gutterRight, 0),
                  sliver: SliverToBoxAdapter(
                    child: HeroMode(
                      enabled: !_deleted,
                      child: NoteBanner(note: note, titleSize: titleSize),
                    ),
                  ),
                ),
                SliverPadding(
                  // In line with the banner's text rather than its edge.
                  padding: EdgeInsets.fromLTRB(
                      gutterLeft + 6, 22, gutterRight + 6, 0),
                  sliver: SliverToBoxAdapter(
                    // Once the page has mostly covered the notes behind it.
                    child: RiseIn(
                      delay: RiseIn.stagger * 2,
                      child: Directionality(
                        textDirection:
                            _rtl ? TextDirection.rtl : TextDirection.ltr,
                        child: QuillEditor(
                          controller: _controller,
                          focusNode: _bodyFocusNode,
                          // The page's own, as the text scrolls with it.
                          scrollController: _scrollController,
                          config: QuillEditorConfig(
                            scrollable: false,
                            // A new note is ready to be written in.
                            autoFocus: note.body.isEmpty,
                            placeholder: "Start writing…",
                            customStyles: noteStyles(context, bodyStyle),
                            textSpanBuilder: checkedLinesSpanBuilder(bodyStyle),
                            textSelectionThemeData:
                                const legacy.TextSelectionThemeData(
                                    cursorColor: _accent),
                            // Keeps the line being written clear of the
                            // toolbar.
                            scrollBottomInset: toolbarCover + 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The rest of the page, which carries on writing at the end
                // of the text when it's tapped.
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _controller.moveCursorToEnd,
                    // The last line scrolls clear of the toolbar.
                    child: SizedBox(height: toolbarCover + 24),
                  ),
                ),
              ],
            ),
            Positioned(
              left: gutterLeft,
              right: gutterRight,
              bottom: padding.bottom + _toolbarGap,
              child: RiseIn(
                delay: RiseIn.stagger * 3,
                // Back puts the formatting panel away first, as it would
                // the keyboard.
                child: PopScope(
                  canPop: !_formatting,
                  onPopInvokedWithResult: (didPop, result) {
                    if (!didPop) setState(() => _formatting = false);
                  },
                  child: EditorToolbar(
                    controller: _controller,
                    focusNode: _bodyFocusNode,
                    unsaved: _unsaved,
                    formatting: _formatting,
                    onFormat: _toggleFormatting,
                    showCount: showCount,
                    autoSave: autoSave,
                    onSave: _saveChanges,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<GlassMenuItem> _menuItems(bool isDarkTheme) => [
        GlassMenuItem(
          icon: Icons.add_to_home_screen_rounded,
          tooltip: "Show on Widget",
          onPressed: _showOnWidget,
        ),
        GlassMenuItem(
          icon: Icons.delete_rounded,
          tooltip: "Delete Note",
          color: _systemRed(isDarkTheme),
          onPressed: _delete,
        ),
      ];

  void _changed() {
    final rtl = _isRtl(_controller.document.toPlainText());
    if (rtl != _rtl) setState(() => _rtl = rtl);
    _unsaved.value = _controller.document.toDelta() != _savedDelta;
    if (_unsaved.value && context.read<UserViewModel>().user.autoSave == 1) {
      _save();
    }
  }

  void _focusChanged() {
    if (!_bodyFocusNode.hasFocus && _formatting) {
      setState(() => _formatting = false);
    }
  }

  /// Opens the formatting panel in the keyboard's place, or puts it away
  /// and brings the keyboard back to carry on writing.
  void _toggleFormatting() {
    setState(() => _formatting = !_formatting);
    SystemChannels.textInput
        .invokeMethod<void>(_formatting ? 'TextInput.hide' : 'TextInput.show');
  }

  /// Saves the note's text, as it is now.
  Future<void> _save() async {
    final delta = _controller.document.toDelta();
    try {
      _saved = await Provider.of<NotesViewModel>(context, listen: false)
          .updateText(widget.note, _controller.document);
    } catch (e) {
      FeedbackToast.error("Sorry, Something went wrong, note not saved");
      return;
    }
    _savedDelta = delta;
    // Still unsaved if it was written in while it saved.
    if (mounted) _unsaved.value = _controller.document.toDelta() != delta;
  }

  Future<void> _saveChanges() async {
    HapticFeedback.lightImpact();
    await _save();
  }

  /// Shows the note's saved text on the home screen's widget.
  Future<void> _showOnWidget() async {
    final result = await Provider.of<NotesViewModel>(context, listen: false)
        .showOnWidget(_saved);
    result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );
  }

  Future<void> _delete() async {
    final result = await Provider.of<NotesViewModel>(context, listen: false)
        .deleteNote(widget.note);
    if (!mounted) return;
    switch (result) {
      case Failure(:final message):
        FeedbackToast.error(message);
      case Success(:final message) || Info(:final message):
        setState(() => _deleted = true);
        Navigator.pop(context);
        FeedbackToast.info(message);
    }
  }
}

bool _isRtl(String text) => intl.Bidi.detectRtlDirectionality(text);

/// The aurora's colours for a note's [cover]: the cover's own, beside two of
/// its neighbours on the colour wheel, or the app's blues behind a white,
/// grey or black one.
(Color, Color, Color) _glowsFor(Color cover) {
  final hsv = HSVColor.fromColor(cover);
  if (hsv.saturation < 0.25 || hsv.value < 0.25) return ProfileAurora.appColors;
  Color turned(double degrees) =>
      hsv.withHue((hsv.hue + degrees) % 360).toColor();
  return (cover, turned(-28), turned(32));
}
