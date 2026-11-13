import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/note.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../models/trashed.dart';
import '../../../../../view_model/notes_view_model.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../widgets/glass_icon_button.dart';
import '../../../../widgets/glass_menu.dart';
import '../../../../widgets/large_title.dart';
import '../../../../widgets/rise_in.dart';
import '../../../profile/lock_page/widgets/password_dialogs.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/empty_trash.dart';
import '../widgets/trash_card.dart';

const _title = "Trash";

/// The gap between cards.
const _cardGap = 12.0;

/// The room above the list's first card.
const _listTop = 20.0;

/// iOS's system red, a touch brighter on dark pages, as there.
Color _systemRed(bool isDarkTheme) =>
    isDarkTheme ? const Color(0xffFF453A) : const Color(0xffFF3B30);

/// The trash page, sliding in from the side, with the deleted [kind] in
/// view.
Route<void> trashRoute(TrashKind kind) => PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          TrashPage(kind: kind),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
        position: animation.drive(
            Tween(begin: const Offset(1, 0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.ease))),
        child: child,
      ),
    );

/// Where deleted tasks and notes wait until the user puts them back or
/// deletes them for good: one or the other at a time, with a switch between
/// the two.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key, required this.kind});

  /// Whether the deleted tasks are in view as the page opens, or the notes.
  final TrashKind kind;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final _scrollController = ScrollController();

  late TrashKind _kind = widget.kind;

  /// Whether the trash has been read in. Until then there's nothing under
  /// the header, rather than an empty trash that flashes up first.
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final reads = [
        Provider.of<TasksViewModel>(context, listen: false).getTrash(),
        Provider.of<NotesViewModel>(context, listen: false).getTrash(),
      ];
      try {
        await Future.wait(reads);
      } finally {
        if (mounted) setState(() => _loaded = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    // Clear of a camera cutout on a phone turned on its side, and a
    // comfortable width on large screens, as on the to-do page.
    final gutterLeft = math.max(16 + padding.left, (width - 640) / 2);
    final gutterRight = math.max(16 + padding.right, (width - 640) / 2);
    final tasks =
        context.select<TasksViewModel, int>((tasks) => tasks.trash.length);
    final notes =
        context.select<NotesViewModel, int>((notes) => notes.trash.length);
    final count = _kind == TrashKind.task ? tasks : notes;
    final listPadding = EdgeInsets.fromLTRB(
        gutterLeft, _listTop, gutterRight, 24 + padding.bottom);
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
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: LargeTitleBarDelegate(
                title: _title,
                topInset: padding.top,
                controller: _scrollController,
                leading: Padding(
                  padding: EdgeInsets.only(left: padding.left),
                  child: GlassIconButton(
                    icon: Icons.chevron_left_rounded,
                    iconSize: 28,
                    tooltip: "Back",
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Only with something to restore or delete.
                trailing: count == 0
                    ? null
                    : Padding(
                        padding: EdgeInsets.only(right: padding.right),
                        child: GlassMenu(items: _menuItems(isDarkTheme)),
                      ),
                titleRevealOffset: _TrashHeader.scrolledAway,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(left: gutterLeft, right: gutterRight),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RiseIn(child: _TrashHeader(tasks: tasks, notes: notes)),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: RiseIn(
                        delay: RiseIn.stagger,
                        child: _KindControl(kind: _kind, onChanged: _show),
                      ),
                    ),
                    // Only over a list, as the empty trash says as much.
                    if (_loaded && count > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                        child: RiseIn(
                          delay: RiseIn.stagger * 2,
                          child: _Hint(kind: _kind),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_loaded)
              switch (_kind) {
                TrashKind.task => _TrashList<TodoItem>(
                    // A list of its own for each, so the cards rise in
                    // afresh.
                    key: const ValueKey(TrashKind.task),
                    kind: TrashKind.task,
                    entries: context.watch<TasksViewModel>().trash,
                    padding: listPadding,
                    cardOf: (entry) => TrashTaskCard(
                      entry: entry,
                      onRestore: () => _restoreTask(entry),
                      onDelete: () => _deleteTask(entry),
                    ),
                  ),
                TrashKind.note => _TrashList<Note>(
                    key: const ValueKey(TrashKind.note),
                    kind: TrashKind.note,
                    entries: context.watch<NotesViewModel>().trash,
                    padding: listPadding,
                    cardOf: (entry) => TrashNoteCard(
                      entry: entry,
                      onRestore: () => _restoreNote(entry),
                      onDelete: () => _deleteNote(entry),
                    ),
                  ),
              },
          ],
        ),
      ),
    );
  }

  List<GlassMenuItem> _menuItems(bool isDarkTheme) => [
        GlassMenuItem(
          icon: Icons.restore_from_trash_rounded,
          tooltip: "Restore All",
          onPressed: _restoreAll,
        ),
        GlassMenuItem(
          icon: Icons.delete_sweep_rounded,
          tooltip: "Delete All",
          color: _systemRed(isDarkTheme),
          onPressed: _deleteAll,
        ),
      ];

  void _show(TrashKind kind) => setState(() => _kind = kind);

  Future<void> _restoreTask(Trashed<TodoItem> entry) async {
    final tasks = Provider.of<TasksViewModel>(context, listen: false);
    _showResult(await tasks.restoreFromTrash(entry));
  }

  Future<void> _restoreNote(Trashed<Note> entry) async {
    final notes = Provider.of<NotesViewModel>(context, listen: false);
    _showResult(await notes.restoreFromTrash(entry));
  }

  /// Deletes [entry]'s task for good, once the user says to.
  Future<void> _deleteTask(Trashed<TodoItem> entry) async {
    final tasks = Provider.of<TasksViewModel>(context, listen: false);
    final confirmed = await confirmDeleteForever(
      context,
      title: "Delete Forever?",
      message: "“${entry.item.title}” will be deleted for good. This can't "
          "be undone.",
    );
    if (confirmed) _showResult(await tasks.deleteForever(entry));
  }

  /// Deletes [entry]'s note for good, once the user says to, and once its
  /// lock lets them through.
  Future<void> _deleteNote(Trashed<Note> entry) async {
    final notes = Provider.of<NotesViewModel>(context, listen: false);
    final askForPassword = noteLockPasswordPrompt(context);
    final confirmed = await confirmDeleteForever(
      context,
      title: "Delete Forever?",
      message: "“${entry.item.title}” will be deleted for good. This can't "
          "be undone.",
    );
    if (confirmed) {
      _showResult(
          await notes.deleteForever(entry, askForPassword: askForPassword));
    }
  }

  /// Puts back every task, or every note, as the page shows.
  Future<void> _restoreAll() async {
    final Result result;
    switch (_kind) {
      case TrashKind.task:
        result = await Provider.of<TasksViewModel>(context, listen: false)
            .restoreAllFromTrash();
      case TrashKind.note:
        result = await Provider.of<NotesViewModel>(context, listen: false)
            .restoreAllFromTrash();
    }
    _showResult(result);
  }

  /// Deletes every task, or every note, as the page shows, for good, once
  /// the user says to.
  Future<void> _deleteAll() async {
    final tasks = Provider.of<TasksViewModel>(context, listen: false);
    final notes = Provider.of<NotesViewModel>(context, listen: false);
    final askForPassword = noteLockPasswordPrompt(context);
    final kind = _kind;
    final (count, things) = switch (kind) {
      TrashKind.task => (tasks.trash.length, "tasks"),
      TrashKind.note => (notes.trash.length, "notes"),
    };
    final confirmed = await confirmDeleteForever(
      context,
      title: "Delete All ${things[0].toUpperCase()}${things.substring(1)}?",
      message: count == 1
          ? "The ${things.substring(0, things.length - 1)} in the Trash will "
              "be deleted for good. This can't be undone."
          : "The $count $things in the Trash will be deleted for good. This "
              "can't be undone.",
    );
    if (!confirmed) return;
    _showResult(switch (kind) {
      TrashKind.task => await tasks.emptyTrash(),
      TrashKind.note => await notes.emptyTrash(askForPassword: askForPassword),
    });
  }
}

/// Shows how [result] went.
void _showResult(Result result) => result.when(
      onSuccess: FeedbackToast.success,
      onFailure: FeedbackToast.error,
      onInfo: FeedbackToast.info,
    );

/// How many tasks and notes are in the trash, over the page's large title,
/// which scrolls away under the bar.
class _TrashHeader extends StatelessWidget {
  const _TrashHeader({required this.tasks, required this.notes});

  final int tasks;
  final int notes;

  /// About how far the header scrolls before its title is under the bar, so
  /// the bar can bring in its own copy of the title.
  static const scrolledAway = 40.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blank with nothing in the trash, but still a line tall, so the
        // title sits where the other pages' do.
        Text(
          [
            if (tasks > 0) tasks == 1 ? "1 task" : "$tasks tasks",
            if (notes > 0) notes == 1 ? "1 note" : "$notes notes",
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

/// The switch between the deleted tasks and the deleted notes.
class _KindControl extends StatelessWidget {
  const _KindControl({required this.kind, required this.onChanged});

  final TrashKind kind;
  final ValueChanged<TrashKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<TrashKind>(
      groupValue: kind,
      onValueChanged: (kind) {
        if (kind != null) onChanged(kind);
      },
      children: const {
        TrashKind.task: _Segment(icon: Icons.checklist_rounded, label: "To-Do"),
        TrashKind.note:
            _Segment(icon: Icons.sticky_note_2_rounded, label: "Notes"),
      },
    );
  }
}

/// A segment of the switch: an icon, then a label that shrinks to fit a
/// segment too narrow for it, as in large text.
class _Segment extends StatelessWidget {
  const _Segment({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: const TextStyle(fontSize: 14.5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the trash keeps, and for how long.
class _Hint extends StatelessWidget {
  const _Hint({required this.kind});

  final TrashKind kind;

  @override
  Widget build(BuildContext context) {
    return Text(
      switch (kind) {
        TrashKind.task => "Deleted tasks stay here until you restore them or "
            "delete them forever.",
        TrashKind.note => "Deleted notes stay here until you restore them or "
            "delete them forever.",
      },
      style: TextStyle(
        color: context.colors.wB.withValues(alpha: 0.5),
        fontSize: 13.5,
        height: 1.35,
      ),
    );
  }
}

/// The [entries] in the trash, the last deleted first, as cards that fold
/// away as they're put back or deleted for good, or what to show instead
/// when there are none.
class _TrashList<T> extends StatefulWidget {
  const _TrashList({
    super.key,
    required this.kind,
    required this.entries,
    required this.padding,
    required this.cardOf,
  });

  final TrashKind kind;
  final List<Trashed<T>> entries;

  /// Around the list.
  final EdgeInsets padding;
  final Widget Function(Trashed<T> entry) cardOf;

  @override
  State<_TrashList<T>> createState() => _TrashListState<T>();
}

class _TrashListState<T> extends State<_TrashList<T>> {
  /// The entries on view: those in the trash, and those just taken out of
  /// it, which keep their place while they fold away.
  late List<Trashed<T>> _shown = widget.entries;

  /// The ids of the entries folding away.
  final _leaving = <int>{};

  /// Whether the list is being laid out for the first time, when the cards
  /// in view rise in one after another.
  bool _opening = true;

  /// The entries there were at the last build, so one that's come since can
  /// rise in by itself.
  Set<int> _known = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _opening = false);
  }

  @override
  void didUpdateWidget(_TrashList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final inTrash = {for (final entry in widget.entries) entry.id};
    final gone = [
      for (final entry in _shown)
        if (!inTrash.contains(entry.id)) entry,
    ];
    _leaving.addAll(gone.map((entry) => entry.id));
    // In the trash's own order, the last deleted first: newer entries have
    // higher ids.
    _shown = [...widget.entries, ...gone]..sort((a, b) => b.id.compareTo(a.id));
  }

  void _gone(int id) {
    if (!mounted) return;
    setState(() {
      _leaving.remove(id);
      _shown = [
        for (final entry in _shown)
          if (entry.id != id) entry,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding;
    if (_shown.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          child: RiseIn(child: EmptyTrash(kind: widget.kind)),
        ),
      );
    }
    final ids = {for (final entry in widget.entries) entry.id};
    final added = _opening ? const <int>{} : ids.difference(_known);
    _known = ids;
    return SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: _shown.length,
        // Keeps each card's state with its entry as the ones above it go.
        findChildIndexCallback: (key) {
          if (key is! ValueKey<int>) return null;
          final index = _shown.indexWhere((entry) => entry.id == key.value);
          return index == -1 ? null : index;
        },
        itemBuilder: (context, index) {
          final entry = _shown[index];
          final leaving = _leaving.contains(entry.id);
          return _Leaving(
            key: ValueKey(entry.id),
            leaving: leaving,
            onGone: () => _gone(entry.id),
            child: Padding(
              padding: const EdgeInsets.only(bottom: _cardGap),
              child: RiseIn(
                animate: _opening || added.contains(entry.id),
                delay: _opening
                    ? RiseIn.stagger * (3 + math.min(index, 8))
                    : Duration.zero,
                child: IgnorePointer(
                  ignoring: leaving,
                  child: widget.cardOf(entry),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A card that fades and folds away once its entry is out of the trash,
/// closing the gap it leaves, then says it's [onGone].
class _Leaving extends StatefulWidget {
  const _Leaving({
    super.key,
    required this.leaving,
    required this.onGone,
    required this.child,
  });

  final bool leaving;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<_Leaving> createState() => _LeavingState();
}

class _LeavingState extends State<_Leaving>
    with SingleTickerProviderStateMixin {
  // Played backwards as the card goes: it fades and shrinks a little first,
  // then the room it took closes up.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 1, curve: Curves.easeOut),
  );
  late final _size = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.7, curve: Curves.easeInOutCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.leaving) _leave();
  }

  @override
  void didUpdateWidget(_Leaving oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving && !oldWidget.leaving) _leave();
  }

  void _leave() => _controller.reverse().whenComplete(() {
        if (mounted) widget.onGone();
      });

  @override
  void dispose() {
    _fade.dispose();
    _size.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(_fade),
          child: widget.child,
        ),
      ),
    );
  }
}
