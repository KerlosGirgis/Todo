import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
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

const _accent = Color(0xff3D5AFE);

/// How far below the bar the banner starts.
const _bannerTop = 8.0;

/// The toolbar's gap above the bottom of the page, or the keyboard.
const _toolbarGap = 12.0;

/// iOS's system red, a touch brighter on dark pages, as there.
Color _systemRed(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30);

/// A note's text as the editor draws it, at the user's text [size] and in
/// the casual font if they've chosen it.
TextStyle noteBodyStyle(BuildContext context,
        {required double size, required bool casualFont}) =>
    TextStyle(
      fontFamily: casualFont ? 'casual' : 'arial',
      fontWeight: casualFont ? FontWeight.w600 : FontWeight.w400,
      color: context.colors.wB,
      fontSize: 26 * size,
      height: 1.4,
    );

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
  late final _bodyController = TextEditingController(text: widget.note.body);
  final _undoHistoryController = UndoHistoryController();
  final _bodyFocusNode = FocusNode();

  /// The text as it was last saved, which tells the toolbar whether there
  /// are changes to save.
  late final _savedBody = ValueNotifier(widget.note.body);

  /// Whether the text is in a language written from right to left, such as
  /// Arabic, which lines it up on the right.
  late bool _rtl = _isRtl(widget.note.body);

  /// Whether the note has been deleted, so its cover doesn't fly back to a
  /// card that's going away.
  bool _deleted = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _bodyController.dispose();
    _undoHistoryController.dispose();
    _bodyFocusNode.dispose();
    _savedBody.dispose();
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
    // The last line scrolls clear of the toolbar.
    final toolbarClearance =
        EditorToolbar.height + _toolbarGap + padding.bottom + 24;
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
                        onPressed: () => Navigator.maybePop(context),
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
                      child: TextField(
                        controller: _bodyController,
                        focusNode: _bodyFocusNode,
                        undoController: _undoHistoryController,
                        // A new note is ready to be written in.
                        autofocus: note.body.isEmpty,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        textDirection:
                            _rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: bodyStyle,
                        cursorColor: _accent,
                        // Keeps the line being written clear of the toolbar.
                        scrollPadding: EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            EditorToolbar.height +
                                _toolbarGap +
                                padding.bottom +
                                20),
                        decoration: InputDecoration.collapsed(
                          hintText: "Start writing…",
                          hintStyle: bodyStyle.copyWith(
                              color: context.colors.wB.withValues(alpha: 0.3)),
                        ),
                        onChanged: (text) => _changed(text, autoSave: autoSave),
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
                    onTap: _writeAtEnd,
                    child: SizedBox(height: toolbarClearance),
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
                child: EditorToolbar(
                  text: _bodyController,
                  history: _undoHistoryController,
                  savedText: _savedBody,
                  showCount: showCount,
                  autoSave: autoSave,
                  onSave: _saveChanges,
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

  void _changed(String text, {required bool autoSave}) {
    final rtl = _isRtl(text);
    if (rtl != _rtl) setState(() => _rtl = rtl);
    if (autoSave) _save(text);
  }

  /// Saves [body] as the note's text.
  Future<void> _save(String body) async {
    final note = widget.note;
    try {
      await Provider.of<NotesViewModel>(context, listen: false).updateNote(
        Note(
          id: note.id,
          title: note.title,
          body: body,
          titleColor: note.titleColor,
          coverColor: note.coverColor,
          protected: note.protected,
        ),
      );
    } catch (e) {
      FeedbackToast.error("Sorry, Something went wrong, note not saved");
      return;
    }
    if (mounted) _savedBody.value = body;
  }

  Future<void> _saveChanges() async {
    HapticFeedback.lightImpact();
    await _save(_bodyController.text);
  }

  /// Puts the cursor at the end of the text, and the keyboard up.
  void _writeAtEnd() {
    _bodyController.selection =
        TextSelection.collapsed(offset: _bodyController.text.length);
    if (_bodyFocusNode.hasFocus) {
      // Still focused after the keyboard was put away, so it's brought back.
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _bodyFocusNode.requestFocus();
    }
  }

  /// Shows the note's saved text on the home screen's widget.
  void _showOnWidget() {
    final body = _savedBody.value;
    if (body.trim().isEmpty) {
      FeedbackToast.info("Write something to show on the widget first");
      return;
    }
    try {
      Provider.of<NotesViewModel>(context, listen: false)
          .updateAndroidWidget(body);
    } catch (e) {
      FeedbackToast.error("Sorry, Something went wrong");
      return;
    }
    FeedbackToast.info("Note has been added to the widget");
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
