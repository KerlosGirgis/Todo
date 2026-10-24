import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/note.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../widgets/appbar_avatar.dart';
import '../../../../widgets/glass_menu.dart';
import '../../../../widgets/large_title.dart';
import '../../../../widgets/page_action_buttons.dart';
import '../../../../widgets/rise_in.dart';
import '../../../profile/lock_page/widgets/password_dialogs.dart';
import '../../../profile/profile_page/screen/profile_page.dart';
import '../../../profile/profile_page/widgets/aurora.dart';
import '../../../tasks/todo_page/screen/todo_page.dart';
import '../../../tasks/todo_page/widgets/form_dialog.dart';
import '../../note_editor_page/screen/note_editor_page.dart';
import '../widgets/empty_notes.dart';
import '../widgets/note_card.dart';
import '../widgets/note_dialog.dart';
import '../widgets/notes_overwrite_dialog.dart';
import '../widgets/notes_search_field.dart';
import '../widgets/reorder_notes_dialog.dart';

const _title = "Notes";

/// The gap between cards.
const _cardGap = 14.0;

/// How wide a card grows before another column of them fits.
const _maxCardWidth = 220.0;

/// A card's width over its height.
const _cardAspectRatio = 0.8;

/// The page's margins either side: clear of a camera cutout on a phone
/// turned on its side, and a comfortable width on large screens.
(double, double) _gutters(double width, EdgeInsets padding) => (
      math.max(16 + padding.left, (width - 1040) / 2),
      math.max(16 + padding.right, (width - 1040) / 2),
    );

/// How big each card is in the grid on this screen, so that a card drawn
/// elsewhere, like the settings' preview of the title size, is as big and
/// breaks its title over lines just as it will here.
Size noteCardSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final (left, right) = _gutters(width, MediaQuery.paddingOf(context));
  final gridWidth = width - left - right;
  // As the grid's delegate shares the width out between its columns.
  final columns =
      math.max(1, (gridWidth / (_maxCardWidth + _cardGap)).ceil());
  final cardWidth =
      math.max(0.0, gridWidth - _cardGap * (columns - 1)) / columns;
  return Size(cardWidth, cardWidth / _cardAspectRatio);
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Whether the notes have been read in. Until then there's nothing under
  /// the title, rather than a "No Notes" that flashes up first.
  bool _loaded = false;

  /// What the notes are searched for; empty shows them all.
  String _query = "";

  /// How many sections rise in ahead of the grid's cards: the search field
  /// when the page opens, and none once the grid only changes.
  int _gridDelay = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Provider.of<NotesViewModel>(context, listen: false).get();
      } finally {
        if (mounted) setState(() => _loaded = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    final (gutterLeft, gutterRight) =
        _gutters(MediaQuery.sizeOf(context).width, padding);
    // The last cards scroll clear of the buttons, or of the keyboard while
    // searching.
    final bottomInset = math.max(PageActionButtons.height + 24 + padding.bottom,
        MediaQuery.viewInsetsOf(context).bottom + 24);
    final hasNotes =
        context.select<NotesViewModel, bool>((notes) => notes.notes.isNotEmpty);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // There's no app bar to pick the status bar's icons, so they're set here.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: context.colors.pageBackground,
        floatingActionButton: PageActionButtons(
          switchIcon: Icons.checklist_rounded,
          switchTooltip: "To-Do",
          onSwitch: _openTodo,
          addTooltip: "New Note",
          onAdd: _addNote,
        ),
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
                child: const ProfileAurora(),
              ),
            ),
            CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: LargeTitleBarDelegate(
                    title: _title,
                    topInset: padding.top,
                    controller: _scrollController,
                    trailing: Padding(
                      padding: EdgeInsets.only(right: padding.right),
                      child: _BarActions(items: _menuItems()),
                    ),
                    titleRevealOffset: _NotesHeader.scrolledAway,
                  ),
                ),
                SliverPadding(
                  padding:
                      EdgeInsets.only(left: gutterLeft, right: gutterRight),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const RiseIn(child: _NotesHeader()),
                        // Only while there's something to search, or a search
                        // to clear.
                        if (_loaded && (hasNotes || _query.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: RiseIn(
                              delay: RiseIn.stagger,
                              child: NotesSearchField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _search,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_loaded)
                  _NoteGridSliver(
                    query: _query,
                    padding: EdgeInsets.fromLTRB(
                        gutterLeft, 20, gutterRight, bottomInset),
                    gridDelay: _gridDelay,
                    onOpen: _openNote,
                    onEdit: _editNote,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<GlassMenuItem> _menuItems() => [
        GlassMenuItem(
          icon: Icons.swap_vert_rounded,
          tooltip: "Reorder Notes",
          onPressed: () =>
              showFormDialog<void>(context, const ReorderNotesDialog()),
        ),
        GlassMenuItem(
          icon: Icons.settings_backup_restore_rounded,
          tooltip: "Restore Backup",
          onPressed: () =>
              showFormDialog<void>(context, const NotesOverwriteDialog()),
        ),
        GlassMenuItem(
          icon: Icons.backup_rounded,
          tooltip: "Back Up Notes",
          onPressed: _backUp,
        ),
        GlassMenuItem(
          icon: Icons.settings_rounded,
          tooltip: "Settings",
          onPressed: _openSettings,
        ),
      ];

  void _search(String query) {
    // Cards a search brings back show up straight away.
    setState(() {
      _query = query;
      _gridDelay = 0;
    });
  }

  /// Backs the notes up, once the App Lock lets the user through.
  void _backUp() {
    final notes = Provider.of<NotesViewModel>(context, listen: false);
    withAppLockPassword(
      context,
      subtitle: "Enter your password to back up your notes.",
      action: (password) => notes.backup(password: password).then(_showResult),
    );
  }

  void _addNote() {
    _searchFocusNode.unfocus();
    showFormDialog<void>(context, const NoteDialog());
  }

  /// Opens [note] in the editor, once its lock lets the user through.
  Future<void> _openNote(Note note) async {
    final result = await Provider.of<NotesViewModel>(context, listen: false)
        .authenticate(note, askForPassword: noteLockPasswordPrompt(context));
    if (!mounted) return;
    if (result is Failure) {
      FeedbackToast.error(result.message);
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoteEditorPage(note: note),
        // Fades in around the note's cover, which grows out of its card into
        // the top of the editor, covering the notes well before it lands.
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
          opacity: animation.drive(
              CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut))),
          child: child,
        ),
      ),
    );
  }

  /// Opens the dialog that changes [note]'s title, colours and lock, once
  /// its lock lets the user through.
  Future<void> _editNote(Note note) async {
    final result = await Provider.of<NotesViewModel>(context, listen: false)
        .authenticate(note, askForPassword: noteLockPasswordPrompt(context));
    if (!mounted) return;
    if (result is Failure) {
      FeedbackToast.error(result.message);
      return;
    }
    showFormDialog<void>(context, NoteDialog(note: note));
  }

  void _openTodo() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const TodoPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: animation.drive(
              Tween(begin: const Offset(1, 0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.ease))),
          child: child,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfilePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: animation.drive(
              Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.ease))),
          child: child,
        ),
      ),
    );
  }
}

void _showResult(Result result) => result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );

/// The menu of the notes' less frequent actions, and the avatar, at the end
/// of the bar.
class _BarActions extends StatelessWidget {
  const _BarActions({required this.items});

  final List<GlassMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassMenu(items: items),
        const SizedBox(width: 10),
        const AppbarAvatar(),
      ],
    );
  }
}

/// How many notes there are, over the page's large title, which scrolls
/// away under the bar.
class _NotesHeader extends StatelessWidget {
  const _NotesHeader();

  /// About how far the header scrolls before its title is under the bar, so
  /// the bar can bring in its own copy of the title.
  static const scrolledAway = 40.0;

  @override
  Widget build(BuildContext context) {
    final (count, locked) =
        context.select<NotesViewModel, (int, int)>((notes) => (
              notes.notes.length,
              notes.lockedCount,
            ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blank with no notes, as the empty state says so, but still a line
        // tall, so the title sits where the to-do page's does.
        Text(
          [
            if (count > 0) count == 1 ? "1 note" : "$count notes",
            if (locked > 0) "$locked locked",
          ].join(" · ").toUpperCase(),
          style: TextStyle(
            color: context.colors.moreLess,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.wB,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

/// The notes the search finds, or what to show instead when there are none.
class _NoteGridSliver extends StatelessWidget {
  const _NoteGridSliver({
    required this.query,
    required this.padding,
    required this.gridDelay,
    required this.onOpen,
    required this.onEdit,
  });

  final String query;

  /// Around the grid. Its bottom keeps the last cards clear of the buttons.
  final EdgeInsets padding;

  /// How many sections rise in ahead of the first card.
  final int gridDelay;

  /// Opens the note in the editor, on a tap.
  final ValueChanged<Note> onOpen;

  /// Opens the dialog that changes the note's cover, on a long press.
  final ValueChanged<Note> onEdit;

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesViewModel>();
    final matching = notes.search(query);
    if (notes.notes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        // Centred in the room the buttons leave, within the page rather than
        // past its end, so an empty page doesn't scroll.
        child: Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          child: const RiseIn(child: EmptyNotes()),
        ),
      );
    }
    if (matching.isEmpty) {
      // Near the top rather than centred, which could be behind the keyboard.
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(padding.left, 28, padding.right, 0),
        sliver: SliverToBoxAdapter(
          child: RiseIn(child: EmptyNotes(query: query.trim())),
        ),
      );
    }
    return SliverPadding(
      padding: padding,
      sliver: _NoteGrid(
        notes: notes.notes,
        matching: matching,
        gridDelay: gridDelay,
        onOpen: onOpen,
        onEdit: onEdit,
      ),
    );
  }
}

class _NoteGrid extends StatefulWidget {
  const _NoteGrid({
    required this.notes,
    required this.matching,
    required this.gridDelay,
    required this.onOpen,
    required this.onEdit,
  });

  /// Every note, which tells a note just added from one the search let back
  /// in.
  final List<Note> notes;

  /// The notes the search finds, which the grid shows.
  final List<Note> matching;
  final int gridDelay;
  final ValueChanged<Note> onOpen;
  final ValueChanged<Note> onEdit;

  @override
  State<_NoteGrid> createState() => _NoteGridState();
}

class _NoteGridState extends State<_NoteGrid> {
  /// Whether the grid is being laid out for the first time, when the cards
  /// in view rise in one after another.
  bool _opening = true;

  /// The notes there were at the last build, so a note added since can rise
  /// in by itself.
  Set<int?> _known = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final ids = {for (final note in widget.notes) note.id};
    // Only a note added makes the count grow; reordering the notes gives
    // every one of them a new id, but they're the same notes.
    final added = !_opening && ids.length > _known.length
        ? ids.difference(_known)
        : const <int?>{};
    _known = ids;
    final notes = widget.matching;
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth,
        mainAxisSpacing: _cardGap,
        crossAxisSpacing: _cardGap,
        childAspectRatio: _cardAspectRatio,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return RiseIn(
          key: ValueKey(note.id),
          animate: _opening || added.contains(note.id),
          delay: _opening
              ? RiseIn.stagger * (widget.gridDelay + math.min(index, 8))
              : Duration.zero,
          child: NoteCard(
            note: note,
            onTap: () => widget.onOpen(note),
            onLongPress: () => widget.onEdit(note),
          ),
        );
      },
    );
  }
}
