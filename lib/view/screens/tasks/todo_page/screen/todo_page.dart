import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../../../core/extensions/theme_extensions.dart';
import '../../../../../core/result.dart';
import '../../../../../core/ui/feedback_toast.dart';
import '../../../../../models/task_filters.dart';
import '../../../../../models/todo_item.dart';
import '../../../../../models/trashed.dart';
import '../../../../../models/user_profile.dart';
import '../../../../../view_model/tasks_view_model.dart';
import '../../../../../view_model/tour_view_model.dart';
import '../../../../../view_model/user_view_model.dart';
import '../../../../widgets/appbar_avatar.dart';
import '../../../../widgets/glass_menu.dart';
import '../../../../widgets/large_title.dart';
import '../../../../widgets/page_action_buttons.dart';
import '../../../../widgets/rise_in.dart';
import '../../../../widgets/tour.dart';
import '../../../notes/notes_page/screen/notes_page.dart';
import '../../../profile/lock_page/widgets/password_dialogs.dart';
import '../../../profile/profile_page/screen/profile_page.dart';
import '../../../trash/trash_page/screen/trash_page.dart';
import '../widgets/empty_tasks.dart';
import '../widgets/form_dialog.dart';
import '../widgets/task_dialog.dart';
import '../widgets/task_filter_bar.dart';
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
  const TodoPage({
    super.key,
  });

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // One per scroll view, as the two layouts briefly overlap when the screen
  // turns, and a controller can't follow two scroll views at once.
  final _scrollController = ScrollController();
  final _overviewPaneScrollController = ScrollController();
  final _listPaneScrollController = ScrollController();

  /// Whether the tasks have been read in. Until then there's nothing under
  /// the title, rather than a "No Tasks" that flashes up first.
  bool _loaded = false;

  /// How many sections rise in ahead of the list's cards: the summary and
  /// the filter when the page opens, and none when only the list changes.
  int _listDelay = 2;

  /// The page's tours, each of which shows once: the list's as the page
  /// first opens on the list, and the map's as it first shows the map.
  final _tour = TourController();
  Timer? _tourStart;

  /// Whether a tour is on, or about to be, when the list's first card has
  /// [_firstCardKey], for the tour to find it by. It's only there then, as a
  /// global key moves a card's state along with it when the cards are
  /// reordered.
  bool _touring = false;

  /// What the tours point at: on the list, then on the map.
  final _headerKey = GlobalKey();
  final _firstCardKey = GlobalKey();
  final _buttonsKey = GlobalKey();
  final _menuKey = GlobalKey();
  final _hubKey = GlobalKey();
  final _nodeKey = GlobalKey();
  final _fitKey = GlobalKey();

  /// How tall the bar over the map is, once it's been laid out: the map is
  /// fitted to the room under it.
  double? _mapBarHeight;

  /// The page's route, whose tour waits while another page is over it.
  ModalRoute<Object?>? _route;

  /// Which tours are due, which says when the user asks for them again.
  late final TourViewModel _tours;

  /// Starts the daily tasks over when the app comes back on a new day.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _tours = Provider.of<TourViewModel>(context, listen: false)
      ..addListener(_toursReplayed);
    _lifecycle = AppLifecycleListener(
      onResume:
          Provider.of<TasksViewModel>(context, listen: false).checkForNewDay,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Provider.of<TasksViewModel>(context, listen: false).get();
      } finally {
        if (mounted) setState(() => _loaded = true);
      }
      _tourIfDue();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _route?.secondaryAnimation?.removeStatusListener(_uncovered);
    _route = route;
    route?.secondaryAnimation?.addStatusListener(_uncovered);
  }

  @override
  void dispose() {
    _route?.secondaryAnimation?.removeStatusListener(_uncovered);
    _lifecycle.dispose();
    _tours.removeListener(_toursReplayed);
    _tourStart?.cancel();
    _tour.dispose();
    _scrollController.dispose();
    _overviewPaneScrollController.dispose();
    _listPaneScrollController.dispose();
    super.dispose();
  }

  /// How the page shows the tasks now, and the tour that goes with it.
  TasksView get _view =>
      Provider.of<UserViewModel>(context, listen: false).user.tasksView;
  PageTour get _pageTour =>
      _view == TasksView.map ? PageTour.map : PageTour.tasks;

  /// Shows the tour again once the user asks for the tips again in the
  /// settings, as they come back from them.
  void _toursReplayed() => _tourIfDue();

  /// As the page comes back from under another, such as the settings, where
  /// the list may have been changed for the map.
  void _uncovered(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _tourIfDue();
  }

  /// Shows the user how the list works, or the map, whichever the page is
  /// showing, once it has settled, if they haven't been shown yet.
  Future<void> _tourIfDue() async {
    final tour = _pageTour;
    if (_touring || !_loaded || !await _tours.isDue(tour) || !mounted) return;
    // Not for a view that's been switched away from meanwhile, nor under
    // another page.
    if (_touring || tour != _pageTour || !(_route?.isCurrent ?? true)) return;
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
    final first = Provider.of<TasksViewModel>(context, listen: false)
        .tree
        .nodes
        .firstOrNull;
    _tour.start(
      switch (tour) {
        PageTour.map => mapTour(
            hub: _hubKey,
            node: _nodeKey,
            fit: _fitKey,
            menu: _menuKey,
          ),
        _ => todoTour(
            task: first?.task,
            subtasks: first == null || first.subtaskCount == 0
                ? null
                : (done: first.doneSubtaskCount, total: first.subtaskCount),
            card: _firstCardKey,
            header: _headerKey,
            gap: _listTop,
            buttons: _buttonsKey,
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
  /// and from now on.
  Future<void> _switchView() async {
    final user = Provider.of<UserViewModel>(context, listen: false);
    // A tour that was about to start is for the view being left.
    _tourStart?.cancel();
    setState(() {
      _touring = false;
      // The list opens afresh, under its summary and its filter.
      _listDelay = 2;
    });
    await user.setTasksView(
        user.user.tasksView == TasksView.list ? TasksView.map : TasksView.list);
    if (mounted) _tourIfDue();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // Side by side when the screen is too short for one long column, as on a
    // phone turned on its side.
    final twoPanes =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
            MediaQuery.sizeOf(context).aspectRatio >= 1.5;
    final view =
        context.select<UserViewModel, TasksView>((user) => user.user.tasksView);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // There's no app bar to pick the status bar's icons, so they're set here.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
      ),
      child: Tour(
        controller: _tour,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: context.colors.pageBackground,
          floatingActionButton: KeyedSubtree(
            key: _buttonsKey,
            child: PageActionButtons(
              switchIcon: Icons.edit_note_rounded,
              switchTooltip: "Notes",
              onSwitch: _openNotes,
              addTooltip: "Add Task",
              onAdd: _addTask,
            ),
          ),
          body: switch (view) {
            TasksView.map => _buildMap(context),
            TasksView.list =>
              twoPanes ? _buildTwoPanes(context) : _buildOnePane(context),
          },
        ),
      ),
    );
  }

  /// The tasks as a map that fills the page, under a bar of its own with
  /// the filters on it: the map doesn't scroll, so there's no header for
  /// them to scroll away with.
  Widget _buildMap(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final barHeight = _mapBarHeight;
    return Stack(
      children: [
        // Once the bar says how much room it leaves.
        if (_loaded && barHeight != null)
          Positioned.fill(
            child: _TaskMapPane(
              insets: EdgeInsets.fromLTRB(
                  padding.left, barHeight, padding.right, padding.bottom),
              onEdit: _editTask,
              onAddSubtask: _addSubtask,
              hubKey: _hubKey,
              nodeKey: _nodeKey,
              fitKey: _fitKey,
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _MeasuredHeight(
            onChange: (height) {
              if (mounted && height != _mapBarHeight) {
                setState(() => _mapBarHeight = height);
              }
            },
            child: _MapBar(
              trailing: _BarActions(
                  items: _menuItems(TasksView.map), menuKey: _menuKey),
              // Once there are tasks to say whether there's anything to
              // filter.
              filters: _loaded,
              onFilterChanged: _changeFilter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnePane(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // Keeps the cards a comfortable width on tablets.
    final gutter = math.max(16.0, (MediaQuery.sizeOf(context).width - 640) / 2);
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: LargeTitleBarDelegate(
            title: _title,
            topInset: padding.top,
            controller: _scrollController,
            trailing: _BarActions(
                items: _menuItems(TasksView.list), menuKey: _menuKey),
            titleRevealOffset: _TodoHeader.scrolledAway,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverToBoxAdapter(
            child: Column(
              key: _headerKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RiseIn(child: _TodoHeader()),
                if (_loaded) _Overview(onFilterChanged: _changeFilter),
              ],
            ),
          ),
        ),
        if (_loaded)
          _TaskListSliver(
            padding: EdgeInsets.fromLTRB(gutter, _listTop, gutter,
                PageActionButtons.height + 24 + padding.bottom),
            listDelay: _listDelay,
            onEdit: _editTask,
            onAddSubtask: _addSubtask,
            firstCardKey: _touring ? _firstCardKey : null,
          ),
      ],
    );
  }

  Widget _buildTwoPanes(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: CustomScrollView(
            controller: _overviewPaneScrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: LargeTitleBarDelegate(
                  title: _title,
                  topInset: padding.top,
                  controller: _overviewPaneScrollController,
                  titleRevealOffset: _TodoHeader.scrolledAway,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    16 + padding.left, 0, 16, 24 + padding.bottom),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    key: _headerKey,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RiseIn(child: _TodoHeader()),
                      if (_loaded) _Overview(onFilterChanged: _changeFilter),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: CustomScrollView(
            controller: _listPaneScrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: LargeTitleBarDelegate(
                  // The title is in the other pane already.
                  title: "",
                  topInset: padding.top,
                  controller: _listPaneScrollController,
                  trailing: _BarActions(
                      items: _menuItems(TasksView.list), menuKey: _menuKey),
                ),
              ),
              if (_loaded)
                _TaskListSliver(
                  padding: EdgeInsets.fromLTRB(16, 8, 16 + padding.right,
                      PageActionButtons.height + 24 + padding.bottom),
                  listDelay: _listDelay,
                  onEdit: _editTask,
                  onAddSubtask: _addSubtask,
                  firstCardKey: _touring ? _firstCardKey : null,
                ),
            ],
          ),
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

  /// Backs the tasks up, once the App Lock lets the user through.
  void _backUp() {
    Provider.of<TasksViewModel>(context, listen: false)
        .backup(
          askForPassword: passwordPrompt(context,
              subtitle: "Enter your password to back up your tasks."),
          askForBackupPassword: newBackupPasswordPrompt(context),
        )
        .then(_showResult);
  }

  void _addTask() => showFormDialog<void>(context, const TaskDialog());

  void _editTask(TodoItem task) =>
      showFormDialog<void>(context, TaskDialog(task: task));

  void _addSubtask(TodoItem parent) =>
      showFormDialog<void>(context, TaskDialog(parent: parent));

  void _openNotes() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NotesPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: animation.drive(
              Tween(begin: const Offset(-1, 0), end: Offset.zero)
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

/// Shows how [result] went, if there's a result to show: none when the user
/// cancels. One that changed more than was asked of it comes with an Undo
/// that takes it all back.
void _showResult(Result? result) {
  if (result case Undoable(:final message, :final undo)) {
    FeedbackToast.undoable(
      message,
      onUndo: () => undo().then(FeedbackToast.undone),
    );
    return;
  }
  result?.when(
    onSuccess: FeedbackToast.success,
    onFailure: FeedbackToast.error,
    onInfo: FeedbackToast.info,
  );
}

/// Moves [task] to the trash, with the tasks in it, as its card has been
/// swiped away, and says so with an Undo that puts them back where they
/// were.
Future<void> _moveToTrash(TasksViewModel tasks, TodoItem task) async {
  final trashed = await tasks.delete(task);
  if (trashed == null) {
    FeedbackToast.error("Couldn't delete the task");
    return;
  }
  final subtasks = trashed.item.subtasks.length;
  FeedbackToast.deleted(
    switch (subtasks) {
      0 => "Task moved to Trash",
      1 => "Task and its subtask moved to Trash",
      _ => "Task and its $subtasks subtasks moved to Trash",
    },
    onUndo: () => tasks.restoreFromTrash(trashed).then(FeedbackToast.undone),
  );
}

/// The bar over the map: the page's title and the menu, and, under them,
/// the filters, with how many tasks each lets through. Hidden, as on the
/// list, while there are no tasks, unless a filter other than All is still
/// on, so it can be turned off.
class _MapBar extends StatelessWidget {
  const _MapBar({
    required this.trailing,
    required this.filters,
    required this.onFilterChanged,
  });

  final Widget trailing;

  /// Whether the filters can show yet.
  final bool filters;
  final ValueChanged<TaskFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // As wide as the list's cards, and clear of a camera cutout.
    final gutter = math.max(16.0, (MediaQuery.sizeOf(context).width - 640) / 2);
    final (total, filtered) =
        context.select<TasksViewModel, (int, bool)>((tasks) => (
              tasks.finishedTasksCount + tasks.unfinishedTasksCount,
              tasks.currentFilter is! AllTasksFilter,
            ));
    return TitleBar(
      title: _title,
      topInset: padding.top,
      trailing: trailing,
      bottom: !filters || (total == 0 && !filtered)
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(math.max(gutter, 16 + padding.left),
                  2, math.max(gutter, 16 + padding.right), 10),
              child: TaskFilterBar(onChanged: onFilterChanged),
            ),
    );
  }
}

/// Tells [onChange] how tall its child is once it's laid out, and again
/// whenever that changes.
class _MeasuredHeight extends SingleChildRenderObjectWidget {
  const _MeasuredHeight({required this.onChange, super.child});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredHeight(onChange);

  @override
  void updateRenderObject(
          BuildContext context, _RenderMeasuredHeight renderObject) =>
      renderObject.onChange = onChange;
}

class _RenderMeasuredHeight extends RenderProxyBox {
  _RenderMeasuredHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _told;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _told) return;
    _told = height;
    // After the frame, as it's the page that's told, which is being laid
    // out now.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(height));
  }
}

/// The tasks the filter lets through as a map, or what to show instead when
/// there are none.
class _TaskMapPane extends StatelessWidget {
  const _TaskMapPane({
    required this.insets,
    required this.onEdit,
    required this.onAddSubtask,
    required this.hubKey,
    required this.nodeKey,
    required this.fitKey,
  });

  /// How much of the map the page's bar covers, and the edges of the screen
  /// it's to keep clear of.
  final EdgeInsets insets;

  /// Opens the editor for the task.
  final ValueChanged<TodoItem> onEdit;

  /// Opens the form for a new subtask of the task.
  final ValueChanged<TodoItem> onAddSubtask;

  /// What the map's tour points at.
  final GlobalKey hubKey;
  final GlobalKey nodeKey;
  final GlobalKey fitKey;

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksViewModel>();
    if (tasks.emptyReason case final reason?) {
      // Centred in the room the bar and the buttons leave, as on the list.
      return Padding(
        padding: EdgeInsets.only(
            top: insets.top,
            bottom: PageActionButtons.height + 24 + insets.bottom),
        child: RiseIn(key: ValueKey(reason), child: EmptyTasks(reason: reason)),
      );
    }
    return TaskMap(
      tasks: tasks,
      insets: insets,
      onEdit: onEdit,
      onAddSubtask: onAddSubtask,
      onDelete: (task) => _moveToTrash(tasks, task),
      onResult: _showResult,
      hubKey: hubKey,
      nodeKey: nodeKey,
      fitKey: fitKey,
    );
  }
}

/// The menu, with the switch between the list and the map and the tasks'
/// less frequent actions, and the avatar, at the end of the bar.
class _BarActions extends StatelessWidget {
  const _BarActions({required this.items, required this.menuKey});

  final List<GlassMenuItem> items;
  final GlobalKey menuKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassMenu(key: menuKey, items: items),
        const SizedBox(width: 10),
        const AppbarAvatar(),
      ],
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
              .format(context
                  .select<TasksViewModel, DateTime>((tasks) => tasks.today))
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

/// The progress summary and the filters, under the title. Hidden while
/// there are no tasks, unless a filter other than All is still on, so it
/// can be turned off.
class _Overview extends StatelessWidget {
  const _Overview({required this.onFilterChanged});

  final ValueChanged<TaskFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final (total, filtered) =
        context.select<TasksViewModel, (int, bool)>((tasks) => (
              tasks.finishedTasksCount + tasks.unfinishedTasksCount,
              tasks.currentFilter is! AllTasksFilter,
            ));
    if (total == 0 && !filtered) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: RiseIn(delay: RiseIn.stagger, child: TasksSummaryCard()),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: RiseIn(
            delay: RiseIn.stagger * 2,
            child: TaskFilterBar(onChanged: onFilterChanged),
          ),
        ),
      ],
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
    if (tasks.emptyReason case final reason?) {
      return SliverFillRemaining(
        hasScrollBody: false,
        // Centred in the room the buttons leave, within the page rather than
        // past its end, so an empty page doesn't scroll.
        child: Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          child:
              RiseIn(key: ValueKey(reason), child: EmptyTasks(reason: reason)),
        ),
      );
    }
    return SliverPadding(
      padding: padding,
      // A new list for each filter, so the cards rise in afresh.
      sliver: TaskList(
        key: ValueKey(tasks.currentFilter.runtimeType),
        tasks: tasks,
        listDelay: listDelay,
        onEdit: onEdit,
        onAddSubtask: onAddSubtask,
        onDelete: (task) => _moveToTrash(tasks, task),
        onResult: _showResult,
        firstCardKey: firstCardKey,
      ),
    );
  }
}
