import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/task_filters.dart';
import '../../../../../models/task_sort.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../models/trashed.dart';
import '../../../../../models/user_profile.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../../view_model/tour_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/app_gate.dart';
import '../../../../widgets/form_dialog.dart';
import '../../../../widgets/glass_menu.dart';
import '../../../../widgets/large_title.dart';
import '../../../../widgets/page_action_buttons.dart';
import '../../../../widgets/page_bar_actions.dart';
import '../../../../widgets/password_dialogs.dart';
import '../../../../widgets/rise_in.dart';
import '../../../../widgets/themed_status_bar.dart';
import '../../../../widgets/tour.dart';
import '../../../../widgets/widget_page_requests.dart';
import '../../../profile/profile_page/screen/profile_page.dart';
import '../../../trash/trash_page/screen/trash_page.dart';
import '../widgets/empty_tasks.dart';
import '../widgets/sort_filter_buttons.dart';
import '../widgets/task_dialog.dart';
import '../widgets/task_list.dart';
import '../widgets/task_map/map_tour.dart';
import '../widgets/task_map/task_map.dart';
import '../widgets/tasks_overwrite_dialog.dart';
import '../widgets/tasks_summary_card.dart';
import '../widgets/todo_tour.dart';

const _title = "ToDo";

/// The room above the list's first card.
const _listTop = 20.0;

/// How long the page takes to rise in, which its tour waits for.
const _tourDelay = Duration(milliseconds: 900);

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> with WidgetPageRequests<TodoPage> {
  final _scrollController = ScrollController();

  @override
  StartPage get widgetPage => StartPage.tasks;

  @override
  void openOtherPage() => _openNotes();

  /// Whether the tasks have been read in. Until then there's nothing under
  /// the title, rather than a "No Tasks" that flashes up first.
  bool _loaded = false;

  /// How many sections rise in ahead of the list's cards: the summary when
  /// the page opens, and none when only the list changes.
  int _listDelay = 1;

  /// The page's tours, each of which shows once: the list's as the page
  /// first opens on the list, and the map's as it first shows the map.
  final _tour = TourController();
  Timer? _tourStart;

  /// Whether a tour is on, or about to be, when the list's first card has
  /// [_firstCardKey], for the tour to find it by. It's only there then, as a
  /// global key moves a card's state along with it when the cards are
  /// reordered.
  bool _touring = false;

  /// What the tours point at: on the list, on the map, then on both.
  final _headerKey = GlobalKey();
  final _firstCardKey = GlobalKey();
  final _buttonsKey = GlobalKey();
  final _hubKey = GlobalKey();
  final _nodeKey = GlobalKey();
  final _fitKey = GlobalKey();
  final _fullScreenKey = GlobalKey();
  final _sortFilterKey = GlobalKey();
  final _menuKey = GlobalKey();

  /// Whether the map has the whole screen: the page's bar and buttons are
  /// out of the way, and so are the phone's status and navigation bars.
  bool _fullScreen = false;

  /// Whether the phone's bars are hidden: while the map has the whole
  /// screen, unless another page is over it.
  bool _systemBarsHidden = false;

  /// The page's route, whose tour waits while another page is over it.
  ModalRoute<Object?>? _route;

  /// Whether another page is over this one, such as the lock page.
  bool _covered = false;

  /// Which tours are due, which says when the user asks for them again.
  late final TourViewModel _tours;

  /// The tasks, which can leave the map with nothing to show.
  late final TasksViewModel _tasks;

  @override
  void initState() {
    super.initState();
    _tours = Provider.of<TourViewModel>(context, listen: false)
      ..addListener(_toursReplayed);
    _tasks = Provider.of<TasksViewModel>(context, listen: false)
      ..addListener(_tasksChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final failed = await Provider.of<TasksViewModel>(
        context,
        listen: false,
      ).get();
      if (!mounted) return;
      setState(() => _loaded = true);
      FeedbackToast.show(failed);
      // Not over tasks that couldn't be read in.
      if (failed == null) await _tourIfDue();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _route?.secondaryAnimation?.removeStatusListener(_coverChanged);
    _route = route;
    route?.secondaryAnimation?.addStatusListener(_coverChanged);
  }

  @override
  void dispose() {
    // The rest of the app has the phone's bars.
    if (_systemBarsHidden) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _route?.secondaryAnimation?.removeStatusListener(_coverChanged);
    _tasks.removeListener(_tasksChanged);
    _tours.removeListener(_toursReplayed);
    _tourStart?.cancel();
    _tour.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// How the page shows the tasks now, and the tour that goes with it.
  TasksView get _view =>
      Provider.of<UserViewModel>(context, listen: false).shownTasksView;
  PageTour get _pageTour =>
      _view == TasksView.map ? PageTour.map : PageTour.tasks;

  /// Shows the tour again once the user asks for the tips again in the
  /// settings, as they come back from them.
  void _toursReplayed() => _tourIfDue();

  /// As another page comes over this one, such as the lock page, which has
  /// the phone's bars, and as the page comes back from under it, or from
  /// under the settings, where the list may have been changed for the map.
  void _coverChanged(AnimationStatus status) {
    _covered = status != AnimationStatus.dismissed;
    _syncSystemBars();
    if (!_covered) _tourIfDue();
  }

  /// Shows the user how the list works, or the map, whichever the page is
  /// showing, once it has settled, if they haven't been shown yet. Not
  /// while the map has the whole screen, without the menu the tour points
  /// at.
  Future<void> _tourIfDue() async {
    final tour = _pageTour;
    if (_touring || _fullScreen || !_loaded) return;
    if (!await _tours.isDue(tour) || !mounted) return;
    // Not for a view that's been switched away from meanwhile, nor under
    // another page.
    if (_touring ||
        _fullScreen ||
        tour != _pageTour ||
        !(_route?.isCurrent ?? true)) {
      return;
    }
    setState(() => _touring = true);
    _tourStart?.cancel();
    _tourStart = Timer(_tourDelay, () => _startTour(tour));
  }

  /// Starts [tour]: the list's, on its first card, or on an example one when
  /// there are no tasks, or the map's.
  void _startTour(PageTour tour) {
    if (tour != _pageTour) {
      setState(() => _touring = false);
      return;
    }
    final first = Provider.of<TasksViewModel>(
      context,
      listen: false,
    ).tree.nodes.firstOrNull;
    _tour.start(
      switch (tour) {
        PageTour.map => mapTour(
          hub: _hubKey,
          node: _nodeKey,
          fit: _fitKey,
          fullScreen: _fullScreenKey,
          sortFilter: _sortFilterKey,
          menu: _menuKey,
        ),
        _ => todoTour(
          task: first?.task,
          now: _tasks.now,
          subtasks: first == null || first.subtaskCount == 0
              ? null
              : (done: first.doneSubtaskCount, total: first.subtaskCount),
          card: _firstCardKey,
          header: _headerKey,
          gap: _listTop,
          buttons: _buttonsKey,
          sortFilter: _sortFilterKey,
          menu: _menuKey,
        ),
      },
      onEnd: () {
        setState(() => _touring = false);
        _tours.finish(tour);
      },
    );
  }

  /// Shows the tasks as a map instead of a list, or the other way round,
  /// for now: only the settings change the view the page opens with.
  void _switchView() {
    // A tour that was about to start is for the view being left.
    _tourStart?.cancel();
    setState(() {
      _touring = false;
      // The list opens afresh, under its summary.
      _listDelay = 1;
    });
    Provider.of<UserViewModel>(
      context,
      listen: false,
    ).showTasksAs(_view == TasksView.list ? TasksView.map : TasksView.list);
    _tourIfDue();
  }

  /// Gives the map the whole screen, or gives the page its bar and buttons
  /// back, and the phone its bars.
  void _setFullScreen(bool on) {
    if (on == _fullScreen) return;
    // A tour about to start waits until the page has its bar back.
    final tourWaits = on && (_tourStart?.isActive ?? false);
    if (tourWaits) _tourStart!.cancel();
    setState(() {
      _fullScreen = on;
      if (tourWaits) _touring = false;
    });
    _syncSystemBars();
    if (!on) _tourIfDue();
  }

  /// Hides the phone's status and navigation bars while the map has the
  /// whole screen and no other page is over it, and shows them otherwise.
  /// A swipe in from the edge of the screen shows them for a moment.
  void _syncSystemBars() {
    final hide = _fullScreen && !_covered;
    if (hide == _systemBarsHidden) return;
    _systemBarsHidden = hide;
    SystemChrome.setEnabledSystemUIMode(
      // Otherwise edge to edge, as the app has them from the start.
      hide ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  /// Gives the page its bar back once the map has nothing left to show, as
  /// the last task on it is deleted, say, for the buttons that add one.
  void _tasksChanged() {
    if (_fullScreen && _tasks.emptyReason != null) _setFullScreen(false);
  }

  @override
  Widget build(BuildContext context) {
    final view = context.select<UserViewModel, TasksView>(
      (user) => user.shownTasksView,
    );
    final fullScreen = _fullScreen && view == TasksView.map;
    final padding = MediaQuery.paddingOf(context);
    return ThemedStatusBar(
      child: PopScope(
        // Back leaves full screen, rather than the app.
        canPop: !fullScreen,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _setFullScreen(false);
        },
        child: Tour(
          controller: _tour,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: context.colors.pageBackground,
            floatingActionButton: _SlideAway(
              hidden: fullScreen,
              away: const Offset(0, 1.5),
              child: KeyedSubtree(
                key: _buttonsKey,
                child: PageActionButtons(
                  switchIcon: Icons.edit_note_rounded,
                  switchTooltip: "Notes",
                  onSwitch: _openNotes,
                  addTooltip: "Add Task",
                  onAdd: _addTask,
                ),
              ),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: switch (view) {
                    TasksView.map => _buildMap(context, fullScreen: fullScreen),
                    TasksView.list => _buildList(context),
                  },
                ),
                // In the corner across from the page's buttons, on the same
                // line as the add button, and under the map's own buttons.
                // It stays as the map takes the whole screen, with those.
                PositionedDirectional(
                  start: 16 + padding.left,
                  bottom: 16 + padding.bottom,
                  child: _SortFilterSlot(
                    loaded: _loaded,
                    buttonsKey: _sortFilterKey,
                    onSort: _changeSort,
                    onFilter: _changeFilter,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tasks as a map that fills the page, under a bar of its own, as the
  /// map doesn't scroll: the page's title and its menu. In [fullScreen], the
  /// bar is out of the way.
  Widget _buildMap(BuildContext context, {required bool fullScreen}) {
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        if (_loaded)
          Positioned.fill(
            child: _TaskMapPane(
              insets: EdgeInsets.fromLTRB(
                padding.left,
                padding.top + (fullScreen ? 0 : TitleBar.height),
                padding.right,
                padding.bottom,
              ),
              fullScreen: fullScreen,
              onFullScreen: _setFullScreen,
              onEdit: _editTask,
              onAddSubtask: _addSubtask,
              hubKey: _hubKey,
              nodeKey: _nodeKey,
              fitKey: _fitKey,
              fullScreenKey: _fullScreenKey,
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _SlideAway(
            hidden: fullScreen,
            away: const Offset(0, -1),
            child: TitleBar(
              title: _title,
              topInset: padding.top,
              trailing: PageBarActions(
                items: _menuItems(TasksView.map),
                menuKey: _menuKey,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The tasks as a list, in one column under the page's title and the
  /// summary, on a phone turned on its side as well.
  Widget _buildList(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // Clear of a camera cutout on a phone turned on its side, and a
    // comfortable width for the cards on wide screens.
    final centred = (MediaQuery.sizeOf(context).width - 640) / 2;
    final left = math.max(16 + padding.left, centred);
    final right = math.max(16 + padding.right, centred);
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: LargeTitleBarDelegate(
            title: _title,
            topInset: padding.top,
            controller: _scrollController,
            trailing: PageBarActions(
              items: _menuItems(TasksView.list),
              menuKey: _menuKey,
            ),
            titleRevealOffset: _TodoHeader.scrolledAway,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(left: left, right: right),
          sliver: SliverToBoxAdapter(
            child: Column(
              key: _headerKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RiseIn(child: _TodoHeader()),
                if (_loaded) const _Overview(),
              ],
            ),
          ),
        ),
        if (_loaded)
          _TaskListSliver(
            padding: EdgeInsets.fromLTRB(
              left,
              _listTop,
              right,
              PageActionButtons.height + 24 + padding.bottom,
            ),
            listDelay: _listDelay,
            onEdit: _editTask,
            onAddSubtask: _addSubtask,
            firstCardKey: _touring ? _firstCardKey : null,
          ),
      ],
    );
  }

  /// The menu's items: first the switch to the map, or back to the list
  /// from [view], then the tasks' less frequent actions.
  List<GlassMenuItem> _menuItems(TasksView view) => [
    GlassMenuItem(
      icon: view == TasksView.list
          ? Icons.hub_rounded
          : Icons.view_agenda_rounded,
      tooltip: view == TasksView.list ? "Show as Map" : "Show as List",
      onPressed: _switchView,
    ),
    GlassMenuItem(
      icon: Icons.settings_backup_restore_rounded,
      tooltip: "Restore Backup",
      onPressed: () =>
          showFormDialog<void>(context, const TasksOverwriteDialog()),
    ),
    GlassMenuItem(
      icon: Icons.backup_rounded,
      tooltip: "Back Up Tasks",
      onPressed: _backUp,
    ),
    GlassMenuItem(
      icon: Icons.delete_outline_rounded,
      tooltip: "Trash",
      onPressed: () => Navigator.push(context, trashRoute(TrashKind.task)),
    ),
    GlassMenuItem(
      icon: Icons.settings_rounded,
      tooltip: "Settings",
      onPressed: _openSettings,
    ),
  ];

  void _changeFilter(TaskFilter filter) {
    // The cards rise in again for the new filter, straight away.
    setState(() => _listDelay = 0);
    Provider.of<TasksViewModel>(context, listen: false).setFilter(filter);
  }

  void _changeSort(TaskSort sort, SortDirection direction) {
    // The cards rise in again in their new order, straight away.
    setState(() => _listDelay = 0);
    Provider.of<TasksViewModel>(
      context,
      listen: false,
    ).setSort(sort, direction: direction);
  }

  /// Backs the tasks up, once the App Lock lets the user through.
  void _backUp() {
    Provider.of<TasksViewModel>(context, listen: false)
        .backup(
          askForPassword: passwordPrompt(
            context,
            subtitle: "Enter your password to back up your tasks.",
          ),
          askForBackupPassword: newBackupPasswordPrompt(context),
        )
        .then(FeedbackToast.show);
  }

  void _addTask() => showFormDialog<void>(context, const TaskDialog());

  void _editTask(TodoItem task) =>
      showFormDialog<void>(context, TaskDialog(task: task));

  void _addSubtask(TodoItem parent) =>
      showFormDialog<void>(context, TaskDialog(parent: parent));

  void _openNotes() => switchToPage(context, StartPage.notes);

  void _openSettings() => Navigator.push(context, profileRoute());
}

/// Moves [task] to the trash, with the tasks in it, as its card has been
/// swiped away, and says so with an Undo that puts them back where they
/// were.
Future<void> _moveToTrash(TasksViewModel tasks, TodoItem task) async =>
    FeedbackToast.show(await tasks.delete(task));

/// The sort and filter buttons, in the bottom left corner, over the list
/// and the map alike. Not there until the tasks are read in, nor while
/// there are none, unless a filter other than All is still on, so it can be
/// turned off.
class _SortFilterSlot extends StatelessWidget {
  const _SortFilterSlot({
    required this.loaded,
    required this.buttonsKey,
    required this.onSort,
    required this.onFilter,
  });

  /// Whether the tasks have been read in.
  final bool loaded;

  /// The key for the buttons, for the tours to find them by.
  final GlobalKey buttonsKey;
  final void Function(TaskSort sort, SortDirection direction) onSort;
  final ValueChanged<TaskFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final wanted = context.select<TasksViewModel, bool>(
      (tasks) =>
          tasks.filter != TaskFilter.all ||
          tasks.finishedTasksCount + tasks.unfinishedTasksCount > 0,
    );
    if (!loaded || !wanted) return const SizedBox.shrink();
    return KeyedSubtree(
      key: buttonsKey,
      // Fades in as they come.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        builder: (context, shown, child) =>
            Opacity(opacity: shown, child: child),
        child: SortFilterButtons(onSort: onSort, onFilter: onFilter),
      ),
    );
  }
}

/// Slides [child] off the screen and fades it out while it's [hidden], as
/// the map takes the whole screen, and brings it back after. It keeps its
/// place meanwhile, so it's laid out as before.
class _SlideAway extends StatelessWidget {
  const _SlideAway({
    required this.hidden,
    required this.away,
    required this.child,
  });

  static const _duration = Duration(milliseconds: 300);

  final bool hidden;

  /// Where it slides to, in its own size: up for the bar, down for the
  /// buttons.
  final Offset away;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedSlide(
          offset: hidden ? away : Offset.zero,
          duration: duration,
          curve: Curves.easeInOutCubic,
          child: AnimatedOpacity(
            opacity: hidden ? 0 : 1,
            duration: duration,
            curve: Curves.easeInOutCubic,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The tasks the filter lets through as a map, or what to show instead when
/// there are none.
class _TaskMapPane extends StatelessWidget {
  const _TaskMapPane({
    required this.insets,
    required this.fullScreen,
    required this.onFullScreen,
    required this.onEdit,
    required this.onAddSubtask,
    required this.hubKey,
    required this.nodeKey,
    required this.fitKey,
    required this.fullScreenKey,
  });

  /// How much of the map the page's bar covers, and the edges of the screen
  /// it's to keep clear of.
  final EdgeInsets insets;

  /// Whether the map has the whole screen, and what gives it the whole
  /// screen, or gives the page its bar back.
  final bool fullScreen;
  final ValueChanged<bool> onFullScreen;

  /// Opens the editor for the task.
  final ValueChanged<TodoItem> onEdit;

  /// Opens the form for a new subtask of the task.
  final ValueChanged<TodoItem> onAddSubtask;

  /// What the map's tour points at.
  final GlobalKey hubKey;
  final GlobalKey nodeKey;
  final GlobalKey fitKey;
  final GlobalKey fullScreenKey;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksViewModel>();
    if (tasks.emptyReason case final reason?) {
      // Centred in the room the bar and the buttons leave, as on the list.
      return Padding(
        padding: EdgeInsets.only(
          top: insets.top,
          bottom: PageActionButtons.height + 24 + insets.bottom,
        ),
        child: RiseIn(
          key: ValueKey(reason),
          child: EmptyTasks(reason: reason),
        ),
      );
    }
    return TaskMap(
      tree: tasks.tree,
      now: tasks.now,
      byHand: tasks.sort == TaskSort.custom,
      done: tasks.finishedTasksCount,
      total: tasks.finishedTasksCount + tasks.unfinishedTasksCount,
      actions: tasks,
      insets: insets,
      onEdit: onEdit,
      onAddSubtask: onAddSubtask,
      onDelete: (task) => _moveToTrash(tasks, task),
      onResult: FeedbackToast.show,
      fullScreen: fullScreen,
      onFullScreen: onFullScreen,
      // Over the sort and filter buttons, as far apart as the map's own.
      belowButtons: SortFilterButtons.height + 10,
      hubKey: hubKey,
      nodeKey: nodeKey,
      fitKey: fitKey,
      fullScreenKey: fullScreenKey,
    );
  }
}

/// Today's date over the page's large title, which scrolls away under the
/// bar: the day the tasks are for, which turns over with them.
class _TodoHeader extends StatelessWidget {
  const _TodoHeader();

  /// About how far the header scrolls before its title is under the bar, so
  /// the bar can bring in its own copy of the title.
  static const scrolledAway = 40.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat("EEEE, MMMM d")
              .format(
                context.select<TasksViewModel, DateTime>(
                  (tasks) => tasks.today,
                ),
              )
              .toUpperCase(),
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

/// The progress summary, under the title, while there are tasks.
class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    final total = context.select<TasksViewModel, int>(
      (tasks) => tasks.finishedTasksCount + tasks.unfinishedTasksCount,
    );
    if (total == 0) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(top: 18),
      child: RiseIn(delay: RiseIn.stagger, child: TasksSummaryCard()),
    );
  }
}

/// The tasks the filter lets through, or what to show instead when there
/// are none.
class _TaskListSliver extends StatelessWidget {
  const _TaskListSliver({
    required this.padding,
    required this.listDelay,
    required this.onEdit,
    required this.onAddSubtask,
    required this.firstCardKey,
  });

  /// Around the list. Its bottom keeps the last card clear of the buttons.
  final EdgeInsets padding;

  /// How many sections rise in ahead of the first card.
  final int listDelay;

  /// Opens the editor for the task.
  final ValueChanged<TodoItem> onEdit;

  /// Opens the form for a new subtask of the task.
  final ValueChanged<TodoItem> onAddSubtask;

  /// The key for the first card, if it's to have one.
  final GlobalKey? firstCardKey;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksViewModel>();
    final (titleScale, descriptionScale, descriptionLines) = context
        .select<UserViewModel, (double, double, int)>(
          (user) => (
            user.user.tasksTitleSize,
            user.user.tasksDescSize,
            user.user.descLines,
          ),
        );
    if (tasks.emptyReason case final reason?) {
      return SliverFillRemaining(
        hasScrollBody: false,
        // Centred in the room the buttons leave, within the page rather than
        // past its end, so an empty page doesn't scroll.
        child: Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          child: RiseIn(
            key: ValueKey(reason),
            child: EmptyTasks(reason: reason),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: padding,
      // A new list for each filter and sort, so the cards rise in afresh.
      sliver: TaskList(
        key: ValueKey((tasks.filter, tasks.sort, tasks.sortDirection)),
        tree: tasks.tree,
        now: tasks.now,
        byHand: tasks.sort == TaskSort.custom,
        titleScale: titleScale,
        descriptionScale: descriptionScale,
        descriptionLines: descriptionLines,
        actions: tasks,
        listDelay: listDelay,
        onEdit: onEdit,
        onAddSubtask: onAddSubtask,
        onDelete: (task) => _moveToTrash(tasks, task),
        onResult: FeedbackToast.show,
        firstCardKey: firstCardKey,
      ),
    );
  }
}
